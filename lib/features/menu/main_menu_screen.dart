import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../shared/sound_service.dart';
import '../map/russia_map_screen.dart';
import '../shell/ui_kit.dart';

/// Главное меню: реальное фото берега с медленным «кен-бёрнс»-зумом и живой
/// атмосферой (туман, светлячки, виньетка); пункты меню появляются каскадом.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  static const version = 'v 0.2.0';

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
        (e) => setState(() => _t = e.inMicroseconds / 1e6))
      ..start();
    // Фоновая музыка меню (луп); заглушается при уходе в игру.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => SoundService.startMenuMusic());
  }

  @override
  void dispose() {
    _ticker.dispose();
    SoundService.stopMenuMusic();
    super.dispose();
  }

  /// Каскадное появление пункта меню: прозрачность и сдвиг справа.
  Widget _staggered(int index, Widget child) {
    final a = ((_t - 0.25 - index * 0.14) / 0.45).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(a);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset((1 - eased) * 46, 0),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Медленный «кен-бёрнс»: лёгкое дыхание масштаба и дрейф кадра.
    final kb = 1.06 + 0.035 * math.sin(_t * 0.10);
    final drift = Offset(
      math.sin(_t * 0.07) * 8,
      math.cos(_t * 0.05) * 5,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.translate(
              offset: drift,
              child: Transform.scale(
                scale: kb,
                // Фон + костёр в единых координатах картинки (1024×576), чтобы
                // пламя всегда держалось точно на кострище при любом размере окна.
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 1024,
                    height: 576,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/art/menu_bg.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFF0B0E12)),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter:
                                _CampfirePainter(_t, const Offset(408, 356)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Живая атмосфера поверх фото (туман, светлячки, комары, виньетка).
          IgnorePointer(child: CustomPaint(painter: _MenuFxPainter(_t))),
          // Затемнение правой части под пункты меню.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Colors.black38, Colors.black87],
                stops: [0.50, 0.76, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _staggered(
                    0,
                    _MenuItem(
                      label: 'НАЧАТЬ ИГРУ',
                      onTap: () async {
                        SoundService.stopMenuMusic(); // тишина на карте/воде
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const RussiaMapScreen()));
                        if (mounted) SoundService.startMenuMusic();
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  _staggered(
                    1,
                    _MenuItem(
                      label: 'НАСТРОЙКИ',
                      onTap: () => GameWindow.show(
                          context, 'Настройки', const SettingsWindowBody()),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _staggered(
                    2,
                    _MenuItem(
                      label: 'ОБ ИГРЕ',
                      onTap: () => GameWindow.show(
                          context, 'Об игре', const _AboutBody()),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _staggered(
                      3, _MenuItem(label: 'ВЫХОД', onTap: () => exit(0))),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text(MainMenuScreen.version,
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Атмосфера поверх фото: дрейфующий туман, золотые светлячки, виньетка.
class _MenuFxPainter extends CustomPainter {
  _MenuFxPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Полосы тумана над водой (дрейфуют в разные стороны).
    for (var i = 0; i < 3; i++) {
      final y = h * (0.52 + i * 0.09);
      final shift = math.sin(t * (0.05 + i * 0.02)) * w * 0.06 +
          (i.isEven ? t : -t) * 6;
      final band = Rect.fromCenter(
        center: Offset(w / 2 + shift % (w * 0.2), y),
        width: w * 1.3,
        height: h * 0.055 + i * 4,
      );
      canvas.drawOval(
        band,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.045 - i * 0.008)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // Светлячки в левой части (золотые точки с плаванием и миганием).
    final rnd = math.Random(17);
    for (var i = 0; i < 14; i++) {
      final bx = rnd.nextDouble() * w * 0.55;
      final by = h * (0.45 + rnd.nextDouble() * 0.45);
      final phase = rnd.nextDouble() * math.pi * 2;
      final x = bx + math.sin(t * 0.6 + phase) * 14;
      final y = by + math.cos(t * 0.42 + phase * 1.7) * 9;
      final a =
          (0.18 + 0.5 * (0.5 + 0.5 * math.sin(t * 1.8 + phase * 3))) * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        1.6,
        Paint()
          ..color = const Color(0xFFFFD98C).withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Комары: тёмные точки с рваной траекторией, роятся у берега и костра.
    final mr = math.Random(91);
    for (var i = 0; i < 22; i++) {
      final bx = w * (0.22 + mr.nextDouble() * 0.5);
      final by = h * (0.54 + mr.nextDouble() * 0.36);
      final f1 = 0.7 + mr.nextDouble() * 1.2;
      final f2 = 1.1 + mr.nextDouble() * 1.7;
      final ph = mr.nextDouble() * math.pi * 2;
      final x = bx + math.sin(t * f1 + ph) * 22 + math.sin(t * f2 * 1.7 + ph) * 8;
      final y =
          by + math.cos(t * f2 + ph) * 15 + math.sin(t * f1 * 2.3 + ph) * 7;
      final a = 0.3 + 0.28 * (0.5 + 0.5 * math.sin(t * 3 + ph * 2));
      canvas.drawCircle(
          Offset(x, y), 1.1, Paint()..color = Colors.black.withValues(alpha: a));
    }

    // Виньетка по краям.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.42),
          ],
          stops: const [0.62, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _MenuFxPainter old) => old.t != t;
}

/// Живой костёр поверх кострища на фото: тёплое мерцающее свечение, языки
/// пламени с колыханием, поднимающиеся искры и лёгкий дымок. Рисуется в
/// координатах картинки (1024×576), поэтому всегда попадает на кострище.
class _CampfirePainter extends CustomPainter {
  _CampfirePainter(this.t, this.fire);

  final double t;
  final Offset fire;

  @override
  void paint(Canvas canvas, Size size) {
    final f = fire;
    // Мерцание пламени.
    final flick =
        0.82 + 0.15 * math.sin(t * 13) + 0.08 * math.sin(t * 23 + 1.3);

    // Мягкое тёплое свечение — только оживляет уже нарисованный костёр.
    final glowR = 44 * flick;
    final gc = f.translate(0, -6);
    canvas.drawCircle(
        gc,
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF9A3C).withValues(alpha: 0.20 * flick),
              const Color(0xFFFF6A1E).withValues(alpha: 0.06),
              const Color(0x00000000),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: gc, radius: glowR))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    // Лёгкий отблеск под костром.
    canvas.drawOval(
        Rect.fromCenter(
            center: f.translate(0, 10), width: 86 * flick, height: 16),
        Paint()
          ..color = const Color(0xFFFF7A2A).withValues(alpha: 0.08 * flick)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));

    // Компактные языки пламени поверх дров (внешние оранжевые → жёлтое ядро).
    void tongue(double dx, double baseW, double h, Color col, double sp,
        double ph) {
      final wig = math.sin(t * sp + ph) * 3 * flick;
      final bx = f.dx + dx;
      final by = f.dy;
      final tipY = by - h * flick;
      final path = Path()
        ..moveTo(bx - baseW, by)
        ..quadraticBezierTo(bx - baseW * 0.6, by - h * 0.5, bx + wig, tipY)
        ..quadraticBezierTo(bx + baseW * 0.6, by - h * 0.5, bx + baseW, by)
        ..quadraticBezierTo(bx, by + 2, bx - baseW, by)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color = col
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4));
    }

    tongue(-3, 7, 26, const Color(0xFFDD4E18).withValues(alpha: 0.55), 11, 0);
    tongue(3, 6, 24, const Color(0xFFF2701F).withValues(alpha: 0.6), 13, 1.1);
    tongue(0, 5, 32, const Color(0xFFFF9A2E).withValues(alpha: 0.8), 12, 0.6);
    tongue(-1, 3.4, 21, const Color(0xFFFFD65A).withValues(alpha: 0.85), 17, 2);
    tongue(1, 2, 14, const Color(0xFFFFF0B0).withValues(alpha: 0.9), 19, 0.3);

    // Немного искр над пламенем.
    final rnd = math.Random(42);
    for (var i = 0; i < 10; i++) {
      final ph = rnd.nextDouble();
      final life = (t * 0.5 * (0.7 + rnd.nextDouble() * 0.6) + ph) % 1.0;
      final rise = life * (40 + rnd.nextDouble() * 34);
      final sway = math.sin(life * 6.28 + ph * 6.28) * (4 + rnd.nextDouble() * 6);
      final p =
          Offset(f.dx + sway + (rnd.nextDouble() - 0.5) * 7, f.dy - 6 - rise);
      final a = (1 - life) * 0.8;
      final r = 1.1 * (1 - life) + 0.4;
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..color = Color.lerp(const Color(0xFFFFD65A),
                    const Color(0xFFFF5A1E), life)!
                .withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant _CampfirePainter old) => old.t != t;
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hover ? 1.04 : 1),
          duration: const Duration(milliseconds: 90),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _pressed || _hover ? kGoldLight : Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Тело окна «Настройки»: звук/вибрация (персистентно) и язык.
class SettingsWindowBody extends ConsumerStatefulWidget {
  const SettingsWindowBody({super.key});

  @override
  ConsumerState<SettingsWindowBody> createState() => _SettingsWindowBodyState();
}

class _SettingsWindowBodyState extends ConsumerState<SettingsWindowBody> {
  late bool _sound;
  late bool _vibration;
  late double _volume;
  late bool _music;
  late double _musicVolume;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _sound = SoundService.enabled;
    _volume = SoundService.volume;
    _music = SoundService.musicEnabled;
    _musicVolume = SoundService.musicVolume;
    _vibration = prefs.getBool('settings.vibration') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.read(sharedPreferencesProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: HeaderPanel(
          header: 'Настройки',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleRow('Звук', _sound, (v) {
                setState(() => _sound = v);
                SoundService.setEnabled(prefs, v);
              }),
              if (_sound) ...[
                const SizedBox(height: 10),
                _volumeRow(prefs),
                const SizedBox(height: 10),
                _sfxSection(prefs),
              ],
              const SizedBox(height: 10),
              _toggleRow('Музыка в меню', _music, (v) {
                setState(() => _music = v);
                SoundService.setMusicEnabled(prefs, v);
              }),
              if (_music) ...[
                const SizedBox(height: 10),
                _musicVolumeRow(prefs),
              ],
              const SizedBox(height: 10),
              _toggleRow('Вибрация', _vibration, (v) {
                setState(() => _vibration = v);
                prefs.setBool('settings.vibration', v);
              }),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Язык',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [kGoldLight, kGold]),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text('RU',
                          style: TextStyle(
                              color: kTextDark, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _volumeRow(SharedPreferences prefs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.volume_up, color: Colors.white54, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Slider(
            value: _volume,
            activeColor: kGold,
            label: '${(_volume * 100).round()}%',
            divisions: 20,
            onChanged: (v) {
              setState(() => _volume = v);
              SoundService.setVolume(prefs, v);
            },
            onChangeEnd: (_) => SoundService.splash(), // проба громкости
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(_volume * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _musicVolumeRow(SharedPreferences prefs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.music_note, color: Colors.white54, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Slider(
            value: _musicVolume,
            activeColor: kGold,
            label: '${(_musicVolume * 100).round()}%',
            divisions: 20,
            onChanged: (v) {
              setState(() => _musicVolume = v);
              SoundService.setMusicVolume(prefs, v);
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(_musicVolume * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _sfxSection(SharedPreferences prefs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Звуковые эффекты',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800)),
          for (final s in Sfx.values)
            Row(children: [
              Expanded(
                child: Text(s.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              Switch(
                value: SoundService.isEffectOn(s),
                activeTrackColor: kGold,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                onChanged: (v) {
                  setState(() => SoundService.setEffect(prefs, s, v));
                  if (v) SoundService.play(s); // проба
                },
              ),
            ]),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          Switch(
            value: value,
            activeTrackColor: kGold,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: HeaderPanel(
          header: 'Об игре',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Наша Рыбалка', style: displayStyle(size: 22)),
              const SizedBox(height: 10),
              const Text(
                'Офлайн-симулятор рыбалки от первого лица. Реальная карта '
                'России по регионам: от Ладоги до Камчатки. Подбирай снасть, '
                'читай погоду и глубину, собирай бестиарий и трофеи.\n\n'
                'Весь контент игры оригинальный. Прогресс хранится локально '
                'на устройстве.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 13.5, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(MainMenuScreen.version,
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
