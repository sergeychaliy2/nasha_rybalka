import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/providers.dart';
import 'app/theme/app_theme.dart';
import 'data/content_overrides.dart';
import 'features/splash/splash_screen.dart';
import 'shared/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Правки контента из админки (зоны заброса, аудио-дефолты и пр.) — до UI.
  ContentOverrides(prefs)
    ..load()
    ..applyToGame();
  // Аудио: сперва админ-дефолты (внутри applyToGame), затем настройки игрока.
  SoundService.loadFromPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NashaRybalkaApp(),
    ),
  );
}

/// «Наша Рыбалка» — локальная сборка.
///
/// Поток: сплэш → рисованное главное меню → карта России по регионам
/// (реальные границы) → водоём → сцена ловли. Разделы (магазин, снаряжение,
/// профиль, бестиарий, турниры, достижения) — окнами поверх сцены.
class NashaRybalkaApp extends StatelessWidget {
  const NashaRybalkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Наша Рыбалка',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
