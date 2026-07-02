import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Геометрия изгиба удилища — общий модуль рендера снасти (Canvas).
/// Чистые функции над [Canvas]: считают точки бланка и рисуют удилище, леску,
/// поплавок и катушку. Используется сценой ловли (и демо-прототипами).
class RodGeometry {
  RodGeometry(this.points, this.tip);

  /// Точки осевой линии бланка от комля (в руке) к кончику.
  final List<Offset> points;

  /// Кончик удилища (точка схода лески).
  final Offset tip;
}

/// Считает точки изогнутого удилища.
///
/// Комель — за нижне‑правым углом (в руке), кончик уходит вверх‑влево. Под
/// нагрузкой ([bend] > 0) кончик гнётся к воде/леске (кантилевер ~ t²).
///
/// [pull] 0..1 — «оттяжка к игроку» при вываживании: комель служит осью, и весь
/// бланк заводится назад/вверх к руке (кончик идёт к вертикали). Это даёт
/// живую позу «тяну рыбу на себя», а одновременный [bend] держит кончик
/// нагруженным к поплавку — как в реальном вываживании.
RodGeometry computeRod(Size size, double bend, double time, {double pull = 0}) {
  final w = size.width;
  final h = size.height;
  final butt = Offset(w * 0.95, h * 1.08);
  final restTip = Offset(w * 0.60, h * 0.05);

  // Поворот бланка к игроку: вращаем хорду «комель→кончик» вокруг комля.
  // Знак подобран так, чтобы кончик шёл к вертикали (на рыбака), а не от него.
  final chord0 = restTip - butt;
  final theta = pull * 0.30; // рад (~17° при полной оттяжке)
  final cosT = math.cos(theta);
  final sinT = math.sin(theta);
  final rotated = Offset(
    chord0.dx * cosT - chord0.dy * sinT,
    chord0.dx * sinT + chord0.dy * cosT,
  );
  final tipRest = butt + rotated;

  final chord = tipRest - butt;
  final len = chord.distance;
  final dir = chord / len;
  // Перпендикуляр в сторону воды/лески — туда гнётся кончик.
  final perp = Offset(dir.dy, -dir.dx);

  const n = 22;
  final pts = <Offset>[];
  final maxBendPx = len * 0.95;
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final base = butt + dir * (len * t);
    final disp = perp * (t * t * bend * maxBendPx);
    final tremor = math.sin(time * 9 + t * 6) * 0.6 * t * t;
    pts.add(base + disp + perp * tremor);
  }
  return RodGeometry(pts, pts.last);
}

/// Рисует удилище (тень, тейпер‑корпус, блик, пропускные кольца).
void paintRod(Canvas canvas, RodGeometry geo) {
  final pts = geo.points;
  const buttW = 9.5;
  const tipW = 1.4;

  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    final prev = pts[i == 0 ? 0 : i - 1];
    final next = pts[i == pts.length - 1 ? i : i + 1];
    final tan = next - prev;
    final tl = tan.distance == 0 ? const Offset(0, -1) : tan / tan.distance;
    final nrm = Offset(-tl.dy, tl.dx);
    final t = i / (pts.length - 1);
    final wHalf = ui.lerpDouble(buttW, tipW, t)! / 2;
    left.add(pts[i] + nrm * wHalf);
    right.add(pts[i] - nrm * wHalf);
  }

  final body = Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    body.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    body.lineTo(p.dx, p.dy);
  }
  body.close();

  canvas.drawPath(
    body.shift(const Offset(2, 3)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  final rect = body.getBounds();
  canvas.drawPath(
    body,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topRight,
        rect.bottomLeft,
        const [Color(0xFF2A2E33), Color(0xFF0E1013)],
      ),
  );

  final hl = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    hl.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(
    hl,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.22),
  );

  for (var i = 4; i < pts.length - 1; i += 4) {
    canvas.drawCircle(
      pts[i],
      ui.lerpDouble(3.2, 1.6, i / pts.length)!,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.white.withValues(alpha: 0.30),
    );
  }
}

