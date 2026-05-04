int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _toStringValue(dynamic value) => (value ?? '').toString();

class VehicleResult {
  final String vehicleType;
  final int vehicleCount;
  final String vehiclePurpose;
  final int vehicleHourlyCostRs;
  final int vehicleDailyRentalRs;
  final double vehicleFuelLph;
  final int vehicleTotalDailyCostRs;

  const VehicleResult({
    required this.vehicleType,
    required this.vehicleCount,
    required this.vehiclePurpose,
    required this.vehicleHourlyCostRs,
    required this.vehicleDailyRentalRs,
    required this.vehicleFuelLph,
    required this.vehicleTotalDailyCostRs,
  });

  factory VehicleResult.fromJson(Map<String, dynamic> json) {
    return VehicleResult(
      vehicleType: _toStringValue(json['vehicle_type']),
      vehicleCount: _toInt(json['vehicle_count']),
      vehiclePurpose: _toStringValue(json['vehicle_purpose']),
      vehicleHourlyCostRs: _toInt(json['vehicle_hourly_cost_rs']),
      vehicleDailyRentalRs: _toInt(json['vehicle_daily_rental_rs']),
      vehicleFuelLph: _toDouble(json['vehicle_fuel_lph']),
      vehicleTotalDailyCostRs: _toInt(json['vehicle_total_daily_cost_rs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_type': vehicleType,
      'vehicle_count': vehicleCount,
      'vehicle_purpose': vehiclePurpose,
      'vehicle_hourly_cost_rs': vehicleHourlyCostRs,
      'vehicle_daily_rental_rs': vehicleDailyRentalRs,
      'vehicle_fuel_lph': vehicleFuelLph,
      'vehicle_total_daily_cost_rs': vehicleTotalDailyCostRs,
    };
  }
}

class MachineryResult {
  final String machineryType;
  final int machineryCount;
  final String machineryPurpose;
  final int machineryHourlyCostRs;
  final int machineryDailyRentalRs;
  final double machineryFuelLph;
  final int machineryTotalDailyCostRs;

  const MachineryResult({
    required this.machineryType,
    required this.machineryCount,
    required this.machineryPurpose,
    required this.machineryHourlyCostRs,
    required this.machineryDailyRentalRs,
    required this.machineryFuelLph,
    required this.machineryTotalDailyCostRs,
  });

  factory MachineryResult.fromJson(Map<String, dynamic> json) {
    return MachineryResult(
      machineryType: _toStringValue(json['machinery_type']),
      machineryCount: _toInt(json['machinery_count']),
      machineryPurpose: _toStringValue(json['machinery_purpose']),
      machineryHourlyCostRs: _toInt(json['machinery_hourly_cost_rs']),
      machineryDailyRentalRs: _toInt(json['machinery_daily_rental_rs']),
      machineryFuelLph: _toDouble(json['machinery_fuel_lph']),
      machineryTotalDailyCostRs: _toInt(json['machinery_total_daily_cost_rs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'machinery_type': machineryType,
      'machinery_count': machineryCount,
      'machinery_purpose': machineryPurpose,
      'machinery_hourly_cost_rs': machineryHourlyCostRs,
      'machinery_daily_rental_rs': machineryDailyRentalRs,
      'machinery_fuel_lph': machineryFuelLph,
      'machinery_total_daily_cost_rs': machineryTotalDailyCostRs,
    };
  }
}

class LabourGangResult {
  final int masonCount;
  final int carpenterCount;
  final int barBenderCount;
  final int plastererCount;
  final int tilerCount;
  final int rooferCount;
  final int painterCount;
  final int mixerOperatorCount;
  final int vibratorOperatorCount;
  final int semiSkilledLabourerCount;
  final int generalLabourerCount;
  final int cleaningLabourerCount;
  final int foremanCount;
  final int surveyAssistantCount;
  final int totalSkilled;
  final int totalSemiSkilled;
  final int totalUnskilled;
  final int totalGang;
  final int labourDailyCostRs;

  const LabourGangResult({
    required this.masonCount,
    required this.carpenterCount,
    required this.barBenderCount,
    required this.plastererCount,
    required this.tilerCount,
    required this.rooferCount,
    required this.painterCount,
    required this.mixerOperatorCount,
    required this.vibratorOperatorCount,
    required this.semiSkilledLabourerCount,
    required this.generalLabourerCount,
    required this.cleaningLabourerCount,
    required this.foremanCount,
    required this.surveyAssistantCount,
    required this.totalSkilled,
    required this.totalSemiSkilled,
    required this.totalUnskilled,
    required this.totalGang,
    required this.labourDailyCostRs,
  });

  factory LabourGangResult.fromJson(Map<String, dynamic> json) {
    return LabourGangResult(
      masonCount: _toInt(json['mason_count']),
      carpenterCount: _toInt(json['carpenter_count']),
      barBenderCount: _toInt(json['bar_bender_count']),
      plastererCount: _toInt(json['plasterer_count']),
      tilerCount: _toInt(json['tiler_count']),
      rooferCount: _toInt(json['roofer_count']),
      painterCount: _toInt(json['painter_count']),
      mixerOperatorCount: _toInt(json['mixer_operator_count']),
      vibratorOperatorCount: _toInt(json['vibrator_operator_count']),
      semiSkilledLabourerCount: _toInt(json['semi_skilled_labourer_count']),
      generalLabourerCount: _toInt(json['general_labourer_count']),
      cleaningLabourerCount: _toInt(json['cleaning_labourer_count']),
      foremanCount: _toInt(json['foreman_count']),
      surveyAssistantCount: _toInt(json['survey_assistant_count']),
      totalSkilled: _toInt(json['total_skilled']),
      totalSemiSkilled: _toInt(json['total_semi_skilled']),
      totalUnskilled: _toInt(json['total_unskilled']),
      totalGang: _toInt(json['total_gang']),
      labourDailyCostRs: _toInt(json['labour_daily_cost_rs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mason_count': masonCount,
      'carpenter_count': carpenterCount,
      'bar_bender_count': barBenderCount,
      'plasterer_count': plastererCount,
      'tiler_count': tilerCount,
      'roofer_count': rooferCount,
      'painter_count': painterCount,
      'mixer_operator_count': mixerOperatorCount,
      'vibrator_operator_count': vibratorOperatorCount,
      'semi_skilled_labourer_count': semiSkilledLabourerCount,
      'general_labourer_count': generalLabourerCount,
      'cleaning_labourer_count': cleaningLabourerCount,
      'foreman_count': foremanCount,
      'survey_assistant_count': surveyAssistantCount,
      'total_skilled': totalSkilled,
      'total_semi_skilled': totalSemiSkilled,
      'total_unskilled': totalUnskilled,
      'total_gang': totalGang,
      'labour_daily_cost_rs': labourDailyCostRs,
    };
  }

  Map<String, int> get activeRoles {
    final roles = <String, int>{
      'Mason': masonCount,
      'Carpenter': carpenterCount,
      'Bar Bender': barBenderCount,
      'Plasterer': plastererCount,
      'Tiler': tilerCount,
      'Roofer': rooferCount,
      'Painter': painterCount,
      'Mixer Operator': mixerOperatorCount,
      'Vibrator Operator': vibratorOperatorCount,
      'Semi-Skilled Labourer': semiSkilledLabourerCount,
      'General Labourer': generalLabourerCount,
      'Cleaning Labourer': cleaningLabourerCount,
      'Foreman': foremanCount,
      'Survey Assistant': surveyAssistantCount,
    };

    final active = <String, int>{};
    roles.forEach((key, value) {
      if (value > 0) {
        active[key] = value;
      }
    });
    return active;
  }

  Map<String, int> get skillBreakdown {
    return {
      'Skilled': totalSkilled,
      'Semi-Skilled': totalSemiSkilled,
      'Unskilled': totalUnskilled,
    };
  }
}

class FuelAnalysis {
  final double vehicleFuelLphTotal;
  final double machineryFuelLphTotal;
  final double totalFuelLph;
  final double totalFuelPerDayLitres;
  final double fuelCostPerDayRs;
  final String efficiencyRating;

  const FuelAnalysis({
    required this.vehicleFuelLphTotal,
    required this.machineryFuelLphTotal,
    required this.totalFuelLph,
    required this.totalFuelPerDayLitres,
    required this.fuelCostPerDayRs,
    required this.efficiencyRating,
  });

  factory FuelAnalysis.fromJson(Map<String, dynamic> json) {
    return FuelAnalysis(
      vehicleFuelLphTotal: _toDouble(json['vehicle_fuel_lph_total']),
      machineryFuelLphTotal: _toDouble(json['machinery_fuel_lph_total']),
      totalFuelLph: _toDouble(json['total_fuel_lph']),
      totalFuelPerDayLitres: _toDouble(json['total_fuel_per_day_litres']),
      fuelCostPerDayRs: _toDouble(json['fuel_cost_per_day_rs']),
      efficiencyRating: _toStringValue(json['efficiency_rating']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_fuel_lph_total': vehicleFuelLphTotal,
      'machinery_fuel_lph_total': machineryFuelLphTotal,
      'total_fuel_lph': totalFuelLph,
      'total_fuel_per_day_litres': totalFuelPerDayLitres,
      'fuel_cost_per_day_rs': fuelCostPerDayRs,
      'efficiency_rating': efficiencyRating,
    };
  }
}

class CostSummary {
  final int vehicleDailyCostRs;
  final int machineryDailyCostRs;
  final int labourDailyCostRs;
  final int totalDailyCostRs;
  final int workingDays;
  final int taskTotalCostRs;

  const CostSummary({
    required this.vehicleDailyCostRs,
    required this.machineryDailyCostRs,
    required this.labourDailyCostRs,
    required this.totalDailyCostRs,
    required this.workingDays,
    required this.taskTotalCostRs,
  });

  factory CostSummary.fromJson(Map<String, dynamic> json) {
    return CostSummary(
      vehicleDailyCostRs: _toInt(json['vehicle_daily_cost_rs']),
      machineryDailyCostRs: _toInt(json['machinery_daily_cost_rs']),
      labourDailyCostRs: _toInt(json['labour_daily_cost_rs']),
      totalDailyCostRs: _toInt(json['total_daily_cost_rs']),
      workingDays: _toInt(json['working_days']),
      taskTotalCostRs: _toInt(json['task_total_cost_rs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_daily_cost_rs': vehicleDailyCostRs,
      'machinery_daily_cost_rs': machineryDailyCostRs,
      'labour_daily_cost_rs': labourDailyCostRs,
      'total_daily_cost_rs': totalDailyCostRs,
      'working_days': workingDays,
      'task_total_cost_rs': taskTotalCostRs,
    };
  }
}

class WasteRecommendation {
  final String category;
  final String recommendation;
  final double estimatedSavingPct;

  const WasteRecommendation({
    required this.category,
    required this.recommendation,
    required this.estimatedSavingPct,
  });

  factory WasteRecommendation.fromJson(Map<String, dynamic> json) {
    return WasteRecommendation(
      category: _toStringValue(json['category']),
      recommendation: _toStringValue(json['recommendation']),
      estimatedSavingPct: _toDouble(json['estimated_saving_pct']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'recommendation': recommendation,
      'estimated_saving_pct': estimatedSavingPct,
    };
  }
}

class TaskPrediction {
  final int taskSequence;
  final String taskName;
  final String boqDescription;
  final int boqAmountRs;
  final VehicleResult vehicle;
  final MachineryResult machinery;
  final LabourGangResult labour;
  final FuelAnalysis fuel;
  final CostSummary costSummary;

  const TaskPrediction({
    required this.taskSequence,
    required this.taskName,
    required this.boqDescription,
    required this.boqAmountRs,
    required this.vehicle,
    required this.machinery,
    required this.labour,
    required this.fuel,
    required this.costSummary,
  });

  factory TaskPrediction.fromJson(Map<String, dynamic> json) {
    return TaskPrediction(
      taskSequence: _toInt(json['task_sequence']),
      taskName: _toStringValue(json['task_name']),
      boqDescription: _toStringValue(json['boq_description']),
      boqAmountRs: _toInt(json['boq_amount_rs']),
      vehicle: VehicleResult.fromJson(Map<String, dynamic>.from(json['vehicle'] ?? const {})),
      machinery: MachineryResult.fromJson(Map<String, dynamic>.from(json['machinery'] ?? const {})),
      labour: LabourGangResult.fromJson(Map<String, dynamic>.from(json['labour'] ?? const {})),
      fuel: FuelAnalysis.fromJson(Map<String, dynamic>.from(json['fuel'] ?? const {})),
      costSummary: CostSummary.fromJson(Map<String, dynamic>.from(json['cost_summary'] ?? const {})),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_sequence': taskSequence,
      'task_name': taskName,
      'boq_description': boqDescription,
      'boq_amount_rs': boqAmountRs,
      'vehicle': vehicle.toJson(),
      'machinery': machinery.toJson(),
      'labour': labour.toJson(),
      'fuel': fuel.toJson(),
      'cost_summary': costSummary.toJson(),
    };
  }
}

class ProjectTotals {
  final int totalVehicleCostRs;
  final int totalMachineryCostRs;
  final int totalLabourCostRs;
  final int totalDailyCostRs;
  final int grandTotalCostRs;
  final int totalGangHeadcountPeak;
  final String peakTask;
  final double averageFuelPerDayLitres;
  final int boqTotalRs;

  const ProjectTotals({
    required this.totalVehicleCostRs,
    required this.totalMachineryCostRs,
    required this.totalLabourCostRs,
    required this.totalDailyCostRs,
    required this.grandTotalCostRs,
    required this.totalGangHeadcountPeak,
    required this.peakTask,
    required this.averageFuelPerDayLitres,
    required this.boqTotalRs,
  });

  factory ProjectTotals.fromJson(Map<String, dynamic> json) {
    return ProjectTotals(
      totalVehicleCostRs: _toInt(json['total_vehicle_cost_rs']),
      totalMachineryCostRs: _toInt(json['total_machinery_cost_rs']),
      totalLabourCostRs: _toInt(json['total_labour_cost_rs']),
      totalDailyCostRs: _toInt(json['total_daily_cost_rs']),
      grandTotalCostRs: _toInt(json['grand_total_cost_rs']),
      totalGangHeadcountPeak: _toInt(json['total_gang_headcount_peak']),
      peakTask: _toStringValue(json['peak_task']),
      averageFuelPerDayLitres: _toDouble(json['average_fuel_per_day_litres']),
      boqTotalRs: _toInt(json['boq_total_rs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_vehicle_cost_rs': totalVehicleCostRs,
      'total_machinery_cost_rs': totalMachineryCostRs,
      'total_labour_cost_rs': totalLabourCostRs,
      'total_daily_cost_rs': totalDailyCostRs,
      'grand_total_cost_rs': grandTotalCostRs,
      'total_gang_headcount_peak': totalGangHeadcountPeak,
      'peak_task': peakTask,
      'average_fuel_per_day_litres': averageFuelPerDayLitres,
      'boq_total_rs': boqTotalRs,
    };
  }
}

class PredictionResponse {
  final String projectId;
  final String projectName;
  final String projectType;
  final String siteLocation;
  final int totalFloorAreaSqft;
  final int numberOfFloors;
  final double buildingComplexityIndex;
  final int workingDays;
  final int tasksDetected;
  final double confidenceScore;
  final String predictedAt;
  final List<TaskPrediction> tasks;
  final ProjectTotals projectTotals;
  final List<WasteRecommendation> wasteRecommendations;

  const PredictionResponse({
    required this.projectId,
    required this.projectName,
    required this.projectType,
    required this.siteLocation,
    required this.totalFloorAreaSqft,
    required this.numberOfFloors,
    required this.buildingComplexityIndex,
    required this.workingDays,
    required this.tasksDetected,
    required this.confidenceScore,
    required this.predictedAt,
    required this.tasks,
    required this.projectTotals,
    required this.wasteRecommendations,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    return PredictionResponse(
      projectId: _toStringValue(json['project_id']),
      projectName: _toStringValue(json['project_name']),
      projectType: _toStringValue(json['project_type']),
      siteLocation: _toStringValue(json['site_location']),
      totalFloorAreaSqft: _toInt(json['total_floor_area_sqft']),
      numberOfFloors: _toInt(json['number_of_floors']),
      buildingComplexityIndex: _toDouble(json['building_complexity_index']),
      workingDays: _toInt(json['working_days']),
      tasksDetected: _toInt(json['tasks_detected']),
      confidenceScore: _toDouble(json['confidence_score']),
      predictedAt: _toStringValue(json['predicted_at']),
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .map((e) => TaskPrediction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      projectTotals: ProjectTotals.fromJson(Map<String, dynamic>.from(json['project_totals'] ?? const {})),
      wasteRecommendations: (json['waste_recommendations'] as List<dynamic>? ?? const [])
          .map((e) => WasteRecommendation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
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
      'tasks_detected': tasksDetected,
      'confidence_score': confidenceScore,
      'predicted_at': predictedAt,
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'project_totals': projectTotals.toJson(),
      'waste_recommendations': wasteRecommendations.map((e) => e.toJson()).toList(),
    };
  }

  Map<String, dynamic> toHiveMap() {
    return toJson();
  }

  factory PredictionResponse.fromHiveMap(Map map) {
    return PredictionResponse.fromJson(Map<String, dynamic>.from(map));
  }
}

typedef MultiTaskPredictionResponse = PredictionResponse;
