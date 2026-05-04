import '../models/prediction_model.dart';

/// Abstract Prediction Data Source
abstract class IPredictionDataSource {
  Future<PredictionModel> getPrediction(Map<String, dynamic> boqInput);
  Future<List<PredictionModel>> getPredictionHistory();
}

/// Remote Prediction Data Source
class RemotePredictionDataSource implements IPredictionDataSource {
  @override
  Future<PredictionModel> getPrediction(Map<String, dynamic> boqInput) async {
    // TODO: Call API service to get prediction
    throw UnimplementedError();
  }
  
  @override
  Future<List<PredictionModel>> getPredictionHistory() async {
    // TODO: Call API service to get history
    throw UnimplementedError();
  }
}

/// Local Prediction Data Source
class LocalPredictionDataSource implements IPredictionDataSource {
  @override
  Future<PredictionModel> getPrediction(Map<String, dynamic> boqInput) async {
    // TODO: Get from local cache (Hive)
    throw UnimplementedError();
  }
  
  @override
  Future<List<PredictionModel>> getPredictionHistory() async {
    // TODO: Get from local cache (Hive)
    throw UnimplementedError();
  }
}
