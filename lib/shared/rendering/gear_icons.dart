import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/value_objects/fishing_enums.dart';

/// Векторные иконки снастей: узнаваемые силуэты по категориям (удилище,
/// спиннинг, катушка, леска, шнур, крючок, наживка, приманка, эхолот…).
/// Рисуются в тёплой палитре под светлые «фото-зоны» карточек.
class GearIcon extends StatelessWidget {
  const GearIcon(this.category, {super.key, this.size = 44});

  final GearCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GearIconPainter(category),
    );
  }
}

class _GearIconPainter extends CustomPainter {
  _GearIconPainter(this.category);

  final GearCategory category;

  static const _dark = Color(0xFF4A3A22);
  static const _mid = Color(0xFF7A5C33);
  static const _accent = Color(0xFFB8862F);
  static const _red = Color(0xFFC0452F);
  static const _steel = Color(0xFF5E6A74);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    switch (category) {
      case GearCategory.rod:
        _rod(canvas, s, withFloat: true);
      case GearCategory.spinningRod:
        _rod(canvas, s, withFloat: false);
      case GearCategory.floatReel || GearCategory.spinningReel:
        _reel(canvas, s);
      case GearCategory.line:
        _spool(canvas, s, _mid);
      case GearCategory.braid:
        _spool(canvas, s, _steel);
      case GearCategory.hook:
        _hook(canvas, s);
      case GearCategory.bait:
        _worm(canvas, s);
      case GearCategory.lure:
        _wobbler(canvas, s);
      case GearCategory.echoSounder:
        _sonar(canvas, s);
      case GearCategory.groundbait:
        _groundbait(canvas, s);
      case GearCategory.spray:
        _spray(canvas, s);
      case GearCategory.energy:
        _thermos(canvas, s);
      case GearCategory.premium:
        _crown(canvas, s);
    }
  }

  Paint _stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = c;

  // Удилище по диагонали: бланк, рукоять, кольца; у поплавочного — поплавок.
  void _rod(Canvas canvas, double s, {required bool withFloat}) {
    final butt = Offset(s * 0.16, s * 0.86);
    final tip = Offset(s * 0.88, s * 0.10);
    canvas.drawLine(butt, tip, _stroke(s * 0.060, _dark));
    canvas.drawLine(Offset(s * 0.16, s * 0.86), Offset(s * 0.34, s * 0.68),
        _stroke(s * 0.085, _mid)); // рукоять
    // Кольца.
    for (final t in [0.42, 0.62, 0.82]) {
      final p = Offset.lerp(butt, tip, t)!;
      canvas.drawCircle(
          p + Offset(s * 0.035, s * 0.035), s * 0.045, _stroke(s * 0.02, _accent));
    }
    // Леска вниз от кончика.
    canvas.drawLine(
        tip, Offset(tip.dx, s * 0.62), _stroke(s * 0.015, _steel));
    if (withFloat) {
      // Поплавок на леске.
      final f = Offset(tip.dx, s * 0.66);
      canvas.drawOval(
          Rect.fromCenter(
              center: f, width: s * 0.085, height: s * 0.16),
          Paint()..color = _red);
      canvas.drawLine(f - Offset(0, s * 0.12), f - Offset(0, s * 0.20),
          _stroke(s * 0.025, _dark));
    } else {
      // Блесна на конце.
      final f = Offset(tip.dx, s * 0.68);
      canvas.drawOval(
          Rect.fromCenter(center: f, width: s * 0.07, height: s * 0.13),
          Paint()..color = _accent);
    }
  }

  // Безынерционная катушка: корпус, шпуля, лесоукладыватель, ручка.
  void _reel(Canvas canvas, double s) {
    final c = Offset(s * 0.46, s * 0.50);
    // Лапка крепления.
    canvas.drawLine(Offset(c.dx, s * 0.12), Offset(c.dx, c.dy - s * 0.2),
        _stroke(s * 0.06, _dark));
    canvas.drawLine(Offset(c.dx - s * 0.14, s * 0.12),
        Offset(c.dx + s * 0.14, s * 0.12), _stroke(s * 0.05, _dark));
    // Корпус и шпуля.
    canvas.drawCircle(c, s * 0.21, Paint()..color = _mid);
    canvas.drawCircle(c, s * 0.21, _stroke(s * 0.02, _dark));
    canvas.drawCircle(c, s * 0.115, Paint()..color = const Color(0xFFD9CFAF));
    canvas.drawCircle(c, s * 0.115, _stroke(s * 0.018, _dark));
    // Намотка.
    canvas.drawCircle(c, s * 0.155, _stroke(s * 0.022, _steel));
    // Дужка лесоукладывателя.
    canvas.drawArc(Rect.fromCircle(center: c, radius: s * 0.24),
        -math.pi * 0.15, math.pi * 0.75, false, _stroke(s * 0.025, _accent));
    // Ручка.
    final knob = c + Offset(s * 0.30, s * 0.16);
    canvas.drawLine(c + Offset(s * 0.16, s * 0.08), knob,
        _stroke(s * 0.035, _dark));
    canvas.drawCircle(knob, s * 0.05, Paint()..color = _accent);
  }

  // Катушка-бобина лески/шнура.
  void _spool(Canvas canvas, double s, Color thread) {
    final r = Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.52),
        width: s * 0.46,
        height: s * 0.56);
    // Щёки бобины.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(r.center.dx, r.top), width: r.width, height: s * 0.14),
        Paint()..color = _dark);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(r.center.dx, r.bottom),
            width: r.width,
            height: s * 0.14),
        Paint()..color = _dark);
    // Намотка.
    canvas.drawRect(
        Rect.fromLTRB(r.left + s * 0.04, r.top + s * 0.02,
            r.right - s * 0.04, r.bottom - s * 0.02),
        Paint()..color = thread);
    for (var i = 0; i < 4; i++) {
      final y = r.top + s * 0.06 + i * (r.height - s * 0.12) / 3;
      canvas.drawLine(Offset(r.left + s * 0.04, y),
          Offset(r.right - s * 0.04, y), _stroke(s * 0.012, Colors.black26));
    }
    // Хвост лески.
    final start = Offset(r.right - s * 0.04, r.bottom - s * 0.10);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(s * 0.86, s * 0.70, s * 0.78, s * 0.88)
      ..quadraticBezierTo(s * 0.70, s * 0.97, s * 0.56, s * 0.92);
    canvas.drawPath(path, _stroke(s * 0.02, thread));
  }

  // Рыболовный крючок с колечком и бородкой.
  void _hook(Canvas canvas, double s) {
    final p = Path()
      ..moveTo(s * 0.58, s * 0.12)
      ..lineTo(s * 0.58, s * 0.55)
      ..arcToPoint(Offset(s * 0.30, s * 0.55),
          radius: Radius.circular(s * 0.155), clockwise: true)
      ..lineTo(s * 0.30, s * 0.42);
    canvas.drawPath(p, _stroke(s * 0.05, _steel));
    // Колечко.
    canvas.drawCircle(
        Offset(s * 0.58, s * 0.10), s * 0.055, _stroke(s * 0.035, _steel));
    // Жало с бородкой.
    canvas.drawLine(Offset(s * 0.30, s * 0.42), Offset(s * 0.24, s * 0.50),
        _stroke(s * 0.035, _steel));
  }

  // Червь: волнистое тело.
  void _worm(Canvas canvas, double s) {
    final path = Path()..moveTo(s * 0.14, s * 0.62);
    path.cubicTo(s * 0.22, s * 0.38, s * 0.36, s * 0.40, s * 0.44, s * 0.58);
    path.cubicTo(s * 0.52, s * 0.76, s * 0.64, s * 0.78, s * 0.72, s * 0.58);
    path.cubicTo(s * 0.78, s * 0.42, s * 0.86, s * 0.40, s * 0.88, s * 0.48);
    canvas.drawPath(path, _stroke(s * 0.085, const Color(0xFFB06A4A)));
    canvas.drawCircle(Offset(s * 0.14, s * 0.62), s * 0.045,
        Paint()..color = const Color(0xFF8E4F35));
  }

  // Воблер: рыбка с лопастью и тройником.
  void _wobbler(Canvas canvas, double s) {
    final body = Path()
      ..moveTo(s * 0.18, s * 0.46)
      ..quadraticBezierTo(s * 0.42, s * 0.28, s * 0.72, s * 0.42)
      ..quadraticBezierTo(s * 0.60, s * 0.62, s * 0.34, s * 0.60)
      ..close();
    canvas.drawPath(body, Paint()..color = _red);
    canvas.drawPath(body, _stroke(s * 0.018, _dark));
    // Глаз.
    canvas.drawCircle(
        Offset(s * 0.62, s * 0.42), s * 0.035, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(s * 0.63, s * 0.42), s * 0.018, Paint()..color = Colors.black);
    // Лопасть.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.80, s * 0.50),
            width: s * 0.14,
            height: s * 0.10),
        Paint()..color = const Color(0xAAFFFFFF));
    // Тройник снизу.
    final hookC = Offset(s * 0.40, s * 0.76);
    canvas.drawLine(Offset(s * 0.40, s * 0.60), hookC, _stroke(s * 0.018, _steel));
    for (var i = 0; i < 3; i++) {
      final a = math.pi / 2 + (i - 1) * 0.85;
      canvas.drawArc(
          Rect.fromCircle(center: hookC, radius: s * 0.07),
          a,
          math.pi * 0.8,
          false,
          _stroke(s * 0.022, _steel));
    }
  }

  // Эхолот: корпус с экраном (дуга дна и «рыбки»).
  void _sonar(Canvas canvas, double s) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.16, s * 0.14, s * 0.68, s * 0.62),
        Radius.circular(s * 0.07));
    canvas.drawRRect(r, Paint()..color = _dark);
    final screen = Rect.fromLTWH(s * 0.22, s * 0.20, s * 0.56, s * 0.42);
    canvas.drawRect(screen, Paint()..color = const Color(0xFF0F2B22));
    // Дно.
    final bottom = Path()..moveTo(screen.left, screen.bottom - s * 0.06);
    bottom.quadraticBezierTo(screen.center.dx, screen.bottom - s * 0.16,
        screen.right, screen.bottom - s * 0.04);
    canvas.drawPath(bottom, _stroke(s * 0.02, const Color(0xFF2EE6A6)));
    // Дуги-рыбы.
    for (final p in [
      Offset(screen.left + s * 0.12, screen.top + s * 0.12),
      Offset(screen.left + s * 0.30, screen.top + s * 0.20),
      Offset(screen.left + s * 0.44, screen.top + s * 0.10),
    ]) {
      canvas.drawArc(Rect.fromCircle(center: p, radius: s * 0.045), 0.3,
          math.pi - 0.6, false, _stroke(s * 0.018, const Color(0xFF7FE3C0)));
    }
    // Кнопки.
    canvas.drawCircle(Offset(s * 0.34, s * 0.70), s * 0.025,
        Paint()..color = _accent);
    canvas.drawCircle(Offset(s * 0.50, s * 0.70), s * 0.025,
        Paint()..color = _accent);
    canvas.drawCircle(Offset(s * 0.66, s * 0.70), s * 0.025,
        Paint()..color = _accent);
    // Датчик на шнуре.
    canvas.drawLine(Offset(s * 0.5, s * 0.76), Offset(s * 0.5, s * 0.86),
        _stroke(s * 0.02, _steel));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.90),
            width: s * 0.12,
            height: s * 0.08),
        Paint()..color = _steel);
  }

  // Прикормка: мешок с зёрнами.
  void _groundbait(Canvas canvas, double s) {
    final bag = Path()
      ..moveTo(s * 0.30, s * 0.30)
      ..quadraticBezierTo(s * 0.22, s * 0.78, s * 0.50, s * 0.84)
      ..quadraticBezierTo(s * 0.78, s * 0.78, s * 0.70, s * 0.30)
      ..close();
    canvas.drawPath(bag, Paint()..color = _mid);
    canvas.drawLine(Offset(s * 0.30, s * 0.30), Offset(s * 0.70, s * 0.30),
        _stroke(s * 0.05, _dark));
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
          Offset(s * (0.36 + (i % 3) * 0.14), s * (0.50 + (i ~/ 3) * 0.16)),
          s * 0.035,
          Paint()..color = const Color(0xFFE3C97A));
    }
  }

  // Спрей-баллончик.
  void _spray(Canvas canvas, double s) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.34, s * 0.30, s * 0.32, s * 0.56),
            Radius.circular(s * 0.06)),
        Paint()..color = _steel);
    canvas.drawRect(Rect.fromLTWH(s * 0.42, s * 0.18, s * 0.16, s * 0.12),
        Paint()..color = _dark);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(s * (0.70 + i * 0.07), s * (0.20 - i * 0.03)),
          s * 0.02, Paint()..color = Colors.white54);
    }
  }

  // Термос.
  void _thermos(Canvas canvas, double s) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.36, s * 0.22, s * 0.28, s * 0.62),
            Radius.circular(s * 0.07)),
        Paint()..color = _red);
    canvas.drawRect(Rect.fromLTWH(s * 0.36, s * 0.14, s * 0.28, s * 0.10),
        Paint()..color = _steel);
    canvas.drawLine(Offset(s * 0.42, s * 0.34), Offset(s * 0.42, s * 0.72),
        _stroke(s * 0.02, Colors.white24));
  }

  // Корона (премиум).
  void _crown(Canvas canvas, double s) {
    final p = Path()
      ..moveTo(s * 0.20, s * 0.66)
      ..lineTo(s * 0.20, s * 0.36)
      ..lineTo(s * 0.36, s * 0.50)
      ..lineTo(s * 0.50, s * 0.26)
      ..lineTo(s * 0.64, s * 0.50)
      ..lineTo(s * 0.80, s * 0.36)
      ..lineTo(s * 0.80, s * 0.66)
      ..close();
    canvas.drawPath(p, Paint()..color = _accent);
    canvas.drawRect(Rect.fromLTWH(s * 0.20, s * 0.68, s * 0.60, s * 0.08),
        Paint()..color = _dark);
  }

  @override
  bool shouldRepaint(covariant _GearIconPainter old) =>
      old.category != category;
}
