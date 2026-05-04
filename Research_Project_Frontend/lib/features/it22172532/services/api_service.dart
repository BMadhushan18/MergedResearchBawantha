import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ));

    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Upload images to backend
  Future<void> uploadImages({
    required String projectId,
    required List<String> imagePaths,
    required Function(double) onProgress,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData();

      formData.fields.add(MapEntry('project_id', projectId));

      for (int i = 0; i < imagePaths.length; i++) {
        final file = File(imagePaths[i]);
        if (await file.exists()) {
          formData.files.add(MapEntry(
            'images',
            await MultipartFile.fromFile(
              imagePaths[i],
              filename: 'image_${i.toString().padLeft(3, '0')}.jpg',
            ),
          ));
        }
      }

      await _dio.post(
        '/api/v1/upload',
        data: formData,
        onSendProgress: (sent, total) {
          onProgress(sent / total);
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Start 3D reconstruction process
  Future<String> startReconstruction({
    required String projectId,
    required Function(double) onProgress,
    String quality = 'medium',
  }) async {
    try {
      // Start reconstruction (backend: /api/v1/start/{project_id})
      await _dio.post('/api/v1/start/$projectId');

      // Poll for status
      String status = 'processing';
      String? modelUrl;

      while (status == 'processing') {
        await Future.delayed(const Duration(seconds: 2));

        final response = await _dio.get('/api/v1/status/$projectId');
        final body = response.data ?? {};
        final data = body['data'] ?? body;

        status = data['status'] ?? 'processing';
        onProgress((data['progress'] ?? 0.0) is double
            ? data['progress']
            : (data['progress'] ?? 0.0));

        if (status == 'completed') {
          // Fetch model info to get a stable URL
          final infoResp = await _dio.get('/api/v1/model/$projectId/info');
          final infoBody = infoResp.data ?? {};
          final infoData = infoBody['data'] ?? infoBody;
          final model = infoData['model'];
          if (model != null && model['url'] != null) {
            modelUrl = '${_dio.options.baseUrl}${model['url']}';
          } else {
            modelUrl = '';
          }
          break;
        } else if (status == 'failed') {
          throw Exception(data['message'] ?? 'Reconstruction failed');
        }
      }

      return modelUrl ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Download the 3D model
  Future<String> downloadModel({
    required String projectId,
    required String savePath,
    required Function(double) onProgress,
  }) async {
    try {
      // Backend download route: GET /api/v1/model/{project_id}
      await _dio.download(
        '/api/v1/model/$projectId',
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      return savePath;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get reconstruction status
  Future<Map<String, dynamic>> getStatus(String projectId) async {
    try {
      final response = await _dio.get('/api/v1/status/$projectId');
      final body = response.data ?? {};
      final data = body['data'] ?? body;
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete project
  Future<void> deleteProject(String projectId) async {
    try {
      await _dio.delete('/api/v1/project/$projectId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload single frame (real-time streaming)
  Future<void> uploadFrame({
    required String projectId,
    required String framePath,
  }) async {
    try {
      final file = File(framePath);
      if (!await file.exists()) {
        throw Exception('Frame file not found');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          framePath,
          filename: path.basename(framePath),
        ),
      });

      await _dio.post(
        '/api/v1/frame/$projectId',
        data: formData,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload multiple frames in batch
  Future<void> uploadFrameBatch({
    required String projectId,
    required List<String> framePaths,
    Function(double)? onProgress,
  }) async {
    try {
      final formData = FormData();

      for (int i = 0; i < framePaths.length; i++) {
        final file = File(framePaths[i]);
        if (await file.exists()) {
          formData.files.add(MapEntry(
            'files',
            await MultipartFile.fromFile(
              framePaths[i],
              filename: path.basename(framePaths[i]),
            ),
          ));
        }
      }

      await _dio.post(
        '/api/v1/frames/$projectId',
        data: formData,
        onSendProgress: onProgress != null
            ? (sent, total) => onProgress(sent / total)
            : null,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new project
  Future<String> createProject({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/project',
        data: {
          'name': name,
          'description': description ?? '',
        },
      );

      final data = response.data['data'];
      return data['project_id'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload video for frame extraction
  Future<Map<String, dynamic>> uploadVideo({
    required String projectId,
    required String videoPath,
    required Function(double) onProgress,
  }) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        throw Exception('Video file not found');
      }

      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(
          videoPath,
          filename: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      });

      final response = await _dio.post(
        '/api/v1/upload-video/$projectId',
        data: formData,
        onSendProgress: (sent, total) {
          onProgress(sent / total);
        },
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body;
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Extract frames from uploaded video
  Future<void> extractFrames({
    required String projectId,
    required Function(double) onProgress,
  }) async {
    try {
      await _dio.post('/api/v1/extract-frames/$projectId');

      // Poll for frame extraction progress
      String status = 'processing';
      while (status == 'processing') {
        await Future.delayed(const Duration(seconds: 1));

        final response = await _dio.get('/api/v1/status/$projectId');
        final body = response.data ?? {};
        final data = body['data'] ?? body;

        status = data['status'] ?? 'processing';
        final progress = data['progress'];
        if (progress != null) {
          onProgress(
              progress is double ? progress : (progress as num).toDouble());
        }

        if (status == 'failed') {
          throw Exception(data['message'] ?? 'Frame extraction failed');
        }
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Run feature matching step
  Future<Map<String, dynamic>> runFeatureMatching({
    required String projectId,
    required Function(double) onProgress,
  }) async {
    try {
      await _dio.post('/api/v1/feature-matching/$projectId');

      // Poll for progress
      String status = 'processing';
      String? outputPath;

      while (status == 'processing') {
        await Future.delayed(const Duration(seconds: 2));

        final response = await _dio.get('/api/v1/status/$projectId');
        final body = response.data ?? {};
        final data = body['data'] ?? body;

        status = data['status'] ?? 'processing';
        final progress = data['progress'];
        if (progress != null) {
          onProgress(
              progress is double ? progress : (progress as num).toDouble());
        }

        if (status == 'completed') {
          outputPath = data['feature_matching_output'];
          break;
        } else if (status == 'failed') {
          throw Exception(data['message'] ?? 'Feature matching failed');
        }
      }

      return {'output_path': outputPath};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Generate point cloud
  Future<Map<String, dynamic>> generatePointCloud({
    required String projectId,
    required Function(double) onProgress,
  }) async {
    try {
      await _dio.post('/api/v1/point-cloud/$projectId');

      // Poll for progress
      String status = 'processing';
      String? pointCloudPath;

      while (status == 'processing') {
        await Future.delayed(const Duration(seconds: 2));

        final response = await _dio.get('/api/v1/status/$projectId');
        final body = response.data ?? {};
        final data = body['data'] ?? body;

        status = data['status'] ?? 'processing';
        final progress = data['progress'];
        if (progress != null) {
          onProgress(
              progress is double ? progress : (progress as num).toDouble());
        }

        if (status == 'completed') {
          pointCloudPath = data['point_cloud_path'];
          break;
        } else if (status == 'failed') {
          throw Exception(data['message'] ?? 'Point cloud generation failed');
        }
      }

      return {'point_cloud_path': pointCloudPath};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create mesh from point cloud
  Future<String> createMesh({
    required String projectId,
    required Function(double) onProgress,
  }) async {
    try {
      await _dio.post('/api/v1/create-mesh/$projectId');

      // Poll for progress
      // Increase timeout for long-running reconstruction (up to 15 minutes)
      const int maxAttempts = 450; // 450 * 2 seconds = 15 minutes
      int attempts = 0;
      String status = 'processing';
      String? modelUrl;

      while (status == 'processing' && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        attempts++;

        final response = await _dio.get('/api/v1/status/$projectId');
        final body = response.data ?? {};
        final data = body['data'] ?? body;

        status = data['status'] ?? 'processing';
        final progress = data['progress'];
        if (progress != null) {
          onProgress(
              progress is double ? progress : (progress as num).toDouble());
        }

        if (status == 'completed') {
          final infoResp = await _dio.get('/api/v1/model/$projectId/info');
          final infoBody = infoResp.data ?? {};
          final infoData = infoBody['data'] ?? infoBody;
          final model = infoData['model'];
          if (model != null && model['url'] != null) {
            modelUrl = '${_dio.options.baseUrl}${model['url']}';
          }
          break;
        } else if (status == 'failed') {
          throw Exception(data['message'] ?? 'Mesh creation failed');
        }
      }

      if (attempts >= maxAttempts) {
        throw Exception('Mesh creation timeout - process took too long');
      }

      return modelUrl ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }

  /// Upload panorama images for 3D reconstruction
  Future<String> uploadPanoramaImages({
    required List<String> panoramaPaths,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('📸 Starting panorama upload with ${panoramaPaths.length} images');
      debugPrint('🌐 API Base URL: ${_dio.options.baseUrl}');
      
      // Create multipart form data
      final formData = FormData();

      for (int i = 0; i < panoramaPaths.length; i++) {
        final file = File(panoramaPaths[i]);
        debugPrint('📁 Checking file $i: ${panoramaPaths[i]}');
        
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('✅ File exists, size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          
          formData.files.add(MapEntry(
            'files',
            await MultipartFile.fromFile(
              panoramaPaths[i],
              filename: 'panorama_${i + 1}.jpg',
            ),
          ));
        } else {
          debugPrint('❌ File does not exist: ${panoramaPaths[i]}');
          throw Exception('File not found: ${panoramaPaths[i]}');
        }
      }

      debugPrint('📤 Uploading to /api/v1/panorama/upload');
      
      // Upload panoramas
      final response = await _dio.post(
        '/api/v1/panorama/upload',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total * 0.3;
          debugPrint('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}% ($sent/$total bytes)');
          onProgress(progress); // Upload is 30% of total progress
        },
      );

      debugPrint('✅ Upload successful: ${response.statusCode}');
      
      final responseData = response.data;
      final projectId = responseData['project_id'] as String;
      debugPrint('🆔 Project ID: $projectId');

      // Poll for processing status
      String status = 'processing';
      String? modelUrl;
      int attempts = 0;
      const maxAttempts = 300; // 10 minutes at 2-second intervals

      while (status != 'completed' && status != 'error' && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        attempts++;

        debugPrint('🔄 Checking status (attempt $attempts)...');
        final statusResponse = await _dio.get('/api/v1/panorama/status/$projectId');
        final statusData = statusResponse.data;

        status = statusData['status'] ?? 'processing';
        debugPrint('📊 Status: $status');
        
        // Calculate progress (30% upload + 70% processing)
        if (status == 'views_extracted') {
          debugPrint('🎨 Views extracted');
          onProgress(0.5); // 50% when views are extracted
        } else if (status == 'reconstructing') {
          debugPrint('🔨 Reconstructing 3D model');
          onProgress(0.7); // 70% when reconstructing
        } else if (status == 'completed') {
          debugPrint('✅ Processing completed!');
          onProgress(1.0);
          modelUrl = statusData['model_path'];
          break;
        } else if (status == 'error') {
          final errorMsg = statusData['message'] ?? 'Panorama processing failed';
          debugPrint('❌ Error: $errorMsg');
          throw Exception(errorMsg);
        }
      }

      if (attempts >= maxAttempts) {
        debugPrint('⏱️ Timeout after $attempts attempts');
        throw Exception('Panorama processing timeout');
      }

      debugPrint('🎉 Model URL: $modelUrl');
      return modelUrl ?? '';
    } on DioException catch (e) {
      debugPrint('❌ DioException: ${e.type}');
      debugPrint('❌ Message: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      rethrow;
    }
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.sendTimeout:
        return 'Upload timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server response timeout. Please try again.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'Server error';
        return 'Error $statusCode: $message';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Please check your connection.';
      default:
        return e.message ?? 'An unexpected error occurred';
    }
  }
}
