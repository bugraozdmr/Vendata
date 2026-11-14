import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/database_engine.dart';
import 'presentation/providers/database_provider.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class VenDataApp extends StatelessWidget {
  const VenDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VenData',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
