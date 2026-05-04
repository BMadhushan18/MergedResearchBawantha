import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight HTTP client used by the wood classification screens.
/// Mirrors the ApiClient from dineth_app_frontend/lib/core/api_client.dart.
class WoodApiClient {
  final String baseUrl;
  const WoodApiClient(this.baseUrl);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    if (decoded is Map && decoded['detail'] != null) {
      throw Exception(decoded['detail']);
    }
    throw Exception('Request failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    String fileField,
    List<int> bytes,
    String filename, {
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri);
    if (fields != null) {
      req.fields.addAll(fields);
    }
    req.files.add(
      http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
    );
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final decoded = jsonDecode(body.isEmpty ? '{}' : body);

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    if (decoded is Map && decoded['detail'] != null) {
      throw Exception(decoded['detail']);
    }
    throw Exception('Request failed: ${streamed.statusCode}');
  }
}
