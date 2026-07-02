import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Тёмная, сдержанная, «мужская» тема. Минимум перегруза.
abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.surface,
      primary: AppColors.accent,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      useMaterial3: true,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
