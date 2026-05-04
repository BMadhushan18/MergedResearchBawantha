import 'package:flutter/material.dart';

class UserSession {
  final String email;
  final String displayName;
  final String role;
  final DateTime? joinedAt;

  UserSession({
    required this.email,
    required this.displayName,
    required this.role,
    this.joinedAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? 'User',
      role: json['role'] ?? 'user',
      joinedAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}

class SessionService extends ChangeNotifier {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  UserSession? _currentUser;

  UserSession? get currentUser => _currentUser;

  void setSession(UserSession user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearSession() {
    _currentUser = null;
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;
}
