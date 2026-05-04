import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/scan_project.dart';

class StorageService {
  static const String _projectsKey = 'saved_projects';

  /// Get app documents directory
  Future<Directory> getAppDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/3d_scanner');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Get models directory
  Future<Directory> getModelsDirectory() async {
    final appDir = await getAppDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Get scans directory (for captured images)
  Future<Directory> getScansDirectory() async {
    final appDir = await getAppDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }
    return scansDir;
  }

  /// Save downloaded model locally
  Future<String> saveModel(String projectId, String remotePath) async {
    final modelsDir = await getModelsDirectory();
    final localPath = path.join(modelsDir.path, '$projectId.glb');

    // The model should already be downloaded to the local path
    // This method ensures the path is correct and accessible

    return localPath;
  }

  /// Get local model path
  Future<String?> getModelPath(String projectId) async {
    final modelsDir = await getModelsDirectory();
    final modelPath = path.join(modelsDir.path, '$projectId.glb');

    if (await File(modelPath).exists()) {
      return modelPath;
    }
    return null;
  }

  /// Save project metadata
  Future<void> saveProjectMetadata(ScanProject project) async {
    final prefs = await SharedPreferences.getInstance();
    final projectsJson = prefs.getStringList(_projectsKey) ?? [];

    // Create project map
    final projectMap = {
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toIso8601String(),
      'imageCount': project.images.length,
      'status': project.status.toString(),
      'modelPath': project.modelPath,
      'images': project.images
          .map((img) => {
                'id': img.id,
                'path': img.path,
                'index': img.index,
                'angle': img.angle,
                'capturedAt': img.capturedAt.toIso8601String(),
              })
          .toList(),
    };

    // Remove existing entry if exists
    projectsJson.removeWhere((json) {
      final map = jsonDecode(json);
      return map['id'] == project.id;
    });

    // Add new entry
    projectsJson.add(jsonEncode(projectMap));

    await prefs.setStringList(_projectsKey, projectsJson);
  }

  /// Get all saved projects
  Future<List<Map<String, dynamic>>> getSavedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final projectsJson = prefs.getStringList(_projectsKey) ?? [];

    return projectsJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();
  }

  /// Delete project files
  Future<void> deleteProjectFiles(String projectId) async {
    // Delete model
    final modelsDir = await getModelsDirectory();
    final modelFile = File(path.join(modelsDir.path, '$projectId.glb'));
    if (await modelFile.exists()) {
      await modelFile.delete();
    }

    // Delete scan images
    final scansDir = await getScansDirectory();
    final projectScansDir = Directory(path.join(scansDir.path, projectId));
    if (await projectScansDir.exists()) {
      await projectScansDir.delete(recursive: true);
    }

    // Remove from preferences
    final prefs = await SharedPreferences.getInstance();
    final projectsJson = prefs.getStringList(_projectsKey) ?? [];
    projectsJson.removeWhere((json) {
      final map = jsonDecode(json);
      return map['id'] == projectId;
    });
    await prefs.setStringList(_projectsKey, projectsJson);
  }

  /// Calculate storage usage
  Future<int> getStorageUsage() async {
    int totalSize = 0;

    final modelsDir = await getModelsDirectory();
    if (await modelsDir.exists()) {
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    final scansDir = await getScansDirectory();
    if (await scansDir.exists()) {
      await for (final entity in scansDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    return totalSize;
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    final scansTempDir = Directory('${tempDir.path}/scans');
    if (await scansTempDir.exists()) {
      await scansTempDir.delete(recursive: true);
    }
  }
}
