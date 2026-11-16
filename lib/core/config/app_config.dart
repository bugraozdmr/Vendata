import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._();

  static String appName = 'Vendata';
  static String appVersion = '1.0.0';
  static String openRouterApiKey = '';
  static String geminiApiKey = '';

  static Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('.env');
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join('=').trim();
          if (key == 'APP_NAME') appName = val;
          if (key == 'APP_VERSION') appVersion = val;
          if (key == 'OPENROUTER_API_KEY') openRouterApiKey = val;
          if (key == 'GEMINI_API_KEY') geminiApiKey = val;
        }
      }
    } catch (_) {}
  }
}