/// Рисует катушку на удилище возле комля. [angle] — угол вращения шпули
/// (растёт при подмотке → видно, что «катушка крутится»).
void paintReel(Canvas canvas, RodGeometry geo, double angle) {
  final pts = geo.points;
  if (pts.length < 3) return;

  // Точка крепления — ближе к комлю (где стоит катушкодержатель).
  final i = (pts.length * 0.16).round().clamp(1, pts.length - 1);
  final at = pts[i];
  final tan = pts[i] - pts[i - 1];
  final tl = tan.distance == 0 ? const Offset(0, -1) : tan / tan.distance;
  // Нормаль к удилищу; выбираем ту сторону, что свисает вниз (к руке/воде).
  var nrm = Offset(-tl.dy, tl.dx);
  if (nrm.dy < 0) nrm = -nrm;

  const stem = 11.0; // вынос ножки катушки
  const r = 9.5; // радиус шпули
  final center = at + nrm * (stem + r);

  // Ножка катушкодержателя.
  canvas.drawLine(
    at,
    center - nrm * r,
    Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B1E22),
  );

  // Корпус шпули: тень → тело → ободок.
  canvas.drawCircle(
    center + const Offset(1.5, 2),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.4),
  );
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        center - Offset(r * 0.3, r * 0.3),
        r * 1.4,
        const [Color(0xFF3A4047), Color(0xFF14171B)],
      ),
  );
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF6E7681).withValues(alpha: 0.7),
  );

  // Спицы шпули — вращаются (видимая подмотка).
  final spokePaint = Paint()
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round
    ..color = Colors.white.withValues(alpha: 0.34);
  for (var s = 0; s < 4; s++) {
    final a = angle + s * math.pi / 2;
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(center - d * (r * 0.7), center + d * (r * 0.7), spokePaint);
  }
  // Ступица.
  canvas.drawCircle(center, 2.4, Paint()..color = const Color(0xFFC9CDD2));

  // Ручка катушки на орбите — главный «крутящийся» элемент.
  final knob = center + Offset(math.cos(angle), math.sin(angle)) * (r + 4.5);
  canvas.drawLine(
    center,
    knob,
    Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF20242A),
  );
  canvas.drawCircle(knob, 3.2, Paint()..color = const Color(0xFFE6A23C));
}

/// Рисует леску от кончика удилища к поплавку с провисом (taut: 0 провис → 1 струна).
void paintLine(Canvas canvas, Offset tip, Offset floatPx, double taut) {
  final mid = Offset.lerp(tip, floatPx, 0.5)!;
  final slack = ui.lerpDouble(46, 2, taut)!;
  final ctrl = mid + Offset(0, slack);
  final path = Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, floatPx.dx, floatPx.dy);

  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.black.withValues(alpha: 0.25),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.55),
  );
}

/// Рисует поплавок (тело + красная антенна + блик). [dip] 0..1 — утопление.
void paintFloat(Canvas canvas, Offset f, double dip, [double scale = 1.0]) {
  canvas.drawOval(
    Rect.fromCenter(
        center: f + Offset(0, 2 * scale),
        width: 16 * scale,
        height: 5 * scale),
    Paint()..color = Colors.black.withValues(alpha: 0.22 * (1 - dip)),
  );
  final visible = (1 - dip).clamp(0.0, 1.0);
  final bodyTop = f - Offset(0, 12 * visible * scale);
  canvas.drawLine(
    f,
    bodyTop,
    Paint()
      ..strokeWidth = 5 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEFE7DA).withValues(alpha: 0.95),
  );
  final antTop = bodyTop - Offset(0, 9 * visible * scale);
  canvas.drawLine(
    bodyTop,
    antTop,
    Paint()
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5483B).withValues(alpha: 0.95),
  );
  canvas.drawCircle(
    bodyTop + Offset(-1.2 * scale, 1 * scale),
    1.1 * scale,
    Paint()..color = Colors.white.withValues(alpha: 0.8 * visible),
  );
}
