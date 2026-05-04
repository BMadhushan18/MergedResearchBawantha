import '../models/placeholder_model.dart';

/// Abstract Placeholder Data Source for IT22150998
abstract class IPlaceholderDataSource {
  Future<List<PlaceholderModel>> getPlaceholders();
}

/// Remote Placeholder Data Source
class RemotePlaceholderDataSource implements IPlaceholderDataSource {
  @override
  Future<List<PlaceholderModel>> getPlaceholders() async {
    // TODO: Implement API call
    throw UnimplementedError();
  }
}
