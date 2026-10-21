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
