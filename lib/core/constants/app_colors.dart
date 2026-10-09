import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary green palette
  static const Color primary     = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight= Color(0xFF4CAF50);
  static const Color secondary   = Color(0xFF4CAF50);
  static const Color secondaryLight = Color(0xFF81C784);

  // Backgrounds
  static const Color background  = Color(0xFFF7FAF7);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceMuted= Color(0xFFF1F8F1);
  static const Color sidebarBg   = Color(0xFF1A3A1C);
  static const Color sidebarSelected = Color(0xFF2E7D32);

  // Text
  static const Color textPrimary   = Color(0xFF1A2E1A);
  static const Color textSecondary = Color(0xFF4A6741);
  static const Color textMuted     = Color(0xFF7A9478);
  static const Color textOnDark    = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0xFFB2DFDB);

  // Status — reserved for alerts/states only
  static const Color info    = Color(0xFF1976D2);
  static const Color warning = Color(0xFFF57C00);
  static const Color danger  = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);

  // Risk levels
  static const Color riskLow      = Color(0xFF43A047);
  static const Color riskMedium   = Color(0xFFFFA000);
  static const Color riskHigh     = Color(0xFFF4511E);
  static const Color riskCritical = Color(0xFFB71C1C);

  // UI chrome
  static const Color border  = Color(0xFFE0EDE0);
  static const Color divider = Color(0xFFEEF5EE);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFF7FAF7), Color(0xFFEDF5ED)],
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF1A3A1C), Color(0xFF0D2410)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  );
}
