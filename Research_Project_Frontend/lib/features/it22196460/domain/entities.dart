/// Domain Entities for IT22196460 Feature
/// These are high-level business logic entities independent of data layer

class Prediction {
  final String id;
  final String boqTitle;
  final double predictedCost;
  final DateTime createdAt;
  final Map<String, dynamic> boqData;
  
  Prediction({
    required this.id,
    required this.boqTitle,
    required this.predictedCost,
    required this.createdAt,
    required this.boqData,
  });
}
