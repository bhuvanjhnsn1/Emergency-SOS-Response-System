import 'package:flutter/material.dart';

/// BLE UUIDs matching the ESP32-C3 firmware
class BleConstants {
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String triggerCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String sosTriggerCommand = 'CMD_TRIGGER_SOS';
  static const Duration scanTimeout = Duration(seconds: 12);
  static const Duration connectionTimeout = Duration(seconds: 10);
}

/// App-wide color palette
class AppColors {
  // Primary dark theme
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF121829);
  static const Color surfaceLight = Color(0xFF1A2138);
  static const Color surfaceBorder = Color(0xFF252D45);

  // Accent colors
  static const Color accentRed = Color(0xFFFF3B5C);
  static const Color accentRedDark = Color(0xFFCC2E4A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentBlue = Color(0xFF448AFF);
  static const Color accentCyan = Color(0xFF18FFFF);
  static const Color accentPurple = Color(0xFFBB86FC);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8A8FA8);
  static const Color textMuted = Color(0xFF505672);

  // Status
  static const Color statusActive = Color(0xFF00E676);
  static const Color statusWarning = Color(0xFFFFD740);
  static const Color statusDanger = Color(0xFFFF3B5C);
  static const Color statusInactive = Color(0xFF505672);

  // Gradients
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF18FFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF448AFF), Color(0xFFBB86FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// SharedPreferences keys
class PrefKeys {
  static const String userName = 'user_name';
  static const String emergencyContactName = 'emergency_contact_name';
  static const String emergencyContactPhone = 'emergency_contact_phone';
  static const String isSetupComplete = 'is_setup_complete';
}
