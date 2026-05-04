// Input and offline record models used by upload flow and Hive cache.
enum BoqSourceMode { uploadFile, directText, fromBoqReport }

class BOQInput {
  final String projectId;
  final String projectName;
  final String projectType;
  final String siteLocation;
  final int totalFloorAreaSqft;
  final int numberOfFloors;
  final double buildingComplexityIndex;
  final int workingDays;

  const BOQInput({
    required this.projectId,
    required this.projectName,
    this.projectType = 'Residential',
    this.siteLocation = 'Colombo',
    this.totalFloorAreaSqft = 3000,
    this.numberOfFloors = 1,
    this.buildingComplexityIndex = 6.0,
    this.workingDays = 5,
  });

  factory BOQInput.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse((value ?? '').toString()) ?? fallback;
    }

    double toDouble(dynamic value, double fallback) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse((value ?? '').toString()) ?? fallback;
    }

    return BOQInput(
      projectId: (json['project_id'] ?? '').toString(),
      projectName: (json['project_name'] ?? '').toString(),
      projectType: (json['project_type'] ?? 'Residential').toString(),
      siteLocation: (json['site_location'] ?? 'Colombo').toString(),
      totalFloorAreaSqft: toInt(json['total_floor_area_sqft'], 3000),
      numberOfFloors: toInt(json['number_of_floors'], 1),
      buildingComplexityIndex: toDouble(json['building_complexity_index'], 6.0),
      workingDays: toInt(json['working_days'], 5),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_name': projectName,
      'project_type': projectType,
      'site_location': siteLocation,
      'total_floor_area_sqft': totalFloorAreaSqft,
      'number_of_floors': numberOfFloors,
      'building_complexity_index': buildingComplexityIndex,
      'working_days': workingDays,
    };
  }

  BOQInput copyWith({
    String? projectId,
    String? projectName,
    String? projectType,
    String? siteLocation,
    int? totalFloorAreaSqft,
    int? numberOfFloors,
    double? buildingComplexityIndex,
    int? workingDays,
  }) {
    return BOQInput(
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      projectType: projectType ?? this.projectType,
      siteLocation: siteLocation ?? this.siteLocation,
      totalFloorAreaSqft: totalFloorAreaSqft ?? this.totalFloorAreaSqft,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      buildingComplexityIndex: buildingComplexityIndex ?? this.buildingComplexityIndex,
      workingDays: workingDays ?? this.workingDays,
    );
  }
}

class OfflineUploadRecord {
  final String id;
  final String projectId;
  final String projectName;
  final String fileName;
  final DateTime uploadedAt;
  final Map<String, dynamic> prediction;

  const OfflineUploadRecord({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.fileName,
    required this.uploadedAt,
    required this.prediction,
  });

  factory OfflineUploadRecord.fromJson(Map<String, dynamic> json) {
    return OfflineUploadRecord(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      projectName: (json['project_name'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      uploadedAt: DateTime.tryParse((json['uploaded_at'] ?? '').toString()) ?? DateTime.now(),
      prediction: Map<String, dynamic>.from(json['prediction'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'project_name': projectName,
      'file_name': fileName,
      'uploaded_at': uploadedAt.toIso8601String(),
      'prediction': prediction,
    };
  }
}
