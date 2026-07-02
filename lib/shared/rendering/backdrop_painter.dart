import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Характер рельефа заднего плана локации.
enum TerrainKind {
  skerries, // гранитные шхеры с соснами (Ладога)
  reeds, // камышовые плёсы (Селигер)
  snags, // затопленный коряжник (Рыбинка)
  steppe, // степные яры и косы (Дон)
  willows, // пойменные ивы и пески (Ахтуба)
  taiga, // таёжные гряды (Енисей)
  mountains, // прозрачная вода и горы (Байкал)
  wide, // бескрайние плёсы в дымке (Амур)
  volcano, // вулканы и быстрая вода (Камчатка)
}

/// Палитра и набор деталей одного фона.
class BackdropSpec {
  const BackdropSpec({
    required this.seed,
    required this.skyTop,
    required this.skyHorizon,
    required this.sunColor,
    required this.sunX,
    required this.sunY,
    required this.waterNear,
    required this.waterFar,
    required this.far,
    required this.mid,
    required this.terrain,
    this.mist = 0.0,
    this.clouds = 3,
    this.ripple = 1.0,
  });

  final int seed;
  final Color skyTop;
  final Color skyHorizon;
  final Color sunColor;
  final double sunX; // 0..1
  final double sunY; // 0..1 от верха до горизонта
  final Color waterNear;
  final Color waterFar;
  final Color far; // дальний силуэт
  final Color mid; // ближний силуэт/деревья
  final TerrainKind terrain;
  final double mist; // 0..1 плотность дымки у горизонта
  final int clouds;
  final double ripple; // множитель ряби
}

/// Атмосферный пейзаж «небо → дальний план → вода → передний план».
/// Горизонт на 0.42 высоты — совпадает с зоной воды игровой сцены.
class BackdropPainter extends CustomPainter {
  BackdropPainter(this.spec);

  final BackdropSpec spec;

  static const double horizonF = 0.42;

  late double _w;
  late double _h;
  late double _hz;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(spec.seed);
    _w = size.width;
    _h = size.height;
    _hz = _h * horizonF;

