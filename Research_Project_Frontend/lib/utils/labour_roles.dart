import 'package:flutter/material.dart';

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
