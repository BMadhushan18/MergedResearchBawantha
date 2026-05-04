// API client for BOQ upload, predictions, dashboard operations, and PDF generation.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models/boq_input.dart';
import '../models/dashboard_models.dart';
import '../models/prediction_response.dart';
import '../utils/constants.dart';

class ApiService {
  String resolveBaseUrl(String? custom) {
    final raw = (custom ?? '').trim();
    final candidate = raw.isEmpty ? AppConstants.defaultBaseUrl : raw;

    String normalized = candidate;
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final uri = Uri.tryParse(normalized);
    final host = (uri?.host ?? '').trim().toLowerCase();
    final isLikelyInvalid =
        host.isEmpty || host == 'api' || host == 'v1' || host == 'http' || host == 'https';

    if (!isLikelyInvalid) {
      return normalized;
    }

    String fallback = AppConstants.defaultBaseUrl.trim();
    if (!fallback.startsWith('http://') && !fallback.startsWith('https://')) {
      fallback = 'http://$fallback';
    }
    if (fallback.endsWith('/')) {
      fallback = fallback.substring(0, fallback.length - 1);
    }
    return fallback;
  }

  Future<http.Response> get(String path, {required String baseUrl}) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}$path');
    final response = await http.get(uri);
    return response;
  }

  Future<http.Response> post(String path, {required String baseUrl, dynamic body}) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}$path');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return response;
  }

  Future<PredictionResponse> uploadBOQ({
    required String baseUrl,
    required PlatformFile file,
    required BOQInput input,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}${AppConstants.predictFileEndpoint}');
    final request = http.MultipartRequest('POST', uri);

    request.fields['project_id'] = input.projectId;
    request.fields['site_location'] = input.siteLocation;

    if (file.bytes == null) {
      throw Exception('Selected file has no bytes in memory.');
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      file.bytes!,
      filename: file.name,
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }

    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return PredictionResponse.fromJson(body);
  }

  Future<PredictionResponse> predictFromText({
    required String baseUrl,
    required String projectId,
    required String siteLocation,
    required String boqText,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}/api/v1/boq/predict/text');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'project_id': projectId,
        'site_location': siteLocation,
        'boq_text': boqText,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Text prediction failed (${response.statusCode}): ${response.body}');
    }

    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return PredictionResponse.fromJson(body);
  }

  Future<PredictionResponse> predictFromBoqReport({
    required String baseUrl,
    required String projectId,
    required String siteLocation,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}/api/v1/boq/predict/from-report');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'project_id': projectId,
        'site_location': siteLocation,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('DB BOQ prediction failed (${response.statusCode}): ${response.body}');
    }

    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return PredictionResponse.fromJson(body);
  }

  Future<void> saveDashboardRecord({
    required String baseUrl,
    required PredictionResponse prediction,
    String? taskDescription,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}${AppConstants.dashboardSavePredictionEndpoint}');
    final payload = {
      'project_id': prediction.projectId,
      'task_description': taskDescription ?? 'Auto-detected BOQ tasks',
      'prediction': prediction.toHiveMap(),
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to save dashboard record: ${response.body}');
    }
  }

  Future<DashboardSummary> getDashboardSummary({
    required String baseUrl,
    required String projectId,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}${AppConstants.dashboardSummaryEndpoint}/$projectId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed summary fetch (${response.statusCode}): ${response.body}');
    }

    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return DashboardSummary.fromJson(body);
  }

  Future<List<PredictionResponse>> getDashboardHistory({
    required String baseUrl,
    required String projectId,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}${AppConstants.dashboardHistoryEndpoint}/$projectId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed history fetch (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final list = _extractList(decoded);

    return list
      .map((item) => _predictionFromHistoryItem(Map<String, dynamic>.from(item as Map)))
      .toList();
  }

  Future<List<DashboardHistoryItem>> getAllDashboardHistory({
    required String baseUrl,
    int limit = 500,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}${AppConstants.dashboardHistoryAllEndpoint}?limit=$limit');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed all-history fetch (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final list = _extractList(decoded);

    return list
        .map((item) => DashboardHistoryItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<String>> getAvailableProjects({
    required String baseUrl,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}/api/v1/dashboard/projects');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed project fetch (${response.statusCode}): ${response.body}');
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final ids = (decoded['project_ids'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    return ids;
  }

  Future<List<ProjectCatalogItem>> getProjectsCatalog({
    required String baseUrl,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}/api/v1/dashboard/projects');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed project catalog fetch (${response.statusCode}): ${response.body}');
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final projects = (decoded['projects'] as List<dynamic>? ?? const [])
        .map((e) => ProjectCatalogItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.projectId.isNotEmpty)
        .toList();

    return projects;
  }

  Future<Uint8List> generatePdf({
    required String baseUrl,
    required String projectId,
  }) async {
    final uri = Uri.parse('${resolveBaseUrl(baseUrl)}${AppConstants.generateProcurementPdfEndpoint}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'project_id': projectId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate PDF (${response.statusCode}): ${response.body}');
    }

    return response.bodyBytes;
  }

  // Backward-compatible wrappers used by existing screens.
  Future<PredictionResponse> uploadBoqFile({
    required String baseUrl,
    required PlatformFile file,
    required BOQInput input,
  }) {
    return uploadBOQ(baseUrl: baseUrl, file: file, input: input);
  }

  Future<void> savePredictionToDashboard({
    required String baseUrl,
    required String projectId,
    required String taskDescription,
    required PredictionResponse prediction,
  }) {
    return saveDashboardRecord(
      baseUrl: baseUrl,
      prediction: prediction,
      taskDescription: taskDescription,
    );
  }

  Future<Uint8List> generateProcurementPdf({
    required String baseUrl,
    required String projectId,
    required String projectName,
  }) {
    return generatePdf(baseUrl: baseUrl, projectId: projectId);
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      if (decoded['records'] is List<dynamic>) {
        return decoded['records'] as List<dynamic>;
      }
      if (decoded['history'] is List<dynamic>) {
        return decoded['history'] as List<dynamic>;
      }
      if (decoded['items'] is List<dynamic>) {
        return decoded['items'] as List<dynamic>;
      }
    }
    return const [];
  }

  PredictionResponse _predictionFromHistoryItem(Map<String, dynamic> item) {
    final payload = item['prediction'] ?? item['predictions'] ?? item;
    return PredictionResponse.fromJson(Map<String, dynamic>.from(payload as Map));
  }
}