    _sky(canvas);
    _clouds(canvas, rnd);
    _sun(canvas);
    _farLayer(canvas, rnd);
    _water(canvas);
    _sunPath(canvas, rnd);
    _midLayer(canvas, rnd);
    if (spec.mist > 0) _mist(canvas);
    _ripples(canvas, rnd);
    _foreground(canvas, rnd);
    _vignette(canvas);
    _grain(canvas, rnd);
  }

  // --- Небо и свет -----------------------------------------------------------

  void _sky(Canvas c) {
    final midSky = Color.lerp(spec.skyTop, spec.skyHorizon, 0.55)!;
    c.drawRect(
      Rect.fromLTWH(0, 0, _w, _hz + 1),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [spec.skyTop, midSky, spec.skyHorizon],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromLTWH(0, 0, _w, _hz)),
    );
    // Тёплая полоса зари у самого горизонта.
    c.drawRect(
      Rect.fromLTWH(0, _hz * 0.72, _w, _hz * 0.28),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            spec.skyHorizon.withValues(alpha: 0),
            spec.skyHorizon.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromLTWH(0, _hz * 0.72, _w, _hz * 0.28)),
    );
  }

  void _sun(Canvas c) {
    final p = Offset(_w * spec.sunX, _hz * spec.sunY);
    final r = _w * 0.045;
    // Широкое свечение в полнеба.
    c.drawCircle(
      p,
      r * 6,
      Paint()
        ..shader = RadialGradient(colors: [
          spec.sunColor.withValues(alpha: 0.42),
          spec.sunColor.withValues(alpha: 0.12),
          spec.sunColor.withValues(alpha: 0),
        ], stops: const [0, 0.45, 1])
            .createShader(Rect.fromCircle(center: p, radius: r * 6)),
    );
    c.drawCircle(
      p,
      r * 1.35,
      Paint()
        ..color = spec.sunColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    c.drawCircle(p, r, Paint()..color = spec.sunColor);
  }

  void _clouds(Canvas c, math.Random rnd) {
    for (var i = 0; i < spec.clouds; i++) {
      final cx = _w * (0.08 + rnd.nextDouble() * 0.84);
      final cy = _hz * (0.14 + rnd.nextDouble() * 0.5);
      final cw = _w * (0.16 + rnd.nextDouble() * 0.22);
      final tint = Color.lerp(
          Colors.white, spec.sunColor, 0.35 + rnd.nextDouble() * 0.3)!;
      final paint = Paint()
        ..color = tint.withValues(alpha: 0.12 + rnd.nextDouble() * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      // Слоистое перистое облако из трёх лент.
      for (var k = 0; k < 3; k++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(cx + k * cw * 0.16, cy + k * 7),
            width: cw * (1 - k * 0.22),
            height: 14.0 + k * 4,
          ),
          paint,
        );
      }
    }
  }

  // --- Дальний план ----------------------------------------------------------

  void _farLayer(Canvas c, math.Random rnd) {
    final paint = Paint()..color = spec.far;
    final path = Path()..moveTo(0, _hz);
    switch (spec.terrain) {
      case TerrainKind.mountains:
        _ridge(path, rnd, 0.085, 60, 95);
        c.drawPath(path..close(), paint);
        _snowCaps(c, rnd);
        return;
      case TerrainKind.taiga:
        _ridge(path, rnd, 0.09, 30, 48);
      case TerrainKind.volcano:
        // Большой конус + малый на фоне пологого берега.
        path
          ..lineTo(0, _hz - 18)
          ..lineTo(_w * 0.18, _hz - 24)
          ..lineTo(_w * 0.40, _hz - 168)
          ..lineTo(_w * 0.47, _hz - 168)
          ..lineTo(_w * 0.66, _hz - 30)
          ..lineTo(_w * 0.74, _hz - 78)
          ..lineTo(_w * 0.80, _hz - 78)
          ..lineTo(_w * 0.92, _hz - 22)
          ..lineTo(_w, _hz - 18);
      case TerrainKind.steppe:
        path
          ..lineTo(0, _hz - 12)
          ..lineTo(_w * 0.52, _hz - 9)
          ..lineTo(_w * 0.56, _hz - 46)
          ..lineTo(_w * 0.93, _hz - 42)
          ..lineTo(_w * 0.96, _hz - 10)
          ..lineTo(_w, _hz - 10);
      default:
        var x = 0.0;
        path.lineTo(0, _hz - 10);
        while (x < _w) {
          final nx = x + _w * (0.12 + rnd.nextDouble() * 0.15);
          path.quadraticBezierTo(
            (x + nx) / 2,
            _hz - (14 + rnd.nextDouble() * 16),
            nx,
            _hz - (6 + rnd.nextDouble() * 9),
          );
          x = nx;
        }
    }
    path
      ..lineTo(_w, _hz + 2)
      ..lineTo(0, _hz + 2)
      ..close();
    c.drawPath(path, paint);

    if (spec.terrain == TerrainKind.volcano) {
      // Снежные шапки обоих конусов.
      c.drawPath(
        Path()
          ..moveTo(_w * 0.375, _hz - 146)
          ..lineTo(_w * 0.40, _hz - 168)
          ..lineTo(_w * 0.47, _hz - 168)
          ..lineTo(_w * 0.495, _hz - 146)
          ..lineTo(_w * 0.465, _hz - 134)
          ..lineTo(_w * 0.435, _hz - 148)
          ..lineTo(_w * 0.405, _hz - 134)
          ..close(),
        Paint()..color = const Color(0xFFEFF5F8),
      );
      c.drawPath(
        Path()
          ..moveTo(_w * 0.755, _hz - 64)
          ..lineTo(_w * 0.74, _hz - 78)
          ..lineTo(_w * 0.80, _hz - 78)
          ..lineTo(_w * 0.785, _hz - 64)
          ..lineTo(_w * 0.77, _hz - 70)
          ..close(),
        Paint()..color = const Color(0xFFEFF5F8),
      );
    }
    if (spec.terrain == TerrainKind.skerries) {
      // Дальняя полоска острова с щёткой леса.
      final island = Path()
        ..moveTo(_w * 0.55, _hz)
        ..lineTo(_w * 0.57, _hz - 8)
        ..lineTo(_w * 0.97, _hz - 7)
        ..lineTo(_w * 0.99, _hz)
        ..close();
      c.drawPath(island, Paint()..color = spec.far);
      var x = _w * 0.58;
      while (x < _w * 0.96) {
        final ph = 6 + rnd.nextDouble() * 9;
        c.drawPath(
          Path()
            ..moveTo(x, _hz - 7 - ph)
            ..lineTo(x - 3, _hz - 5)
            ..lineTo(x + 3, _hz - 5)
            ..close(),
          Paint()..color = spec.far,
        );
        x += 7 + rnd.nextDouble() * 6;
      }
    }
  }

  void _ridge(Path path, math.Random rnd, double stepF, double loH, double hiH) {
    var x = 0.0;
    var y = _hz - loH * (0.6 + rnd.nextDouble() * 0.5);
    path.lineTo(0, y);
    while (x < _w) {
      final nx = x + _w * (stepF * (0.8 + rnd.nextDouble() * 0.6));
      final peak = _hz - (loH + rnd.nextDouble() * (hiH - loH));
      path.quadraticBezierTo((x + nx) / 2, peak, nx,
          _hz - loH * (0.35 + rnd.nextDouble() * 0.5));
      x = nx;
      y = peak;
    }
    path
      ..lineTo(_w, _hz + 2)
      ..lineTo(0, _hz + 2);
  }

  void _snowCaps(Canvas c, math.Random rnd) {
    // Несколько снежных зубцов поверх хребта.
    final r2 = math.Random(spec.seed + 7);
    for (var i = 0; i < 5; i++) {
      final x = _w * (0.08 + r2.nextDouble() * 0.84);
      final peakY = _hz - (70 + r2.nextDouble() * 24);
      c.drawPath(
        Path()
          ..moveTo(x - 14, peakY + 16)
          ..lineTo(x, peakY)
          ..lineTo(x + 13, peakY + 15)
          ..lineTo(x + 6, peakY + 13)
          ..lineTo(x, peakY + 19)
          ..lineTo(x - 6, peakY + 12)
          ..close(),
        Paint()..color = const Color(0xFFE8F1F6).withValues(alpha: 0.9),
      );
    }
  }

  // --- Вода ------------------------------------------------------------------

  void _water(Canvas c) {
    final mirror = Color.lerp(spec.skyHorizon, spec.waterFar, 0.45)!;
    c.drawRect(
      Rect.fromLTWH(0, _hz, _w, _h - _hz),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mirror, spec.waterFar, spec.waterNear],
          stops: const [0, 0.22, 1],
        ).createShader(Rect.fromLTWH(0, _hz, _w, _h - _hz)),
    );
  }

  void _sunPath(Canvas c, math.Random rnd) {
    final cx = _w * spec.sunX;
    // Широкий мягкий столб света: поперечный градиент — без жёстких краёв.
    final col = Rect.fromLTWH(cx - _w * 0.14, _hz, _w * 0.28, _h - _hz);
    c.drawRect(
      col,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            spec.sunColor.withValues(alpha: 0),
            spec.sunColor.withValues(alpha: 0.22),
            spec.sunColor.withValues(alpha: 0),
          ],
        ).createShader(col),
    );
    // Блики-черточки дорожки.
    for (var i = 0; i < 90; i++) {
      final t = i / 90.0;
      final y = _hz + (_h - _hz) * t * t;
      final spread = _w * (0.018 + 0.11 * t);
      final x = cx + (rnd.nextDouble() - 0.5) * spread * 2;
      final len = (6 + rnd.nextDouble() * 30) * (0.5 + t);
      c.drawLine(
        Offset(x - len / 2, y),
        Offset(x + len / 2, y),
        Paint()
          ..color = spec.sunColor.withValues(alpha: 0.30 * (1 - t * 0.55))
          ..strokeWidth = 1.4 + rnd.nextDouble() * 2.0,
      );
    }
  }

  // --- Средний план ----------------------------------------------------------

  void _midLayer(Canvas c, math.Random rnd) {
    final paint = Paint()..color = spec.mid;
    switch (spec.terrain) {
      case TerrainKind.skerries:
        _skerry(c, rnd, _w * 0.13, _w * 0.24);
        _skerry(c, rnd, _w * 0.80, _w * 0.30);
      case TerrainKind.taiga:
        _pineRow(c, rnd, paint, 0, _w, density: 0.95, scale: 1.25);
        _reflectBand(c, 26);
      case TerrainKind.volcano:
      case TerrainKind.mountains:
        _pineRow(c, rnd, paint, 0, _w * 0.4, density: 0.5, scale: 0.9);
        _pineRow(c, rnd, paint, _w * 0.7, _w, density: 0.5, scale: 0.9);
        _reflectBand(c, 16);
      case TerrainKind.willows:
        _willows(c, rnd, paint);
        _reflectBand(c, 22);
      case TerrainKind.steppe:
        // Глинистый яр с тёплой подсветкой кромки.
        final cliff = Path()
          ..moveTo(_w * 0.58, _hz + 1)
          ..lineTo(_w * 0.585, _hz - 40)
          ..lineTo(_w * 0.93, _hz - 36)
          ..lineTo(_w * 0.94, _hz + 1)
          ..close();
        c.drawPath(cliff, paint);
        c.drawLine(
          Offset(_w * 0.585, _hz - 39),
          Offset(_w * 0.93, _hz - 35),
          Paint()
            ..color = spec.sunColor.withValues(alpha: 0.5)
            ..strokeWidth = 2,
        );
        _reflectBand(c, 20);
      case TerrainKind.snags:
        _snags(c, rnd);
      case TerrainKind.reeds:
        _reflectBand(c, 12);
      case TerrainKind.wide:
        _reflectBand(c, 10);
    }
  }

  /// Тёмная «тень-отражение» берега сразу под горизонтом — вода оживает.
  void _reflectBand(Canvas c, double depth) {
    c.drawRect(
      Rect.fromLTWH(0, _hz, _w, depth),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            spec.mid.withValues(alpha: 0.45),
            spec.mid.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, _hz, _w, depth)),
    );
  }

  /// Сосна: ствол + три яруса кроны.
  void _pine(Canvas c, Paint paint, double x, double baseY, double height) {
    final trunkH = height * 0.22;
    c.drawLine(
      Offset(x, baseY),
      Offset(x, baseY - trunkH - 2),
      Paint()
        ..color = paint.color
        ..strokeWidth = math.max(2, height * 0.05),
    );
    final tiers = 3;
    for (var i = 0; i < tiers; i++) {
      final f = i / tiers;
      final tierW = height * 0.42 * (1 - f * 0.55);
      final tierTop = baseY - trunkH - height * (0.25 + 0.75 * f);
      final tierBot = baseY - trunkH - height * (0.05 + 0.62 * f);
      c.drawPath(
        Path()
          ..moveTo(x, tierTop)
          ..lineTo(x - tierW / 2, tierBot)
          ..lineTo(x + tierW / 2, tierBot)
          ..close(),
        paint,
      );
    }
  }

  void _skerry(Canvas c, math.Random rnd, double x, double width) {
    final rockH = 30.0 + rnd.nextDouble() * 16;
    final rock = Path()
      ..moveTo(x - width / 2, _hz + 4)
      ..quadraticBezierTo(
          x - width * 0.2, _hz - rockH, x + width * 0.08, _hz - rockH * 0.8)
      ..quadraticBezierTo(x + width * 0.36, _hz - rockH * 0.55, x + width / 2, _hz + 4)
      ..close();
    c.drawPath(rock, Paint()..color = spec.mid);
    // Светлая кромка гранита со стороны солнца.
    c.drawPath(
      rock,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = spec.sunColor.withValues(alpha: 0.30),
    );
    // Сосны на лбу.
    final pinePaint = Paint()..color = spec.mid;
    final n = 2 + rnd.nextInt(2);
    for (var i = 0; i < n; i++) {
      final px = x - width * 0.22 + i * width * (0.42 / math.max(1, n - 1));
      _pine(c, pinePaint, px, _hz - rockH * (0.55 + rnd.nextDouble() * 0.2),
          44 + rnd.nextDouble() * 26);
    }
    // Отражение острова в воде.
    final mirrorH = rockH * 1.6;
    c.drawOval(
      Rect.fromCenter(
          center: Offset(x, _hz + mirrorH * 0.45),
          width: width * 0.96,
          height: mirrorH),
      Paint()
        ..color = spec.mid.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _pineRow(Canvas c, math.Random rnd, Paint paint, double from, double to,
      {double density = 1.0, double scale = 1.0}) {
    var x = from + 8;
    while (x < to) {
      if (rnd.nextDouble() < density) {
        _pine(c, paint, x, _hz + 2, (26 + rnd.nextDouble() * 26) * scale);
      }
      x += 14 + rnd.nextDouble() * 18;
    }
  }

  void _willows(Canvas c, math.Random rnd, Paint paint) {
    for (final fx in [0.07, 0.2, 0.88]) {
      final x = _w * fx;
      final r = 30.0 + rnd.nextDouble() * 20;
      for (var k = 0; k < 3; k++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x + (k - 1) * r * 0.55, _hz - r * 0.42 + k * 4),
            width: r * (1.3 - k * 0.18),
            height: r * (0.78 - k * 0.1),
          ),
          paint,
        );
      }
      c.drawLine(
        Offset(x, _hz + 2),
        Offset(x, _hz - r * 0.3),
        Paint()
          ..color = paint.color
          ..strokeWidth = 4,
      );
    }
  }

  void _snags(Canvas c, math.Random rnd) {
    for (final fx in [0.15, 0.33, 0.70, 0.88]) {
      final x = _w * fx;
      final y = _hz + (_h - _hz) * (0.16 + rnd.nextDouble() * 0.30);
      final tilt = (rnd.nextDouble() - 0.5) * 0.9;
      final len = 34 + rnd.nextDouble() * 40;
      final top = Offset(x + tilt * len, y - len);
      final wPaint = Paint()
        ..color = spec.mid
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(x, y), top, wPaint);
      // Боковые сучья.
      final m1 = Offset.lerp(Offset(x, y), top, 0.5)!;
      final m2 = Offset.lerp(Offset(x, y), top, 0.78)!;
      c.drawLine(m1, m1 + Offset(12 + tilt * 10, -12), wPaint..strokeWidth = 2.6);
      c.drawLine(m2, m2 + Offset(-9 + tilt * 6, -9), wPaint..strokeWidth = 2.2);
      // Отражение и круги у комля.
      c.drawLine(
        Offset(x, y),
        Offset(x - tilt * len * 0.55, y + len * 0.45),
        Paint()
          ..color = spec.mid.withValues(alpha: 0.35)
          ..strokeWidth = 3,
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y + 2), width: 26, height: 7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.18),
      );
    }
  }

  void _mist(Canvas c) {
    for (final band in [(-30.0, 64.0, 0.20), (6.0, 36.0, 0.12)]) {
      c.drawRect(
        Rect.fromLTWH(0, _hz + band.$1, _w, band.$2),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: band.$3 * spec.mist),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, _hz + band.$1, _w, band.$2))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  void _ripples(Canvas c, math.Random rnd) {
    final n = (80 * spec.ripple).round();
    for (var i = 0; i < n; i++) {
      final t = rnd.nextDouble();
      final y = _hz + (_h - _hz) * (t * t);
      final len = 18 + rnd.nextDouble() * 90 * (0.4 + t);
      final x = rnd.nextDouble() * (_w - len);
      // Тёмная и светлая стороны волны — объём.
      c.drawLine(
        Offset(x, y + 1.4),
        Offset(x + len, y + 1.4),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.045 + 0.05 * t)
          ..strokeWidth = 1 + t * 1.4,
      );
      c.drawLine(
        Offset(x, y),
        Offset(x + len, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05 + 0.07 * t)
          ..strokeWidth = 1 + t * 1.6,
      );
    }
  }

  // --- Передний план ---------------------------------------------------------

  void _foreground(Canvas c, math.Random rnd) {
    switch (spec.terrain) {
      case TerrainKind.reeds:
        _reedCluster(c, rnd, _w * 0.05, 26);
        _reedCluster(c, rnd, _w * 0.94, 18);
      case TerrainKind.willows:
      case TerrainKind.steppe:
        final sand = Path()
          ..moveTo(0, _h)
          ..lineTo(0, _h - 30)
          ..quadraticBezierTo(_w * 0.28, _h - 52, _w * 0.55, _h - 20)
          ..quadraticBezierTo(_w * 0.72, _h - 4, _w, _h - 12)
          ..lineTo(_w, _h)
          ..close();
        c.drawPath(sand, Paint()..color = const Color(0xFF7B6648));
        c.drawPath(
          sand,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = spec.sunColor.withValues(alpha: 0.25),
        );
      case TerrainKind.mountains:
        // Прозрачное мелководье: галька с бликами.
        for (var i = 0; i < 34; i++) {
          final x = rnd.nextDouble() * _w;
          final y = _h - 6 - rnd.nextDouble() * 44;
          final pw = 12 + rnd.nextDouble() * 20;
          c.drawOval(
            Rect.fromCenter(
                center: Offset(x, y), width: pw, height: pw * 0.45),
            Paint()
              ..color = const Color(0xFF7C8890)
                  .withValues(alpha: 0.20 + rnd.nextDouble() * 0.22),
          );
          c.drawOval(
            Rect.fromCenter(
                center: Offset(x - pw * 0.14, y - 1.5),
                width: pw * 0.4,
                height: pw * 0.16),
            Paint()..color = Colors.white.withValues(alpha: 0.10),
          );
        }
      case TerrainKind.skerries:
        // Тёмный гранитный валун в кадре слева с бликом сверху.
        final rock = Path()
          ..moveTo(-12, _h)
          ..lineTo(-8, _h - 56)
          ..quadraticBezierTo(_w * 0.06, _h - 88, _w * 0.15, _h - 44)
          ..quadraticBezierTo(_w * 0.18, _h - 16, _w * 0.155, _h)
          ..close();
        c.drawPath(rock, Paint()..color = const Color(0xFF23282E));
        c.drawPath(
          Path()
            ..moveTo(-6, _h - 54)
            ..quadraticBezierTo(_w * 0.06, _h - 86, _w * 0.145, _h - 44),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = spec.sunColor.withValues(alpha: 0.22),
        );
      default:
        break;
    }
  }

  void _reedCluster(Canvas c, math.Random rnd, double x, int count) {
    for (var i = 0; i < count; i++) {
      final bx = x + (rnd.nextDouble() - 0.5) * 80;
      final len = 90 + rnd.nextDouble() * 130;
      final sway = (rnd.nextDouble() - 0.5) * 34;
      final top = Offset(bx + sway, _h - len);
      final dark = rnd.nextDouble() < 0.5;
      final stem = Paint()
        ..strokeWidth = 2.2 + rnd.nextDouble() * 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..color = dark ? const Color(0xFF1C2519) : const Color(0xFF2E3D27);
      c.drawPath(
        Path()
          ..moveTo(bx, _h + 4)
          ..quadraticBezierTo(
              bx + sway * 0.4, _h - len * 0.6, top.dx, top.dy),
        stem,
      );
      if (rnd.nextDouble() < 0.55) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: top - const Offset(0, 9),
                width: 8,
                height: 24 + rnd.nextDouble() * 8),
            const Radius.circular(5),
          ),
          Paint()..color = const Color(0xFF53412A),
        );
      }
    }
  }

  void _vignette(Canvas c) {
    c.drawRect(
      Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.15,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.26),
          ],
          stops: const [0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, _w, _h)),
    );
  }

  void _grain(Canvas c, math.Random rnd, ) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.022);
    for (var i = 0; i < 1000; i++) {
      c.drawCircle(
        Offset(rnd.nextDouble() * _w, rnd.nextDouble() * _h),
        rnd.nextDouble() * 0.9,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BackdropPainter old) => old.spec != spec;
}

