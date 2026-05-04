import 'package:flutter/foundation.dart';

/// Switch between Firebase and MongoDB backends.
/// kUseMongo = true  → MongoDB REST backend (active)
/// kUseMongo = false → Firebase/Firestore (disabled but code preserved)
class AppConfig {
  AppConfig._();

  static const bool kUseMongo = true;

  /// PC's local WiFi IP — Android device must be on the same network.
  static const String _defaultLanIp = '192.168.8.103';
  // Core Mongo backend (auth/projects/subcollections).
  /// Optional overrides:
  /// flutter run --dart-define=BACKEND_HOST=192.168.x.x --dart-define=BACKEND_PORT=8090
  static const String _backendHostOverride =
      String.fromEnvironment('BACKEND_HOST', defaultValue: '');
    static const int backendPort =
      int.fromEnvironment('BACKEND_PORT', defaultValue: 8008);

  /// PC's LAN IP — keep this in sync with the machine running app.py.
  /// For Android emulator use 10.0.2.2; for a real device use the PC's WiFi IP.
  static String get backendHost {
    if (_backendHostOverride.isNotEmpty) return _backendHostOverride;

    if (kIsWeb) return '127.0.0.1';

    // Real Android device on the same WiFi — use the PC's LAN IP directly.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _defaultLanIp;
    }

    // Windows / Linux / macOS desktop and iOS simulator
    return '127.0.0.1';
  }

  // IT22574718 backend module (ML + phase progress tracking).
  static const int itBackendPort = 8091;

  // 3D Reconstruction routes are now served by the combined backend on the same port.
  static const int recon3dPort =
      int.fromEnvironment('RECON3D_PORT', defaultValue: 8000);

  static String get baseUrl => 'http://$backendHost:$backendPort';
  static String get itBaseUrl => 'http://$backendHost:$itBackendPort';
  static String get recon3dBaseUrl => 'http://$backendHost:$recon3dPort';

  static String get recon3dWsBaseUrl {
    final hostPort = '$backendHost:$recon3dPort';
    return kIsWeb ? 'wss://$hostPort' : 'ws://$hostPort';
  }
}
