import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Service for handling HTTP requests
class ApiService {
  late Dio _dio;

  static String get _baseUrl =>
      'http://${dotenv.get('BACKEND_HOST', fallback: '127.0.0.1')}:${dotenv.get('BACKEND_PORT', fallback: '8000')}';
  static const Duration _timeout = Duration(seconds: 30);

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        contentType: 'application/json',
      ),
    );

    // Add interceptors if needed
    _dio.interceptors.add(LoggingInterceptor());
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete(path, queryParameters: queryParameters);
  }
}

/// Logging Interceptor for debugging
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('REQUEST: ${options.method} ${options.path}', name: 'ApiService');
    log('Headers: ${options.headers}', name: 'ApiService');
    log('Body: ${options.data}', name: 'ApiService');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log(
      'RESPONSE: ${response.statusCode} ${response.requestOptions.path}',
      name: 'ApiService',
    );
    log('Body: ${response.data}', name: 'ApiService');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('ERROR: ${err.message}', name: 'ApiService');
    super.onError(err, handler);
  }
}
