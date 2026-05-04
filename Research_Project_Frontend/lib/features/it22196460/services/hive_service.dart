import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/boq_input.dart';
import '../utils/constants.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.openBox(AppConstants.offlineHistoryBox);
    await Hive.openBox(AppConstants.settingsBox);
  }

  Box get _historyBox => Hive.box(AppConstants.offlineHistoryBox);
  Box get _settingsBox => Hive.box(AppConstants.settingsBox);

  Future<void> saveOfflineUpload(OfflineUploadRecord record) async {
    await _historyBox.put(record.id, jsonEncode(record.toJson()));
  }

  List<OfflineUploadRecord> getOfflineUploads() {
    return _historyBox.values
        .map((value) => OfflineUploadRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(value as String) as Map)))
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  Future<void> setBaseUrl(String url) async {
    await _settingsBox.put(AppConstants.baseUrlHiveKey, url);
  }

  String? getBaseUrl() {
    return _settingsBox.get(AppConstants.baseUrlHiveKey) as String?;
  }
}
