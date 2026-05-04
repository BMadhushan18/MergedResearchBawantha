import 'dart:convert';

import 'package:http/http.dart' as http;

class DinethApiClient {
  final String baseUrl;

  DinethApiClient(this.baseUrl);

  Future<Map<String, dynamic>> postMultipart(
    String path,
    String fileField,
    List<int> bytes,
    String filename, {
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(
      http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
    );

    final streamed = await request.send();
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
