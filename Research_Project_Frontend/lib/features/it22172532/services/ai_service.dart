import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiGenerateResult {
  final String text;
  final String model;

  const AiGenerateResult({required this.text, required this.model});
}

class AiService {
  static const _key = 'ai_api_key';
  static const _modelKey = 'ai_model';
  static const _legacyModelKey = 'ai_model_name';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveApiKey(String key) => _storage.write(key: _key, value: key);
  Future<String?> readApiKey() => _storage.read(key: _key);
  Future<void> deleteApiKey() => _storage.delete(key: _key);

  Future<void> saveModel(String model) => _storage.write(key: _modelKey, value: model);
  Future<String?> readModel() async {
    final current = await _storage.read(key: _modelKey);
    if (current != null && current.isNotEmpty) return current;
    return _storage.read(key: _legacyModelKey);
  }
  Future<void> deleteModel() => _storage.delete(key: _modelKey);

  List<String> buildModelFallbacks({String? preferredModel}) {
    return <String>{
      if (preferredModel != null && preferredModel.isNotEmpty) preferredModel,
      'gemini-2.0-flash',
      'gemini-1.5-flash-latest',
      'gemini-1.5-flash',
    }.toList();
  }

  /// Build authorization headers using the stored AI API key.
  /// Returns an empty map if no key is stored.
  Future<Map<String, String>> getAuthHeaders() async {
    final k = await readApiKey();
    if (k == null || k.isEmpty) return <String, String>{};
    return {
      'Authorization': 'Bearer $k',
      'Content-Type': 'application/json',
    };
  }

  /// Send a small test prompt to a model endpoint and return the text response.
  /// Uses AI generateContent endpoint with the stored API key.
  Future<String> testPrompt(String prompt, {String? model}) async {
    final key = await readApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('No API key configured');
    }

    final body = json.encode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });

    final models = buildModelFallbacks(preferredModel: model);

    String? lastError;

    for (final model in models) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
      );

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final j = json.decode(resp.body);
          if (j is Map && j['candidates'] is List && j['candidates'].isNotEmpty) {
            final candidate = j['candidates'][0];
            final content = candidate['content'];
            final parts = content?['parts'];
            if (parts is List && parts.isNotEmpty) {
              final text = parts[0]['text'];
              if (text is String && text.trim().isNotEmpty) {
                return text;
              }
            }
          }
          return resp.body;
        } catch (_) {
          return resp.body;
        }
      }

      // If model not found, try next fallback model.
      if (resp.statusCode == 404) {
        lastError = 'Model $model not found for this API.';
        continue;
      }

      // Any non-404 error is likely key/permission/quota related; stop here.
      lastError = 'Request failed (${resp.statusCode}): ${resp.body}';
      break;
    }

    throw Exception(lastError ?? 'Unable to get response from AI API');
  }

  Future<AiGenerateResult> generateContent({
    required List<Map<String, dynamic>> contents,
    String? preferredModel,
    Map<String, dynamic>? generationConfig,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final key = await readApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('No API key configured');
    }

    final body = json.encode({
      'contents': contents,
      if (generationConfig != null) 'generationConfig': generationConfig,
    });

    String? lastError;

    for (final model in buildModelFallbacks(preferredModel: preferredModel)) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
      );

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      if (resp.statusCode == 404) {
        lastError = 'Model $model not found for this API key.';
        continue;
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        lastError = 'AI error ${resp.statusCode}: ${resp.body}';
        continue;
      }

      final decoded = json.decode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        lastError = 'AI returned an unexpected response.';
        continue;
      }

      final candidateText = _extractCandidateText(decoded);
      if (candidateText.trim().isNotEmpty) {
        return AiGenerateResult(text: candidateText, model: model);
      }

      final blockedReason = ((decoded['promptFeedback'] as Map?)?['blockReason'])?.toString();
      if (blockedReason != null && blockedReason.isNotEmpty) {
        lastError = 'AI blocked the request: $blockedReason';
        continue;
      }

      lastError = 'AI returned an empty response.';
    }

    throw Exception(lastError ?? 'Unable to get response from AI API');
  }

  String _extractCandidateText(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return '';
    final firstPart = parts.first;
    if (firstPart is! Map) return '';
    final text = firstPart['text'];
    return text is String ? text : '';
  }
}