import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../auth/root_gate.dart';
import '../shell/ui_kit.dart';

/// Загрузочный экран в стиле игры: тёмная вода, поплавок с расходящимися
/// кругами, золотая полоса загрузки и логотип. Тап — пропустить.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  static const _duration = 2.8; // секунд до автоперехода
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
      if (_t >= _duration) _finish();
    })
      ..start();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _ticker.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const RootGate(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_t / _duration).clamp(0.0, 1.0);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Живой фон загрузки: сгенерённое озеро с медленным «кен-бёрнс».
            ClipRect(
              child: Transform.scale(
                scale: 1.0 + 0.06 * (_t / _duration).clamp(0.0, 1.0),
                child: Image.asset(
                  'assets/art/loading_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF05090C)),
                ),
              ),
            ),
            // Вуаль для читабельности лого/прогресса.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x550A1016),
                    Color(0x00000000),
                    Color(0xAA05090C)
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            CustomPaint(painter: _SplashPainter(_t, photo: true)),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // Лого: плавное появление с лёгким масштабом.
                Builder(builder: (context) {
                  final a = ((_t - 0.35) / 0.6).clamp(0.0, 1.0);
                  final eased = Curves.easeOutCubic.transform(a);
                  return Opacity(
                    opacity: eased,
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * eased,
                      child: Column(children: [
                        Text('НАША РЫБАЛКА',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [kGoldLight, kGold],
                                ).createShader(
                                    const Rect.fromLTWH(0, 0, 480, 60)),
                              shadows: const [
                                Shadow(
                                    color: Colors.black87, blurRadius: 12),
                              ],
                            )),
                        const SizedBox(height: 6),
                        Text('симулятор рыбалки',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 14,
                              letterSpacing: 4,
                            )),
                      ]),
                    ),
                  );
                }),
                const Spacer(flex: 4),
                // Полоса загрузки.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 8,
                          child: LayoutBuilder(builder: (context, cc) {
                            final fullW = cc.maxWidth;
                            final fillW = fullW * progress;
                            // Бегущий блик внутри заполненной части.
                            final shineX =
                                (_t * 0.9 % 1.0) * fillW - 18;
                            return Stack(children: [
                              const ColoredBox(
                                  color: Color(0xFF1A2027),
                                  child: SizedBox.expand()),
                              SizedBox(
                                width: fillW,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [kGoldLight, kGold]),
                                  ),
                                  child: SizedBox.expand(),
                                ),
                              ),
                              if (fillW > 24)
                                Positioned(
                                  left: shineX.clamp(0.0, fillW - 18),
                                  top: 0,
                                  bottom: 0,
                                  width: 18,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white
                                            .withValues(alpha: 0.55),
                                        Colors.white.withValues(alpha: 0),
                                      ]),
                                    ),
                                  ),
                                ),
                            ]);
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Загрузка… ${(progress * 100).round()} %',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11.5)),
                    ]),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ночная вода: градиент, звёзды, поплавок с кругами ряби.
class _SplashPainter extends CustomPainter {
  _SplashPainter(this.t, {this.photo = false});

  final double t;
  final bool photo; // true — фон даёт фото, рисуем только поплавок/рябь

  @override
  void paint(Canvas canvas, Size size) {
    if (!photo) {
      // Небо → вода.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B22), Color(0xFF081218), Color(0xFF05090C)],
            stops: [0, 0.55, 1],
          ).createShader(Offset.zero & size),
      );
    }

    // Звёзды (детерминированно, мерцают) — только без фото-фона.
    final rnd = math.Random(7);
    if (!photo) {
      for (var i = 0; i < 70; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = rnd.nextDouble() * size.height * 0.45;
        final phase = rnd.nextDouble() * math.pi * 2;
        final a = 0.25 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.6 + phase));
        canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.1 + 0.3,
            Paint()..color = Colors.white.withValues(alpha: a * 0.8));
      }
    }

    final waterY = size.height * 0.52;

    // Фаза 1 (0–0.55 c): поплавок падает сверху; фаза 2: всплеск и качание.
    const dropEnd = 0.55;
    final dropA = (t / dropEnd).clamp(0.0, 1.0);
    final dropEased = Curves.easeIn.transform(dropA);
    final settled = t >= dropEnd;
    final floatY = settled
        ? waterY + math.sin((t - dropEnd) * 2.2) * 3
        : -30 + (waterY + 30) * dropEased;
    final float = Offset(size.width / 2, floatY);

    if (settled) {
      // Всплеск при приводнении: брызги-точки разлетаются (первые ~0.5 c).
      final splashA = ((t - dropEnd) / 0.5).clamp(0.0, 1.0);
      if (splashA < 1) {
        for (var i = 0; i < 10; i++) {
          final ang = -math.pi / 2 + (i / 10 - 0.5) * 2.2;
          final dist = splashA * 26 + i % 3 * 3;
          final p = Offset(size.width / 2, waterY) +
              Offset(math.cos(ang), math.sin(ang)) * dist +
              Offset(0, splashA * splashA * 22);
          canvas.drawCircle(
              p,
              1.6 * (1 - splashA),
              Paint()
                ..color =
                    Colors.white.withValues(alpha: (1 - splashA) * 0.8));
        }
      }
      // Круги ряби от поплавка.
      for (var k = 0; k < 3; k++) {
        final phase = ((t - dropEnd) * 0.55 + k / 3) % 1.0;
        final r = 18 + phase * size.shortestSide * 0.22;
        final alpha = (1 - phase) * 0.4;
        canvas.save();
        canvas.translate(float.dx, waterY + 8);
        canvas.scale(1, 0.32);
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: alpha),
        );
        canvas.restore();
      }
    }

    // Лёгкое золотое свечение вокруг поплавка.
    canvas.drawCircle(
      float,
      26,
      Paint()
        ..color = kGold.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Поплавок: тело + красная антенна + блик.
    final visibleTop = float - const Offset(0, 14);
    canvas.drawLine(
      float,
      visibleTop,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFEFE7DA),
    );
    canvas.drawLine(
      visibleTop,
      visibleTop - const Offset(0, 11),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE5483B),
    );
    canvas.drawCircle(visibleTop + const Offset(-1.4, 1.5), 1.3,
        Paint()..color = Colors.white.withValues(alpha: 0.85));

    // Немного жизни на фото-фоне: золотые светлячки над водой.
    if (photo) {
      for (var i = 0; i < 12; i++) {
        final bx = rnd.nextDouble() * size.width;
        final by = waterY + rnd.nextDouble() * (size.height - waterY) * 0.8;
        final ph = rnd.nextDouble() * math.pi * 2;
        final x = bx + math.sin(t * 0.6 + ph) * 12;
        final y = by + math.cos(t * 0.4 + ph) * 7;
        final a = (0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 1.6 + ph * 3))) * 0.5;
        canvas.drawCircle(
            Offset(x, y),
            1.4,
            Paint()
              ..color = const Color(0xFFFFD98C).withValues(alpha: a)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }

    // Мерцающие блики на воде — только без фото-фона.
    if (!photo) {
      final glint = Paint()..color = Colors.white.withValues(alpha: 0.05);
      for (var i = 0; i < 26; i++) {
        final gx = rnd.nextDouble() * size.width;
        final gy = waterY + rnd.nextDouble() * (size.height - waterY);
        final w = 8 + rnd.nextDouble() * 18;
        final shift = math.sin(t * 1.2 + i) * 4;
        canvas.drawRect(Rect.fromLTWH(gx + shift, gy, w, 1.1), glint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) => old.t != t;
}
