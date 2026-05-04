import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart' as config;

class PlanPipelineService {
  Uri _u(String path) => Uri.parse('${config.AppConfig.baseUrl}$path');

  Future<String> uploadSheet({
    required Uint8List bytes,
    required String filename,
    String? projectId,
  }) async {
    final req = http.MultipartRequest('POST', _u('/plans/upload-sheet'));
    req.files.add(http.MultipartFile.fromBytes('sheet', bytes, filename: filename));
    if (projectId != null && projectId.isNotEmpty) {
      req.fields['project_id'] = projectId;
    }

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Upload sheet failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Upload sheet failed');
    return j['sheet_id'] as String;
  }

  Future<List<String>> detectSubplans({required String sheetId}) async {
    final resp = await http
        .post(_u('/plans/sheets/$sheetId/detect-subplans'))
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode != 200) {
      throw Exception('Detect subplans failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Detect subplans failed');
    final subs = (j['subplans'] as List?) ?? const [];
    return subs
        .map((e) => (e as Map<String, dynamic>)['_id'] as String)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Heuristic: treat the largest detected subplan crop as the "ground floor".
  /// This matches the requirement that manual marking UI should show ground floor only.
  Future<String> detectGroundFloorSubplanId({required String sheetId}) async {
    final resp = await http
        .post(_u('/plans/sheets/$sheetId/detect-subplans'))
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode != 200) {
      throw Exception('Detect subplans failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Detect subplans failed');

    final subs = (j['subplans'] as List?) ?? const [];
    if (subs.isEmpty) {
      throw Exception('No subplans detected.');
    }

    Map<String, dynamic>? best;
    int bestArea = -1;

    for (final raw in subs) {
      final m = raw as Map<String, dynamic>;
      final id = (m['_id'] ?? '').toString();
      if (id.isEmpty) continue;

      int area = 0;
      final bbox = m['bbox_sheet'];
      if (bbox is List && bbox.length == 4) {
        final x1 = (bbox[0] as num).toInt();
        final y1 = (bbox[1] as num).toInt();
        final x2 = (bbox[2] as num).toInt();
        final y2 = (bbox[3] as num).toInt();
        area = (x2 - x1).abs() * (y2 - y1).abs();
      } else {
        final img = m['image'];
        if (img is Map) {
          final w = (img['width'] as num?)?.toInt() ?? 0;
          final h = (img['height'] as num?)?.toInt() ?? 0;
          area = w * h;
        }
      }

      if (area > bestArea) {
        bestArea = area;
        best = m;
      }
    }

    final bestId = (best?['_id'] ?? '').toString();
    if (bestId.isEmpty) throw Exception('Could not choose ground floor subplan.');
    return bestId;
  }

  Future<void> startAnalysis({required String sheetId, String? apiKey, String? model}) async {
    final body = <String, dynamic>{};
    if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
    if (model != null && model.isNotEmpty) body['model'] = model;

    final resp = await http
        .post(
          _u('/plans/sheets/$sheetId/start-analysis'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Start analysis failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Start analysis failed');
  }

  Future<Map<String, dynamic>> selectGroundFloorSheet({
    required List<String> sheetIds,
    String? apiKey,
    String? model,
  }) async {
    final body = <String, dynamic>{'sheet_ids': sheetIds};
    if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
    if (model != null && model.isNotEmpty) body['model'] = model;

    final resp = await http
        .post(
          _u('/plans/sheets/select-ground-floor'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 180));

    if (resp.statusCode != 200) {
      throw Exception('Select ground floor failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Select ground floor failed');
    return j;
  }

  Future<Map<String, dynamic>> runPrompt1({
    required String projectId,
    required List<String> sheetIds,
    String? apiKey,
    String? model,
  }) async {
    final body = <String, dynamic>{'sheet_ids': sheetIds};
    if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
    if (model != null && model.isNotEmpty) body['model'] = model;

    final resp = await http
        .post(
          _u('/plans/projects/$projectId/prompt-1'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 240));

    if (resp.statusCode != 200) {
      throw Exception('Prompt-1 failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Prompt-1 failed');
    return j;
  }

  Future<Map<String, dynamic>> runPrompt2({
    required String projectId,
    required List<String> sheetIds,
    required String groundSheetId,
    String? apiKey,
    String? model,
  }) async {
    final body = <String, dynamic>{
      'sheet_ids': sheetIds,
      'ground_sheet_id': groundSheetId,
    };
    if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
    if (model != null && model.isNotEmpty) body['model'] = model;

    final resp = await http
        .post(
          _u('/plans/projects/$projectId/prompt-2'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 240));

    if (resp.statusCode != 200) {
      throw Exception('Prompt-2 failed (${resp.statusCode}): ${resp.body}');
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) throw Exception(j['error'] ?? 'Prompt-2 failed');
    return j;
  }

  Uri labelerUrl(String subplanId) {
    return _u('/plans/subplans/$subplanId/labeler');
  }

  bool isDoneUrl(String url) {
    return url.contains('/plans/subplans/') && url.endsWith('/done');
  }
}
