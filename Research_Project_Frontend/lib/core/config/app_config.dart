import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App Configuration
class AppConfig {
  static const String appName = 'Smart BOQ Predictor';
  static const String appVersion = '1.0.0';

  // API Configuration
  static String get baseUrl =>
      'http://${dotenv.get('BACKEND_HOST', fallback: '127.0.0.1')}:${dotenv.get('BACKEND_PORT', fallback: '8000')}';
  static const String apiTimeout = '30000'; // milliseconds

  // Database
  static const String dbName = 'smart_boq_predictor.db';
}
