import 'dart:io';
import 'package:dio/dio.dart';
import 'package:boq_frontend/features/it22172532/config/app_config.dart' as ac;
import 'package:boq_frontend/features/it22172532/models/recon3d_job_model.dart';
import 'package:boq_frontend/features/it22172532/models/recon3d_progress_model.dart';

class Recon3DApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ac.AppConfig.recon3dBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 10),
  ));

  /// Start a live reconstruction session.
  Future<Map<String, dynamic>> startLiveSession() async {
    final resp = await _dio.post<Map<String, dynamic>>('/live/start');
    return resp.data!;
  }

  /// WebSocket URL for sending live frames.
  String liveWsUrl(String sessionId) {
    final base = ac.AppConfig.recon3dBaseUrl;
    final wsBase = base.startsWith('https://')
        ? base.replaceFirst('https://', 'wss://')
        : base.replaceFirst('http://', 'ws://');
    return '$wsBase/live/ws/$sessionId?role=sender';
  }

  /// Viewer URL for the live point cloud.
  String liveViewerUrl(String sessionId) =>
      resolveUrl('/live/viewer/$sessionId');

  /// Upload video or image files; returns the raw job payload map.
  Future<Map<String, dynamic>> uploadFiles(
    List<File> files, {
    String profile = 'fast',
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('profile', profile));
    for (final file in files) {
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      ));
    }

    final resp = await _dio.post<Map<String, dynamic>>(
      '/upload',
      data: formData,
      onSendProgress: onProgress,
    );
    return resp.data!;
  }

  /// Poll job status once.
  Future<Recon3DJobStatus> getStatus(String jobId) async {
    final resp = await _dio.get<Map<String, dynamic>>('/job/$jobId');
    return Recon3DJobStatus.fromJson(resp.data!);
  }

  /// Compare two 3D output files (PLY/GLB) for progress analysis.
  Future<Recon3DProgressComparison> compareProgress(
      File yesterday, File today) async {
    final formData = FormData.fromMap({
      'yesterday': await MultipartFile.fromFile(
        yesterday.path,
        filename: yesterday.uri.pathSegments.last,
      ),
      'today': await MultipartFile.fromFile(
        today.path,
        filename: today.uri.pathSegments.last,
      ),
    });

    final resp = await _dio.post<Map<String, dynamic>>(
        '/progress/compare',
        data: formData);
    return Recon3DProgressComparison.fromJson(resp.data!);
  }

  String resolveUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') ||
        urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    if (urlOrPath.startsWith('/')) {
      return '${ac.AppConfig.recon3dBaseUrl}$urlOrPath';
    }
    return '${ac.AppConfig.recon3dBaseUrl}/$urlOrPath';
  }

  /// URL for the in-browser Three.js viewer.
  String viewerUrl(String jobId) => resolveUrl('/viewer/$jobId');

  /// Download the selected artifact to [savePath].
  Future<void> downloadResult(String urlOrPath, String savePath) async {
    await _dio.download(resolveUrl(urlOrPath), savePath);
  }

  /// Delete job & all server-side files.
  Future<void> deleteJob(String jobId) async {
    await _dio.delete('/job/$jobId');
  }
}
