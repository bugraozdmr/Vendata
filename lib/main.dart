import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/services/database_engine.dart';
import 'presentation/providers/database_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();

  final appDocDir = await getApplicationDocumentsDirectory();
  final dbPath = '${appDocDir.path}/vendata_storage.db';
  final engine = DatabaseEngine(dbPath: dbPath);

  runApp(
    ProviderScope(
      overrides: [
        databaseEngineProvider.overrideWithValue(engine),
      ],
      child: const VenDataApp(),
    ),
  );
}

class VenDataApp extends ConsumerWidget {
  const VenDataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;

    final lightTheme = AppTheme.build(Brightness.light);
    final darkTheme = AppTheme.build(Brightness.dark);
    AppColors.setDark(isDark);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      home: const SplashScreen(),
    );
  }
}
