import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_store.dart';
import '../data/content_overrides.dart';
import 'accounts_editor.dart';
import 'audio_editor.dart';
import 'gear_editor.dart';
import 'locations_editor.dart';
import 'species_editor.dart';
import 'tournaments_editor.dart';
import 'tuning_editor.dart';
import 'zone_editor.dart';

const _gold = Color(0xFFE4B857);
const _goldLight = Color(0xFFF6D98A);
const _bg = Color(0xFF0C1116);
const _panel = Color(0xFF161C23);

/// Админ-приложение: редактор всего контента игры поверх сид-дефолтов
/// (правки хранятся в общих SharedPreferences → игра видит после перезапуска).
class AdminApp extends StatelessWidget {
  const AdminApp(
      {super.key,
      required this.overrides,
      required this.accounts,
      required this.prefs});
  final ContentOverrides overrides;
  final AccountStore accounts;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Наша Рыбалка — Админка',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _gold,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: AdminHome(overrides: overrides, accounts: accounts, prefs: prefs),
    );
  }
}

class _Section {
  const _Section(this.title, this.subtitle, this.icon, this.color,
      {this.builder});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function()? builder; // null — «в разработке»
}

class AdminHome extends StatefulWidget {
  const AdminHome(
      {super.key,
      required this.overrides,
      required this.accounts,
      required this.prefs});
  final ContentOverrides overrides;
  final AccountStore accounts;
  final SharedPreferences prefs;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  ContentOverrides get overrides => widget.overrides;

  /// Бэкап всех правок в JSON-файл.
  Future<void> _export() async {
    final loc = await getSaveLocation(
      suggestedName: 'nasha_rybalka_content.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json'])
      ],
    );
    if (loc == null) return;
    File(loc.path).writeAsStringSync(overrides.exportJson(), encoding: utf8);
    _toast('Экспортировано: ${loc.path}');
  }

  /// Импорт бэкапа: заменяет все правки (сид не трогается).
  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'JSON', extensions: ['json'])
    ]);
    if (file == null) return;
    final ok = overrides.importJson(await file.readAsString());
    if (!ok) {
      _toast('Не удалось прочитать файл — это не JSON правок');
      return;
    }
    await overrides.save();
    overrides.applyToGame();
    setState(() {});
    _toast('Импортировано · игре нужен перезапуск');
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(m),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _panel));
  }

  @override
  Widget build(BuildContext context) {
    final sections = <_Section>[
      _Section(
        'Локации на карте',
        'Создать на карте России, описание, фон, глубина, зарыбление',
        Icons.add_location_alt,
        const Color(0xFF6FBF73),
        builder: () => LocationsEditor(overrides: overrides),
      ),
      _Section(
        'Зоны заброса',
        'Кисть по фону локации: где вода, а где нельзя забрасывать',
        Icons.brush,
        const Color(0xFF56C271),
        builder: () => ZoneEditor(overrides: overrides),
      ),
      _Section(
        'Турниры',
        'Регион, точка на карте, фото, взносы, призы, уровень, боты',
        Icons.emoji_events,
        const Color(0xFFE0864A),
        builder: () => TournamentsEditor(overrides: overrides),
      ),
      _Section(
        'Рыбы и шансы',
        'Каталог видов: вес, редкость, семейство, профиль шансов клёва',
        Icons.set_meal,
        const Color(0xFF5AA9E6),
        builder: () => SpeciesEditor(overrides: overrides),
      ),
      _Section(
        'Магазин и снасти',
        'Все предметы: цены, уровни, классы, характеристики, эхолоты',
        Icons.storefront,
        const Color(0xFFE0B84C),
        builder: () => GearEditor(overrides: overrides),
      ),
      _Section(
        'Продукты и прикормки',
        'Наживки, приманки, прикормки (семейства), спреи, энергия',
        Icons.science,
        const Color(0xFF54C9C9),
        builder: () => GearEditor(overrides: overrides, consumablesOnly: true),
      ),
      _Section(
        'Аккаунты',
        'Мониторинг, создание, роли, блокировка, сброс пароля, рефералы',
        Icons.manage_accounts,
        const Color(0xFF7FB3D5),
        builder: () => AccountsEditor(store: widget.accounts),
      ),
      _Section(
        'Погода и коэффициенты',
        'Прокачка, энергия, формула клёва, вероятность осадков',
        Icons.tune,
        const Color(0xFFB98CFF),
        builder: () => TuningEditor(overrides: overrides),
      ),
      _Section(
        'Аудио игры',
        'Заменить файлы музыки/эффектов и видеть текущие настройки звука',
        Icons.graphic_eq,
        const Color(0xFFD98AC9),
        builder: () => AudioEditor(prefs: widget.prefs),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: _gold, size: 30),
                  const SizedBox(width: 12),
                  Text('Админка · Наша Рыбалка',
                      style: _title(24)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.download, size: 16, color: _gold),
                    label: const Text('Экспорт',
                        style: TextStyle(color: _gold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.upload, size: 16, color: _gold),
                    label: const Text('Импорт',
                        style: TextStyle(color: _gold, fontSize: 12)),
                  ),
                  const SizedBox(width: 14),
                  Text('правки → перезапусти игру',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final s in sections) _card(context, s),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _Section s) {
    final active = s.builder != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: active
          ? () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => s.builder!()))
          : null,
      child: Opacity(
        opacity: active ? 1 : 0.5,
        child: Container(
          width: 300,
          height: 150,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_panel, Color(0xFF0F141A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: s.color.withValues(alpha: active ? 0.6 : 0.25),
                width: 1.4),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      s.color.withValues(alpha: 0.3),
                      s.color.withValues(alpha: 0.08),
                    ]),
                    border: Border.all(color: s.color.withValues(alpha: 0.55)),
                  ),
                  child: Icon(s.icon, color: s.color, size: 22),
                ),
                const Spacer(),
                if (!active)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('скоро',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
              const Spacer(),
              Text(s.title, style: _title(16)),
              const SizedBox(height: 4),
              Text(s.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      height: 1.25)),
            ],
          ),
        ),
      ),
    );
  }

  static TextStyle _title(double size) => TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w900,
        foreground: size >= 24
            ? (Paint()
              ..shader = const LinearGradient(colors: [_goldLight, _gold])
                  .createShader(const Rect.fromLTWH(0, 0, 320, 30)))
            : null,
      );
}
