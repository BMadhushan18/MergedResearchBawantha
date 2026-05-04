/// BOQ Prediction Model for IT22196460 Feature
class PredictionModel {
  final String id;
  final String boqTitle;
  final double predictedCost;
  final DateTime createdAt;
  final Map<String, dynamic> boqData;
  
  PredictionModel({
    required this.id,
    required this.boqTitle,
    required this.predictedCost,
    required this.createdAt,
    required this.boqData,
  });
  
  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      id: json['id'] as String,
      boqTitle: json['boqTitle'] as String,
      predictedCost: (json['predictedCost'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      boqData: json['boqData'] as Map<String, dynamic>,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boqTitle': boqTitle,
      'predictedCost': predictedCost,
      'createdAt': createdAt.toIso8601String(),
      'boqData': boqData,
    };
  }
}
