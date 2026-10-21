import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'IntelliSpace';
  static const String appVersion = '1.0.0';

  // UI Constants
  static const double borderRadius = 16.0;
  static const double defaultPadding = 16.0;

  // Status Colors
  static const Color statusGreen = Color(0xFF10B981);
  static const Color statusOrange = Color(0xFFF59E0B);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color statusBlue = Color(0xFF3B82F6);
  static const Color statusOffline = Color(0xFF6B7280);

  // Asset paths (Placeholders for now)
  static const String defaultAvatar = 'assets/images/default_avatar.png';
}

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}

enum AppRole {
  administrator,
  teacher,
}

enum DeviceStatus {
  online,
  offline,
}

enum DeviceType {
  light,
  fan,
  ac,
  projector,
  power,
  other,
}

enum SeverityLevel {
  info,
  warning,
  critical,
}