/// Спеки фонов всех российских водоёмов (id локации → пейзаж).
const kRuBackdropSpecs = <String, BackdropSpec>{
  'ru_ladoga': BackdropSpec(
    seed: 11,
    skyTop: Color(0xFF1F3A55),
    skyHorizon: Color(0xFFEFB868),
    sunColor: Color(0xFFFFD489),
    sunX: 0.30, sunY: 0.72,
    waterFar: Color(0xFF31506E), waterNear: Color(0xFF101F2E),
    far: Color(0xFF31435A), mid: Color(0xFF18242E),
    terrain: TerrainKind.skerries, mist: 0.8,
  ),
  'ru_seliger': BackdropSpec(
    seed: 22,
    skyTop: Color(0xFF5E9BC2),
    skyHorizon: Color(0xFFF7DBA0),
    sunColor: Color(0xFFFFE6A6),
    sunX: 0.60, sunY: 0.62,
    waterFar: Color(0xFF5F8BA2), waterNear: Color(0xFF1E3641),
    far: Color(0xFF49705C), mid: Color(0xFF1E3326),
    terrain: TerrainKind.reeds, mist: 0.5, ripple: 0.7,
  ),
  'ru_rybinsk': BackdropSpec(
    seed: 33,
    skyTop: Color(0xFF49565F),
    skyHorizon: Color(0xFFBFC7CC),
    sunColor: Color(0xFFE5EAEE),
    sunX: 0.76, sunY: 0.44,
    waterFar: Color(0xFF5F6F79), waterNear: Color(0xFF20292F),
    far: Color(0xFF414E57), mid: Color(0xFF161C20),
    terrain: TerrainKind.snags, clouds: 6, ripple: 1.3,
  ),
  'ru_don': BackdropSpec(
    seed: 44,
    skyTop: Color(0xFF50639A),
    skyHorizon: Color(0xFFF2A75D),
    sunColor: Color(0xFFFFBE6E),
    sunX: 0.16, sunY: 0.76,
    waterFar: Color(0xFF7E6B49), waterNear: Color(0xFF2B2618),
    far: Color(0xFF5E5040), mid: Color(0xFF6E5337),
    terrain: TerrainKind.steppe, ripple: 0.8,
  ),
  'ru_akhtuba': BackdropSpec(
    seed: 55,
    skyTop: Color(0xFF2F74BC),
    skyHorizon: Color(0xFFD8E8F0),
    sunColor: Color(0xFFFFF6CF),
    sunX: 0.84, sunY: 0.26,
    waterFar: Color(0xFF558CA8), waterNear: Color(0xFF173543),
    far: Color(0xFF4E7058), mid: Color(0xFF263F2C),
    terrain: TerrainKind.willows, ripple: 0.9,
  ),
  'ru_yenisei': BackdropSpec(
    seed: 66,
    skyTop: Color(0xFF253F4D),
    skyHorizon: Color(0xFFB6CFC0),
    sunColor: Color(0xFFE2F0DC),
    sunX: 0.5, sunY: 0.40,
    waterFar: Color(0xFF35565E), waterNear: Color(0xFF0E1F24),
    far: Color(0xFF1F3B36), mid: Color(0xFF0E211C),
    terrain: TerrainKind.taiga, mist: 1.0, ripple: 1.2,
  ),
  'ru_baikal': BackdropSpec(
    seed: 77,
    skyTop: Color(0xFF2257A0),
    skyHorizon: Color(0xFFCBE6F2),
    sunColor: Color(0xFFF6FBFF),
    sunX: 0.70, sunY: 0.30,
    waterFar: Color(0xFF2778A4), waterNear: Color(0xFF092C42),
    far: Color(0xFF3A597E), mid: Color(0xFF1B374D),
    terrain: TerrainKind.mountains, mist: 0.35, ripple: 0.6,
  ),
  'ru_amur': BackdropSpec(
    seed: 88,
    skyTop: Color(0xFF6F6188),
    skyHorizon: Color(0xFFF6C58D),
    sunColor: Color(0xFFFFD39A),
    sunX: 0.46, sunY: 0.70,
    waterFar: Color(0xFF7C6753), waterNear: Color(0xFF241E18),
    far: Color(0xFF4E4250), mid: Color(0xFF291F2C),
    terrain: TerrainKind.wide, mist: 0.9, clouds: 4,
  ),
  'ru_kamchatka': BackdropSpec(
    seed: 99,
    skyTop: Color(0xFF2B567F),
    skyHorizon: Color(0xFFE0EBF0),
    sunColor: Color(0xFFF8FCFE),
    sunX: 0.14, sunY: 0.32,
    waterFar: Color(0xFF45727F), waterNear: Color(0xFF102832),
    far: Color(0xFF3E5266), mid: Color(0xFF1C2E37),
    terrain: TerrainKind.volcano, mist: 0.4, ripple: 1.6,
  ),
};
