import 'package:flutter/material.dart';

/// App Color Constants for Buildora
class AppColors {
  // Primary Colours
  static const Color flameOrange = Color(0xFFFF5C2E);
  static const Color forgeBlack = Color(0x0A0A0A0A); // Note: 0x0A0A0A is very dark grey/black
  // Wait, the hex in the doc says #0A0A0A. In Flutter Color(0xFF0A0A0A).
  static const Color forgeBlackActual = Color(0xFF0A0A0A);
  static const Color limestone = Color(0xFFF5F3EF);
  static const Color electricBlue = Color(0xFF1A6FFF);

  // Flame Orange Tints
  static const Color orangeLight = Color(0xFFFF8A69);
  static const Color orangeBase = Color(0xFFFF5C2E);
  static const Color orangeDark = Color(0xCC3D15); // Wait, #CC3D15 is hex. In Flutter: Color(0xFFCC3D15)
  static const Color orangeDarkActual = Color(0xFFCC3D15);
  static const Color orangeDeep = Color(0xFF8A2208);
  static const Color orangeBlack = Color(0xFF3D0D02);

  // Neutral Scale
  static const Color neutral100 = Color(0xFFF5F3EF); // Limestone
  static const Color neutral200 = Color(0xFFE8E4DD); // Light stone
  static const Color neutral300 = Color(0xFFD2CBBD); // Mid stone
  static const Color neutral400 = Color(0xFFA89E8E); // Warm grey
  static const Color neutral500 = Color(0xFF6B6358); // Dark stone
  static const Color neutral600 = Color(0xFF2E2E2E); // Near black
  static const Color neutral700 = Color(0xFF0A0A0A); // Forge black

  // Functional Aliases
  static const Color primary = flameOrange;
  static const Color secondary = forgeBlackActual;
  static const Color background = limestone;
  static const Color surface = Colors.white;
  static const Color textPrimary = neutral700;
  static const Color textSecondary = neutral600;
  static const Color textTertiary = neutral500;
  static const Color divider = neutral200;

  // Status Colors
  static const Color statusActiveBg = Color(0xFFFFF0EB);
  static const Color statusActiveText = Color(0xFFC4340A);
  static const Color statusApprovedBg = Color(0xFFE6F9F1);
  static const Color statusApprovedText = Color(0xFF0F6E48);
  static const Color statusProcessingBg = Color(0xFFEBF2FF);
  static const Color statusProcessingText = Color(0xFF1A4EAB);
  static const Color statusDraftBg = Color(0xFFEAEAEA);
  static const Color statusDraftText = Color(0xFF2A2A2A);
}
