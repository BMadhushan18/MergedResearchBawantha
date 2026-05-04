import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get defaultBaseUrl =>
      'http://${dotenv.get('BACKEND_HOST', fallback: '127.0.0.1')}:${dotenv.get('BACKEND_PORT', fallback: '8000')}';
  static const String baseUrlHiveKey = 'base_url';

  static const String predictFileEndpoint = '/api/v1/boq/upload';
  static const String generateProcurementPdfEndpoint =
      '/api/v1/generate_procurement_pdf';
  static const String dashboardSummaryEndpoint = '/api/v1/dashboard/summary';
  static const String dashboardSavePredictionEndpoint =
      '/api/v1/dashboard/save_prediction';
  static const String dashboardHistoryEndpoint = '/api/v1/dashboard/history';
  static const String dashboardHistoryAllEndpoint = '/api/v1/dashboard/history';

  static const List<String> allowedExtensions = [
    'pdf',
    'xlsx',
    'xls',
    'csv',
    'txt',
  ];

  static const String offlineHistoryBox = 'offline_history_box';
  static const String settingsBox = 'settings_box';
}

const Map<String, String> kRoleLabels = {
  'mason_count': 'Mason',
  'carpenter_count': 'Carpenter',
  'bar_bender_count': 'Bar Bender',
  'plasterer_count': 'Plasterer',
  'tiler_count': 'Tiler',
  'roofer_count': 'Roofer',
  'painter_count': 'Painter',
  'mixer_operator_count': 'Mixer Operator',
  'vibrator_operator_count': 'Vibrator Operator',
  'semi_skilled_labourer_count': 'Semi-Skilled Labourer',
  'general_labourer_count': 'General Labourer',
  'cleaning_labourer_count': 'Cleaning Labourer',
  'foreman_count': 'Foreman',
  'survey_assistant_count': 'Survey Assistant',
};

const Map<String, IconData> kRoleIcons = {
  'Mason': Icons.construction,
  'Carpenter': Icons.carpenter,
  'Bar Bender': Icons.account_tree,
  'Plasterer': Icons.format_paint,
  'Tiler': Icons.grid_view,
  'Roofer': Icons.roofing,
  'Painter': Icons.brush,
  'Mixer Operator': Icons.rotate_right,
  'Vibrator Operator': Icons.vibration,
  'Semi-Skilled Labourer': Icons.engineering,
  'General Labourer': Icons.person,
  'Cleaning Labourer': Icons.cleaning_services,
  'Foreman': Icons.manage_accounts,
  'Survey Assistant': Icons.gps_fixed,
};

const Map<String, int> kRoleDailyRates = {
  'Mason': 3200,
  'Carpenter': 3200,
  'Bar Bender': 2700,
  'Plasterer': 3200,
  'Tiler': 2700,
  'Roofer': 3200,
  'Painter': 3500,
  'Mixer Operator': 2600,
  'Vibrator Operator': 2600,
  'Semi-Skilled Labourer': 2500,
  'General Labourer': 2400,
  'Cleaning Labourer': 2550,
  'Foreman': 3200,
  'Survey Assistant': 2600,
};

Color efficiencyColor(String rating) {
  switch (rating) {
    case 'Excellent':
      return const Color(0xFF388E3C);
    case 'Good':
      return const Color(0xFF00695C);
    case 'Fair':
      return const Color(0xFFF57F17);
    default:
      return const Color(0xFFC62828);
  }
}
