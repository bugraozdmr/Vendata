import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/database_engine.dart';
import 'database_provider.dart';

const _themeSettingKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final DatabaseEngine _engine;

  ThemeModeNotifier(this._engine) : super(_read(_engine));

  static ThemeMode _read(DatabaseEngine engine) {
    return engine.getSetting(_themeSettingKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  void setDark(bool dark) {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    _engine.setSetting(_themeSettingKey, dark ? 'dark' : 'light');
  }

  void toggle() => setDark(state != ThemeMode.dark);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(databaseEngineProvider));
});
