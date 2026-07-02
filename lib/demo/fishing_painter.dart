import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/rendering/rod_geometry.dart';

/// Кольцо ряби на воде. Растёт и затухает; сплющено по вертикали
/// (scaleY) ради ощущения перспективы поверхности воды.
class Ripple {
  Ripple({
    required this.posN,
    required this.maxRadius,
    required this.life,
    this.strength = 1,
    this.scaleY = 0.34,
  });

  /// Положение в нормированных координатах (0..1 от ширины/высоты).
  final Offset posN;
  final double maxRadius; // в пикселях
  final double life; // секунд
  final double strength; // непрозрачность 0..1
  final double scaleY;
  double age = 0;

  bool get isDead => age >= life;
  double get t => (age / life).clamp(0.0, 1.0);
}

/// Капля брызг с гравитацией — для всплеска при забросе/подсечке/выходе рыбы.
class Splash {
  Splash({
    required this.posN,
    required this.velN,
    required this.life,
    required this.size,
  });

  Offset posN;
  Offset velN; // нормированные единицы/сек
  final double life;
  final double size;
  double age = 0;

  bool get isDead => age >= life;
}

/// Тёмная дуга спины рыбы, на миг показавшейся у поверхности (фон. жизнь воды).
class FishSwirl {
  FishSwirl({required this.posN, required this.life, required this.dir});
  final Offset posN;
  final double life;
  final double dir;
  double age = 0;
  bool get isDead => age >= life;
}

/// Художник сцены ловли поверх фотофона (Canvas‑вариант).
///
/// Рисует (снизу вверх): рябь → леску → поплавок → удилище → брызги.
/// Снасть и эффекты переиспользуют общий модуль [rod_geometry] — тот же код,
/// что и во Flame‑варианте.
class FishingPainter extends CustomPainter {
  FishingPainter({
    required this.time,
    required this.bend,
    required this.floatPosN,
    required this.floatDip,
    required this.lineTaut,
    required this.ripples,
    required this.splashes,
    required this.swirls,
    required this.showRig,
  });

  final double time;
  final double bend;
  final Offset floatPosN;
  final double floatDip;
  final double lineTaut;
  final List<Ripple> ripples;
  final List<Splash> splashes;
  final List<FishSwirl> swirls;
  final bool showRig;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRipples(canvas, size);
    _paintSwirls(canvas, size);

    final geo = computeRod(size, bend, time);
    final floatPx = _floatPixel(size);

    if (showRig) {
      paintLine(canvas, geo.tip, floatPx, lineTaut);
      paintFloat(canvas, floatPx, floatDip);
      paintRod(canvas, geo);
    }

    _paintSplashes(canvas, size);
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
      final rectArc = Rect.fromCenter(center: c, width: 34, height: 12);
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
        Rect.fromCenter(center: c + const Offset(0, 3), width: 22, height: 7),
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
