// Dashboard models for summary and history endpoints.
class DashboardSummary {
  final String projectId;
  final int totalVehicleCost;
  final int totalMachineryCost;
  final int totalLabourCost;
  final int totalProjectCost;
  final double averageConfidenceScore;
  final int totalGangHeadcount;
  final List<String> vehicleTypes;
  final List<String> machineryTypes;

  const DashboardSummary({
    required this.projectId,
    required this.totalVehicleCost,
    required this.totalMachineryCost,
    required this.totalLabourCost,
    required this.totalProjectCost,
    required this.averageConfidenceScore,
    required this.totalGangHeadcount,
    required this.vehicleTypes,
    required this.machineryTypes,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      projectId: (json['project_id'] ?? '').toString(),
      totalVehicleCost: (json['total_vehicle_cost'] ?? 0) as int,
      totalMachineryCost: (json['total_machinery_cost'] ?? 0) as int,
      totalLabourCost: (json['total_labour_cost'] ?? 0) as int,
      totalProjectCost: (json['total_project_cost'] ?? 0) as int,
      averageConfidenceScore: (json['average_confidence_score'] ?? 0).toDouble(),
      totalGangHeadcount: (json['total_gang_headcount'] ?? 0) as int,
      vehicleTypes: (json['vehicle_types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      machineryTypes: (json['machinery_types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class DashboardHistoryItem {
  final String id;
  final String projectId;
  final String projectName;
  final String taskDescription;
  final Map<String, dynamic> predictions;
  final DateTime timestamp;

  const DashboardHistoryItem({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.taskDescription,
    required this.predictions,
    required this.timestamp,
  });

  factory DashboardHistoryItem.fromJson(Map<String, dynamic> json) {
    final predictionPayload = json['prediction'] ?? json['predictions'] ?? json;
    final predictionMap = Map<String, dynamic>.from(
      predictionPayload is Map ? predictionPayload : const {},
    );

    final ts = json['timestamp'] ?? json['created_at'] ?? predictionMap['predicted_at'];

    return DashboardHistoryItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      projectId: (json['project_id'] ?? predictionMap['project_id'] ?? '').toString(),
      projectName: (json['project_name'] ?? predictionMap['project_name'] ?? '').toString(),
      taskDescription: (json['task_description'] ?? predictionMap['task_name'] ?? '').toString(),
      predictions: predictionMap,
      timestamp: DateTime.tryParse((ts ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class ProjectCatalogItem {
  final String projectId;
  final String projectName;
  final String projectType;
  final String siteLocation;

  const ProjectCatalogItem({
    required this.projectId,
    required this.projectName,
    required this.projectType,
    required this.siteLocation,
  });

  factory ProjectCatalogItem.fromJson(Map<String, dynamic> json) {
    return ProjectCatalogItem(
      projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
      projectName: (json['project_name'] ?? json['projectName'] ?? '').toString(),
      projectType: (json['project_type'] ?? json['projectType'] ?? 'Residential').toString(),
      siteLocation: (json['site_location'] ?? json['siteLocation'] ?? '').toString(),
    );
  }
}
