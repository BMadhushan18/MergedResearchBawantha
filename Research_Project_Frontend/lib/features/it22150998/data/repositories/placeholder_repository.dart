import '../datasources/placeholder_datasource.dart';
import '../models/placeholder_model.dart';

/// Abstract Placeholder Repository for IT22150998
abstract class IPlaceholderRepository {
  Future<List<PlaceholderModel>> getPlaceholders();
}

/// Placeholder Repository Implementation
class PlaceholderRepository implements IPlaceholderRepository {
  final IPlaceholderDataSource dataSource;
  
  PlaceholderRepository({required this.dataSource});
  
  @override
  Future<List<PlaceholderModel>> getPlaceholders() async {
    try {
      return await dataSource.getPlaceholders();
    } catch (e) {
      rethrow;
    }
  }
}
