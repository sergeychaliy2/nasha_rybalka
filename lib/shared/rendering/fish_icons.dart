import 'package:flutter/material.dart';

/// Единый силуэт рыбы для всего бестиария (без отрисовки конкретных видов).
/// Открытая рыба — светлый силуэт, неоткрытая — тёмный со знаком «?».
class FishIcon extends StatelessWidget {
  const FishIcon(this.speciesId,
      {super.key, this.discovered = true, this.size = 56});

  // id не влияет на форму — силуэт общий; параметр оставлен для совместимости.
  final String speciesId;
  final bool discovered;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.6),
      painter: _FishPainter(discovered),
    );
  }
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.discovered);

  final bool discovered;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = h / 2;
    final half = h * 0.34;
    final nose = Offset(w * 0.84, c);
    final tailBase = Offset(w * 0.22, c);

    final body = Path()
      ..moveTo(nose.dx, nose.dy)
      ..quadraticBezierTo(w * 0.55, c - half, tailBase.dx, c - half * 0.42)
      ..lineTo(tailBase.dx, c + half * 0.42)
      ..quadraticBezierTo(w * 0.55, c + half, nose.dx, nose.dy)
      ..close();

    // Хвост.
    final tail = Path()
      ..moveTo(tailBase.dx, c - half * 0.42)
      ..lineTo(w * 0.06, c - half * 0.95)
      ..lineTo(w * 0.14, c)
      ..lineTo(w * 0.06, c + half * 0.95)
      ..lineTo(tailBase.dx, c + half * 0.42)
      ..close();

    final fill = discovered ? const Color(0xFFC7D2DA) : const Color(0xFF2A3037);
    final finFill =
        discovered ? const Color(0xFF9FB0BC) : const Color(0xFF222A31);

    canvas.drawPath(tail, Paint()..color = finFill);

    // Спинной плавник.
    final dorsal = Path()
      ..moveTo(w * 0.44, c - half * 0.75)
      ..lineTo(w * 0.58, c - half * 1.2)
      ..lineTo(w * 0.62, c - half * 0.6)
      ..close();
    canvas.drawPath(dorsal, Paint()..color = finFill);

    canvas.drawPath(body, Paint()..color = fill);

    if (discovered) {
      // Глаз + жаберная дуга.
      canvas.drawCircle(Offset(w * 0.77, c - half * 0.18), h * 0.06,
          Paint()..color = const Color(0xFF2B3138));
      canvas.drawArc(
          Rect.fromCircle(center: Offset(w * 0.7, c), radius: half * 0.85),
          -1.0, 2.0, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.012
            ..color = const Color(0xFF80909C).withValues(alpha: 0.5));
    } else {
      final tp = TextPainter(
        text: TextSpan(
            text: '?',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: h * 0.5,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.5 - tp.width / 2, c - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _FishPainter old) =>
      old.discovered != discovered;
}
