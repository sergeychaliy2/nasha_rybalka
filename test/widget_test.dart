import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nasha_rybalka/app/providers.dart';
import 'package:nasha_rybalka/features/menu/main_menu_screen.dart';
import 'package:nasha_rybalka/main.dart';

void main() {
  testWidgets('Сплэш показывает логотип и загрузку',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NashaRybalkaApp(),
    ));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('НАША РЫБАЛКА'), findsOneWidget);
    expect(find.textContaining('Загрузка'), findsOneWidget);
  });

  testWidgets('Главное меню показывает пункты по рефу',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: MainMenuScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('НАЧАТЬ ИГРУ'), findsOneWidget);
    expect(find.text('НАСТРОЙКИ'), findsOneWidget);
    expect(find.text('ОБ ИГРЕ'), findsOneWidget);
    expect(find.text('ВЫХОД'), findsOneWidget);
  });
}
