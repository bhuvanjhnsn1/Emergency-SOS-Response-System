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
  // Primary dark theme (Siren Theme)
  static const Color background = Color(0xFF090A0F);
  static const Color surface = Color(0xFF111422);
  static const Color surfaceLight = Color(0xFF1A1F35);
  static const Color surfaceBorder = Color(0xFF1D2235);

  // Accent colors
  static const Color accentRed = Color(0xFFFF3B30); // Siren Coral Red
  static const Color accentRedDark = Color(0xFFD32F2F);
  static const Color accentOrange = Color(0xFFFF9500);
  static const Color accentGreen = Color(0xFF34C759); // Safety Emerald
  static const Color accentBlue = Color(0xFF007AFF); // Electric Azure
  static const Color accentCyan = Color(0xFF32ADE6);
  static const Color accentPurple = Color(0xFFAF52DE);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF48484A);

  // Status
  static const Color statusActive = Color(0xFF34C759);
  static const Color statusWarning = Color(0xFFFFCC00);
  static const Color statusDanger = Color(0xFFFF3B30);
  static const Color statusInactive = Color(0xFF48484A);

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
  static const String userPhone = 'user_phone';
  static const String emergencyContactName = 'emergency_contact_name';
  static const String emergencyContactPhone = 'emergency_contact_phone';
  static const String isSetupComplete = 'is_setup_complete';
}
