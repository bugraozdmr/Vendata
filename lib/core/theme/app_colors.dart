import 'package:flutter/material.dart';

/// Central palette. The values are resolved at read-time so the whole app can
/// switch between the light and dark palette by calling [setDark].
class AppColors {
  AppColors._();

  static bool _isDark = false;

  static bool get isDark => _isDark;

  static void setDark(bool value) {
    _isDark = value;
  }

  static Color _pick(Color light, Color dark) => _isDark ? dark : light;

  // Core Brand & Background - Blockit Aesthetic
  static Color get primary => _pick(
        const Color(0xFF16171D),
        const Color(0xFF26272F),
      );
  static Color get accent => const Color(0xFFEE5D36);
  static Color get accentLight => _pick(
        const Color(0xFFFFF0EC),
        const Color(0xFF3A211A),
      );
  static Color get primaryWash => _pick(
        const Color(0xFFEFECE6),
        const Color(0xFF23242C),
      );

  static Color get background => _pick(
        const Color(0xFFF7F5F0),
        const Color(0xFF101116),
      );
  static Color get surface => _pick(
        Colors.white,
        const Color(0xFF191A21),
      );
  static Color get card => surface;
  static Color get cardMuted => _pick(
        const Color(0xFFEFECE6),
        const Color(0xFF25262E),
      );

  static Color get border => _pick(
        const Color(0xFFE6E3DB),
        const Color(0xFF2E2F38),
      );
  static Color get borderDarker => _pick(
        const Color(0xFFD4D0C6),
        const Color(0xFF3C3D48),
      );

  // Typography
  static Color get textPrimary => _pick(
        const Color(0xFF16171D),
        const Color(0xFFF4F3EF),
      );
  static Color get textSecondary => _pick(
        const Color(0xFF6B6C77),
        const Color(0xFFA8A9B4),
      );
  static Color get textMuted => _pick(
        const Color(0xFFA0A1AC),
        const Color(0xFF6F7079),
      );

  // Functional Accents & Backward Compatibility
  static Color get success => _pick(
        const Color(0xFF26A669),
        const Color(0xFF34C77B),
      );
  static Color get successWash => _pick(
        const Color(0xFFEAF7F0),
        const Color(0xFF12281D),
      );
  static Color get warning => _pick(
        const Color(0xFFF59E0B),
        const Color(0xFFF5A623),
      );
  static Color get warningWash => _pick(
        const Color(0xFFFEF9ED),
        const Color(0xFF2C2412),
      );
  static Color get error => _pick(
        const Color(0xFFE11D48),
        const Color(0xFFFB7185),
      );
  static Color get errorWash => _pick(
        const Color(0xFFFDF0F2),
        const Color(0xFF33161D),
      );

  static Color get accentBlue => _pick(
        const Color(0xFF2563EB),
        const Color(0xFF60A5FA),
      );
  static Color get accentBlueWash => _pick(
        const Color(0xFFEFF6FF),
        const Color(0xFF16243D),
      );
  static Color get accentGreen => success;
  static Color get accentGreenWash => successWash;
  static Color get accentAmber => warning;
  static Color get accentAmberWash => warningWash;
  static Color get accentRose => error;
  static Color get accentRoseWash => errorWash;
  static Color get accentPurple => _pick(
        const Color(0xFF7C3AED),
        const Color(0xFFA78BFA),
      );

  // Code / SQL Editor
  static Color get codeBackground => _pick(
        const Color(0xFFF7F5F0),
        const Color(0xFF15161C),
      );
  static Color get codeBorder => border;
  static Color get codeText => textPrimary;
}
