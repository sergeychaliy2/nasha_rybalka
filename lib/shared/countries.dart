import 'package:flutter/material.dart';

/// Страна проживания игрока. Флаг рисуется полосами (эмодзи-флаги на Windows
/// не отображаются), поэтому у каждой страны — цвета полос и ориентация.
/// Это узнаваемое приближение, а не геральдически точный флаг.
class Country {
  const Country(this.code, this.nameRu, this.colors, {this.vertical = false});
  final String code;
  final String nameRu;
  final List<Color> colors;
  final bool vertical;
}

const _w = Color(0xFFFFFFFF);
const _blk = Color(0xFF1B1B1B);

/// Курируемый список (СНГ + популярные направления). Первый — Россия.
const List<Country> kCountries = [
  Country('RU', 'Россия', [_w, Color(0xFF0039A6), Color(0xFFD52B1E)]),
  Country('BY', 'Беларусь', [Color(0xFFD22730), Color(0xFF009B48)]),
  Country('UA', 'Украина', [Color(0xFF0057B7), Color(0xFFFFD700)]),
  Country('KZ', 'Казахстан', [Color(0xFF00AFCA)]),
  Country('UZ', 'Узбекистан',
      [Color(0xFF0099B5), _w, Color(0xFF1EB53A)]),
  Country('AM', 'Армения',
      [Color(0xFFD90012), Color(0xFF0033A0), Color(0xFFF2A800)]),
  Country('AZ', 'Азербайджан',
      [Color(0xFF00B5E2), Color(0xFFEF3340), Color(0xFF509E2F)]),
  Country('GE', 'Грузия', [_w, Color(0xFFFF0000)]),
  Country('KG', 'Киргизия', [Color(0xFFE8112D)]),
  Country('TJ', 'Таджикистан',
      [Color(0xFFCC0000), _w, Color(0xFF006600)]),
  Country('TM', 'Туркмения', [Color(0xFF28AE66)]),
  Country('MD', 'Молдова',
      [Color(0xFF0046AE), Color(0xFFFFD200), Color(0xFFCC092F)],
      vertical: true),
  Country('LT', 'Литва',
      [Color(0xFFFDB913), Color(0xFF006A44), Color(0xFFC1272D)]),
  Country('LV', 'Латвия',
      [Color(0xFF9E3039), _w, Color(0xFF9E3039)]),
  Country('EE', 'Эстония', [Color(0xFF0072CE), _blk, _w]),
  Country('DE', 'Германия', [_blk, Color(0xFFDD0000), Color(0xFFFFCE00)]),
  Country('FR', 'Франция',
      [Color(0xFF0055A4), _w, Color(0xFFEF4135)],
      vertical: true),
  Country('IT', 'Италия',
      [Color(0xFF008C45), _w, Color(0xFFCD212A)],
      vertical: true),
  Country('NL', 'Нидерланды',
      [Color(0xFFAE1C28), _w, Color(0xFF21468B)]),
  Country('PL', 'Польша', [_w, Color(0xFFDC143C)]),
  Country('FI', 'Финляндия', [_w, Color(0xFF003580)]),
  Country('SE', 'Швеция', [Color(0xFF006AA7), Color(0xFFFECC00)]),
  Country('NO', 'Норвегия',
      [Color(0xFFBA0C2F), _w, Color(0xFF00205B)]),
  Country('US', 'США', [Color(0xFFB22234), _w, Color(0xFF3C3B6E)]),
  Country('CN', 'Китай', [Color(0xFFDE2910)]),
  Country('XX', 'Другая', [Color(0xFF5A6570)]),
];

Country countryByCode(String code) =>
    kCountries.where((c) => c.code == code).firstOrNull ?? kCountries.first;

/// Маленький нарисованный флаг (полосы) со скруглением и рамкой.
class FlagIcon extends StatelessWidget {
  const FlagIcon(this.code, {super.key, this.width = 26, this.height = 18});
  final String code;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = countryByCode(code);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _FlagPainter(c)),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.c);
  final Country c;

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.colors.length;
    for (var i = 0; i < n; i++) {
      final paint = Paint()..color = c.colors[i];
      final Rect r;
      if (c.vertical) {
        r = Rect.fromLTWH(size.width * i / n, 0, size.width / n, size.height);
      } else {
        r = Rect.fromLTWH(0, size.height * i / n, size.width, size.height / n);
      }
      canvas.drawRect(r, paint);
    }
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant _FlagPainter old) => old.c.code != c.code;
}
