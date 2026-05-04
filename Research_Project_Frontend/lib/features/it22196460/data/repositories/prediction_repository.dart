import '../datasources/prediction_datasource.dart';
import '../models/prediction_model.dart';

/// Abstract Prediction Repository
abstract class IPredictionRepository {
  Future<PredictionModel> getPrediction(Map<String, dynamic> boqInput);
  Future<List<PredictionModel>> getPredictionHistory();
}

/// Prediction Repository Implementation
class PredictionRepository implements IPredictionRepository {
  final IPredictionDataSource remoteDataSource;
  final IPredictionDataSource localDataSource;
  
  PredictionRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });
  
  @override
  Future<PredictionModel> getPrediction(Map<String, dynamic> boqInput) async {
    try {
      final prediction = await remoteDataSource.getPrediction(boqInput);
      return prediction;
    } catch (e) {
      rethrow;
    }
  }
  
  @override
  Future<List<PredictionModel>> getPredictionHistory() async {
    try {
      final history = await localDataSource.getPredictionHistory();
      return history;
    } catch (e) {
      rethrow;
    }
  }
}
