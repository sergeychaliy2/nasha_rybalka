import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_store.dart';
import '../data/content_overrides.dart';
import 'admin_app.dart';

/// Точка входа админки «Заветная Рыбалка».
/// Запуск: flutter run -t lib/admin/main.dart -d windows
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // applyToGame и в админке: activeLocations/activeWaterGeo/activeTournaments
  // отражают правки (например, свои локации видны в выборе места турнира).
  final overrides = ContentOverrides(prefs)
    ..load()
    ..applyToGame();
  runApp(AdminApp(overrides: overrides, accounts: AccountStore(prefs)));
}
