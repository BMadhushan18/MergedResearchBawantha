import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AiProviderBase extends ChangeNotifier {
  AiProviderBase({required this.apiKeyStorageKey, required this.modelStorageKey});

  final String apiKeyStorageKey;
  final String modelStorageKey;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _apiKey;
  String? _savedModel;
  bool _loading = false;

  String? get apiKey => _apiKey;
  String? get savedModel => _savedModel;
  bool get loading => _loading;

  Future<void> loadKey() async {
    _loading = true;
    notifyListeners();
    try {
      _apiKey = await _storage.read(key: apiKeyStorageKey);
      _savedModel = await _storage.read(key: modelStorageKey);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveKey(String value) async {
    _loading = true;
    notifyListeners();
    try {
      _apiKey = value;
      await _storage.write(key: apiKeyStorageKey, value: value);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> clearKey() async {
    _loading = true;
    notifyListeners();
    try {
      _apiKey = null;
      await _storage.delete(key: apiKeyStorageKey);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveModelName(String value) async {
    _savedModel = value;
    await _storage.write(key: modelStorageKey, value: value);
    notifyListeners();
  }

  Future<void> clearModelName() async {
    _savedModel = null;
    await _storage.delete(key: modelStorageKey);
    notifyListeners();
  }

  Future<String> testPrompt(String prompt, {String? model});
}