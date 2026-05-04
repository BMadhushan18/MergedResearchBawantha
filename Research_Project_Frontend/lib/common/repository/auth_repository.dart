import '../models/user_model.dart';

/// Abstract Auth Repository
abstract class IAuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> signup(String name, String email, String password);
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
}

/// Auth Repository Implementation
class AuthRepository implements IAuthRepository {
  @override
  Future<UserModel> login(String email, String password) async {
    // TODO: Implement login call to backend
    throw UnimplementedError();
  }
  
  @override
  Future<UserModel> signup(String name, String email, String password) async {
    // TODO: Implement signup call to backend
    throw UnimplementedError();
  }
  
  @override
  Future<void> logout() async {
    // TODO: Implement logout logic
    throw UnimplementedError();
  }
  
  @override
  Future<UserModel?> getCurrentUser() async {
    // TODO: Implement get current user logic
    throw UnimplementedError();
  }
}
