import 'package:flutter_dotenv/flutter_dotenv.dart';

String get dinethApiBaseUrl {
  final host = dotenv.get('BACKEND_HOST', fallback: '127.0.0.1');
  final port = dotenv.get('BACKEND_PORT', fallback: '8000');
  return 'http://$host:$port/dineth';
}
