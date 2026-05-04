import '../config/app_config.dart' as backend_config;
import 'package:flutter/material.dart';

class AppColors {
  // Primary orange color
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8A5B);
  static const Color primaryDark = Color(0xFFE55100);
  
  // Secondary colors
  static const Color secondary = Color(0xFF2196F3);
  static const Color accent = Color(0xFFFFAB40);
  
  // Background colors (white theme)
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF2196F3);
  
  // Card colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x1A000000);
  
  // Border colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
}

class AppConfig {
  // Keep legacy consumers pointed at the same backend config as auth/services.
  static String get apiBaseUrl => backend_config.AppConfig.baseUrl;

  // Minimum images required for 3D reconstruction
  static const int minImages = 20;

  // Maximum images
  static const int maxImages = 50;

  // Recommended images
  static const int recommendedImages = 30;

  // Image quality (0.0 - 1.0)
  static const double imageQuality = 0.85;

  // Capture delay in milliseconds
  static const int captureDelay = 500;
}

class AppConstants {
  // Backend base URL
  static String get baseUrl => AppConfig.apiBaseUrl;
}

class AppStrings {
  static const String appTitle = '3D Object Scanner';
  static const String captureInstructions = 'Move around the object slowly\n'
      'Keep the object centered\n'
      'Maintain consistent distance';
}
