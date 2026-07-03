import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nasha_rybalka/app/providers.dart';
import 'package:nasha_rybalka/features/menu/main_menu_screen.dart';
import 'package:nasha_rybalka/main.dart';
import 'package:nasha_rybalka/shared/sound_service.dart';

void main() {
  // В виджет-тестах не проигрываем музыку: иначе fade-таймер (Timer.periodic),
  // запускаемый в dispose() меню, остаётся «pending» после разбора дерева и
  // роняет тест. При выключенной музыке stopMenuMusic идёт по ветке без таймера.
  setUp(() {
    SoundService.musicEnabled = false;
  });

  testWidgets('Сплэш показывает логотип и загрузку',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NashaRybalkaApp(),
    ));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('ЗАВЕТНАЯ РЫБАЛКА'), findsOneWidget);
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
