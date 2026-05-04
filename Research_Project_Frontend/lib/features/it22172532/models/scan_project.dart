import 'dart:io';

class ScanProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<CapturedImage> images;
  final ScanStatus status;
  final String? modelPath;
  final double? progress;

  ScanProject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.images = const [],
    this.status = ScanStatus.capturing,
    this.modelPath,
    this.progress,
  });

  ScanProject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<CapturedImage>? images,
    ScanStatus? status,
    String? modelPath,
    double? progress,
  }) {
    return ScanProject(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      images: images ?? this.images,
      status: status ?? this.status,
      modelPath: modelPath ?? this.modelPath,
      progress: progress ?? this.progress,
    );
  }
}

class CapturedImage {
  final String id;
  final String path;
  final int index;
  final double angle;
  final DateTime capturedAt;

  CapturedImage({
    required this.id,
    required this.path,
    required this.index,
    required this.angle,
    required this.capturedAt,
  });

  File get file => File(path);
}

enum ScanStatus {
  capturing,
  uploading,
  processing,
  completed,
  failed,
}
