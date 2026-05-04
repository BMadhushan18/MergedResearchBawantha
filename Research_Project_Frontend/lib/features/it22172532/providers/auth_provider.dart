import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/mongo_api_service.dart';
import '../config/app_config.dart';

/// MongoDB-backed auth provider.
/// Drop-in replacement for Firebase AuthProvider — same public interface.
class AuthProvider extends ChangeNotifier {
  final MongoApiService _api = MongoApiService();

  UserModel? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  UserModel? get userProfile    => _userProfile;
  bool get isLoading            => _isLoading;
  String? get errorMessage      => _errorMessage;
  bool get isAuthenticated      => _userProfile != null;
  bool get initialized          => _initialized;

  AuthProvider() {
    _restoreSession();
  }

  /// Try to restore a saved session on app launch.
  Future<void> _restoreSession() async {
    await _api.loadToken();
    if (_api.hasToken) {
      try {
        final userData = await _api.me();
        if (userData != null) {
          _userProfile = _userFromMap(userData);
        }
      } catch (_) {
        // Token expired or invalid — stay logged out
      }
    }
    _initialized = true;
    notifyListeners();
  }

  UserModel _userFromMap(Map<String, dynamic> d) => UserModel(
        uid:         d['uid']         ?? '',
        email:       d['email']       ?? '',
        displayName: d['displayName'] ?? '',
        createdAt:   d['createdAt'] != null
            ? (DateTime.tryParse(d['createdAt']) ?? DateTime.now())
            : DateTime.now(),
        lastLoginAt: d['lastLoginAt'] != null
            ? (DateTime.tryParse(d['lastLoginAt']) ?? DateTime.now())
            : DateTime.now(),
      );

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sign in with email + password.
  /// Returns true on success, false on failure (check [errorMessage]).
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final userData = await _api.signin(email.trim(), password.trim());
      _userProfile = _userFromMap(userData);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Create account with email, password, displayName.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final userData = await _api.signup(email.trim(), password.trim(), displayName.trim());
      _userProfile = _userFromMap(userData);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Sends a password-reset email (server-side placeholder).
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _api.post('/auth/reset-password', {'email': email.trim()});
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _api.signout();
    _userProfile = null;
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid email or password')) return 'Invalid email or password';
    if (raw.contains('Email already in use'))      return 'Email already in use';
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'Cannot reach server at ${AppConfig.baseUrl}. Check your network or backend.';
    }
    if (raw.contains('TimeoutException')) {
      return 'Request timed out while connecting to ${AppConfig.baseUrl}. Try again.';
    }
    return raw.replaceFirst('Exception: ', '');
  }
}
