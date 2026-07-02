import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../shared/rendering/rod_geometry.dart';

/// Кольцо ряби на воде. Растёт и затухает; сплющено по вертикали ради
/// ощущения перспективы поверхности.
class Ripple {
  Ripple({
    required this.posN,
    required this.maxRadius,
    required this.life,
    this.strength = 1,
    this.scaleY = 0.34,
  });

  final Offset posN;
  final double maxRadius;
  final double life;
  final double strength;
  final double scaleY;
  double age = 0;

  bool get isDead => age >= life;
  double get t => (age / life).clamp(0.0, 1.0);
}

/// Капля брызг с гравитацией — всплеск при забросе/подсечке/выходе рыбы.
class Splash {
  Splash({
    required this.posN,
    required this.velN,
    required this.life,
    required this.size,
  });

  Offset posN;
  Offset velN;
  final double life;
  final double size;
  double age = 0;

  bool get isDead => age >= life;
}

/// Тёмная дуга спины рыбы у поверхности (фоновая жизнь воды).
class FishSwirl {
  FishSwirl({
    required this.posN,
    required this.life,
    required this.dir,
    this.scale = 1.0,
  });
  final Offset posN;
  final double life;
  final double dir;

  /// Масштаб «выхода» — больше у крупной рыбы (видно по размеру буруна).
  final double scale;
  double age = 0;
  bool get isDead => age >= life;
}

/// Художник сцены ловли поверх фотофона.
///
/// Рисует (снизу вверх): рябь → леска → поплавок → удилище + катушка → брызги.
/// Снасть берётся из общего модуля [rod_geometry]. [pull] заводит удилище к
/// игроку при вываживании, [reelAngle] крутит катушку при подмотке.
class FishingPainter extends CustomPainter {
  FishingPainter({
    required this.time,
    required this.bend,
    required this.pull,
    required this.reelAngle,
    required this.floatPosN,
    required this.floatDip,
    required this.lineTaut,
    required this.ripples,
    required this.splashes,
    required this.swirls,
    required this.showRig,
    required this.showReel,
    required this.rain,
    this.spinning = false,
    this.lureVisibility = 1.0,
    this.floatScale = 1.0,
  });

  final double time;
  final double bend;
  final double pull;
  final double reelAngle;
  final Offset floatPosN;
  final double floatDip;
  final double lineTaut;
  final List<Ripple> ripples;
  final List<Splash> splashes;
  final List<FishSwirl> swirls;
  final bool showRig;
  final bool showReel;
  final bool rain;

  /// Спиннинг: вместо поплавка — еле заметная блесна под водой.
  final bool spinning;

  /// Видимость блесны 0..1 (ярче по мере подтяга к берегу).
  final double lureVisibility;

  /// Масштаб поплавка по дальности заброса (дальше — мельче).
  final double floatScale;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRipples(canvas, size);
    _paintSwirls(canvas, size);

    final geo = computeRod(size, bend, time, pull: pull);
    final floatPx = _floatPixel(size);

    if (showRig) {
      paintLine(canvas, geo.tip, floatPx, lineTaut);
      if (spinning) {
        _paintLure(canvas, floatPx, lureVisibility);
      } else {
        paintFloat(canvas, floatPx, floatDip, floatScale);
      }
      paintRod(canvas, geo);
      if (showReel) paintReel(canvas, geo, reelAngle);
    }

    _paintSplashes(canvas, size);
    if (rain) _paintRain(canvas, size);
  }

  /// Дождь — диагональные струйки, анимированные временем (детерминированно).
  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 60; i++) {
      final fx = ((i * 53) % 100) / 100 * size.width;
      final speed = 620 + (i % 5) * 120;
      final fy = ((time * speed + i * 47) % (size.height + 40)) - 20;
      canvas.drawLine(Offset(fx, fy), Offset(fx - 6, fy + 16), paint);
    }
  }

  /// Блесна под водой: еле заметная вдали, ярче по мере подтяга к берегу.
  void _paintLure(Canvas canvas, Offset c, double vis) {
    final a = vis.clamp(0.0, 1.0);
    if (a <= 0.02) return;
    // Лёгкий ореол на воде от проводки.
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: a * 0.18),
    );
    // Тело блесны — небольшая «лепестковая» форма.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 7, height: 13),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2A3038).withValues(alpha: 0.3 + a * 0.5),
    );
    // Блик.
    canvas.drawCircle(
      c + const Offset(-1.5, -3),
      1.6,
      Paint()..color = Colors.white.withValues(alpha: a * 0.5),
    );
  }

  Offset _floatPixel(Size size) {
    final base = Offset(floatPosN.dx * size.width, floatPosN.dy * size.height);
    final bob = math.sin(time * 2.1) * 2.4 * (1 - floatDip);
    final dipPx = floatDip * 26;
    return base + Offset(0, bob + dipPx);
  }

  void _paintRipples(Canvas canvas, Size size) {
    for (final r in ripples) {
      final c = Offset(r.posN.dx * size.width, r.posN.dy * size.height);
      final radius = r.maxRadius * Curves.easeOut.transform(r.t);
      final alpha = (1 - r.t) * 0.5 * r.strength;
      if (alpha <= 0.01) continue;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, r.scaleY);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(2.2, 0.5, r.t)!
        ..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset.zero, radius, paint);
      if (r.t < 0.6) {
        canvas.drawCircle(
          Offset.zero,
          radius * 0.6,
          paint..color = Colors.white.withValues(alpha: alpha * 0.6),
        );
      }
      canvas.restore();
    }
  }

  void _paintSwirls(Canvas canvas, Size size) {
    for (final s in swirls) {
      final c = Offset(s.posN.dx * size.width, s.posN.dy * size.height);
      final t = (s.age / s.life).clamp(0.0, 1.0);
      final alpha = math.sin(t * math.pi) * 0.5;
      if (alpha <= 0.01) continue;
      final k = s.scale;
      final rectArc = Rect.fromCenter(center: c, width: 34 * k, height: 12 * k);
      final start = s.dir > 0 ? math.pi : 0.0;
      canvas.drawArc(
        rectArc,
        start,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF20262B).withValues(alpha: alpha),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(0, 3 * k), width: 22 * k, height: 7 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: alpha * 0.6),
      );
    }
  }

  void _paintSplashes(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in splashes) {
      final t = (s.age / s.life).clamp(0.0, 1.0);
      final p = Offset(s.posN.dx * size.width, s.posN.dy * size.height);
      paint.color = Colors.white.withValues(alpha: (1 - t) * 0.85);
      canvas.drawCircle(p, s.size * (1 - t * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant FishingPainter old) => true;
}
