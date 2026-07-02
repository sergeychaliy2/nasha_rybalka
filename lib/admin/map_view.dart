import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../features/map/region_store.dart';
import '../features/map/russia_geo.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Точка на карте админки.
typedef MapPin = ({String id, String label, double lon, double lat});

/// Полноэкранная карта РФ: плавный зум (+/−, колесо, двойной тап), панорама,
/// тап по точке → onTapPin, тап по региону (или выбор в «Найти») → регион
/// подсвечивается и остаются видны только его точки.
class AdminMapView extends StatefulWidget {
  const AdminMapView({
    super.key,
    required this.title,
    required this.regions,
    required this.bounds,
    required this.pins,
    required this.onTapPin,
    this.pinColor = _gold,
    this.itemWord = 'локаций',
  });
  final String title;
  final List<RuRegion> regions;
  final Rect bounds;
  final List<MapPin> pins;
  final void Function(String id) onTapPin;

  /// Цвет точек (локации — золотые, турниры — красные).
  final Color pinColor;

  /// Слово для счётчика в баннере региона («локаций» / «турниров»).
  final String itemWord;

  @override
  State<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends State<AdminMapView>
    with SingleTickerProviderStateMixin {
  double _s = 1;
  Offset _o = Offset.zero;
  double _pinchStart = 1;
  Size _viewport = Size.zero;
  RussiaMapTransform? _t;
  RuRegion? _sel;

  late final AnimationController _zoom;
  double _sFrom = 1, _sTo = 1;
  Offset _oFrom = Offset.zero, _oTo = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..addListener(() {
        final e = Curves.easeOutCubic.transform(_zoom.value);
        setState(() {
          _s = _sFrom + (_sTo - _sFrom) * e;
          _o = Offset.lerp(_oFrom, _oTo, e)!;
        });
      });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _clampPan() {
    final minX = _viewport.width * (1 - _s);
    final minY = _viewport.height * (1 - _s);
    _o = Offset(_o.dx.clamp(minX, 0.0), _o.dy.clamp(minY, 0.0));
  }

  void _applyZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    if (next == _s) return;
    final k = next / _s;
    _o = anchor - (anchor - _o) * k;
    _s = next;
    _clampPan();
    setState(() {});
  }

  void _animateTo(double next, Offset o) {
    _sFrom = _s;
    _sTo = next;
    _oFrom = _o;
    _oTo = o;
    _zoom.forward(from: 0);
  }

  void _animateZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    if (next == _s) return;
    final k = next / _s;
    var o = anchor - (anchor - _o) * k;
    final minX = _viewport.width * (1 - next);
    final minY = _viewport.height * (1 - next);
    o = Offset(o.dx.clamp(minX, 0.0), o.dy.clamp(minY, 0.0));
    _animateTo(next, o);
  }

  void _animateReset() {
    setState(() => _sel = null);
    _animateTo(1, Offset.zero);
  }

  void _panBy(Offset d) {
    if (_s <= 1) return;
    _o += d;
    _clampPan();
    setState(() {});
  }

  /// Плавно навести и приблизить на регион.
  void _focusRegion(RuRegion r) {
    final t = _t;
    if (t == null) return;
    double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    for (final ring in r.rings) {
      for (final pt in ring) {
        final p = t.map(pt.dx, pt.dy);
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    final rw = math.max(1.0, maxX - minX);
    final rh = math.max(1.0, maxY - minY);
    final next =
        (math.min(_viewport.width / rw, _viewport.height / rh) * 0.75)
            .clamp(1.0, 8.0);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    var o = Offset(_viewport.width / 2 - cx * next, _viewport.height / 2 - cy * next);
    final minOX = _viewport.width * (1 - next);
    final minOY = _viewport.height * (1 - next);
    o = Offset(o.dx.clamp(minOX, 0.0), o.dy.clamp(minOY, 0.0));
    _animateTo(next, o);
  }

  void _selectRegion(RuRegion? r) {
    setState(() => _sel = r);
    if (r != null) _focusRegion(r);
  }

  void _tap(Offset local) {
    final t = _t;
    if (t == null) return;
    final base = (local - _o) / _s;
    // Сначала — точки.
    String? best;
    var bestD = 22.0 / _s;
    for (final p in widget.pins) {
      final dd = (t.map(p.lon, p.lat) - base).distance;
      if (dd < bestD) {
        bestD = dd;
        best = p.id;
      }
    }
    if (best != null) {
      widget.onTapPin(best);
      return;
    }
    // Иначе — регион под курсором: подсветить и показать его точки.
    final geo = t.unmap(base);
    for (final r in widget.regions) {
      if (r.contains(geo.$1, geo.$2)) {
        setState(() => _sel = r.nameEn == _sel?.nameEn ? null : r);
        return;
      }
    }
  }

  int get _countInSel {
    final r = _sel;
    if (r == null) return widget.pins.length;
    return widget.pins.where((p) => r.contains(p.lon, p.lat)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(widget.title, style: const TextStyle(color: _gold)),
        actions: [
          // «Найти» — выбрать регион и навести на него.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RuRegion?>(
                value: _sel,
                hint: const Row(children: [
                  Icon(Icons.search, color: _gold, size: 18),
                  SizedBox(width: 4),
                  Text('Найти регион', style: TextStyle(color: _gold)),
                ]),
                dropdownColor: _panel,
                menuMaxHeight: 360,
                iconEnabledColor: _gold,
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— все регионы —')),
                  for (final r in widget.regions)
                    DropdownMenuItem(value: r, child: Text(r.nameRu)),
                ],
                onChanged: _selectRegion,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _viewport = size;
        _t = RussiaMapTransform.fitRaw(widget.bounds, size, paddingFrac: 0.03);
        return Stack(children: [
          Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                _applyZoom(math.exp(-e.scrollDelta.dy / 380), e.localPosition);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTapDown: (d) =>
                  _animateZoom(_s < 4 ? 2.0 : 1 / _s, d.localPosition),
              onScaleStart: (_) => _pinchStart = _s,
              onScaleUpdate: (d) {
                if (d.scale != 1) {
                  _applyZoom((_pinchStart * d.scale) / _s, d.localFocalPoint);
                } else {
                  _panBy(d.focalPointDelta);
                }
              },
              onTapUp: (d) => _tap(d.localPosition),
              child: ClipRect(
                child: Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(_o.dx, _o.dy, 0, 1)
                    ..scaleByDouble(_s, _s, 1, 1),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CustomPaint(
                      painter: _MapViewPainter(
                          _t!, widget.regions, widget.pins, widget.pinColor,
                          _sel),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_sel != null)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.pinColor.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${_sel!.nameRu} · $_countInSel ${widget.itemWord}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Показать все',
                    onPressed: () => setState(() => _sel = null),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ]),
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(children: [
              _btn(Icons.add,
                  () => _animateZoom(1.6, _viewport.center(Offset.zero))),
              _btn(Icons.remove,
                  () => _animateZoom(1 / 1.6, _viewport.center(Offset.zero))),
              _btn(Icons.center_focus_strong, _animateReset),
            ]),
          ),
          const Positioned(
            left: 14,
            bottom: 12,
            child: Text('Тап по точке — правка · тап по региону — показать что в нём',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ]);
      }),
    );
  }

  Widget _btn(IconData i, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF15181C),
            shape: BoxShape.circle,
            border: Border.all(color: _gold.withValues(alpha: 0.5)),
          ),
          child: Icon(i, color: Colors.white, size: 20),
        ),
      );
}

class _MapViewPainter extends CustomPainter {
  _MapViewPainter(this.t, this.regions, this.pins, this.pinColor, this.sel);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<MapPin> pins;
  final Color pinColor;
  final RuRegion? sel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B1016));
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = const Color(0x30FFFFFF);
    for (final r in regions) {
      final path = Path();
      for (final ring in r.rings) {
        for (var i = 0; i < ring.length; i++) {
          final p = t.map(ring[i].dx, ring[i].dy);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
      }
      final isSel = sel != null && r.nameEn == sel!.nameEn;
      canvas.drawPath(
          path,
          Paint()
            ..color = isSel ? const Color(0xFF32271B) : const Color(0xFF16221B));
      canvas.drawPath(
          path,
          isSel
              ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = pinColor)
              : border);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final p in pins) {
      final inSel = sel == null || sel!.contains(p.lon, p.lat);
      final o = t.map(p.lon, p.lat);
      final col = inSel ? pinColor : pinColor.withValues(alpha: 0.18);
      canvas.drawCircle(o, 6, Paint()..color = col.withValues(alpha: 0.25));
      canvas.drawCircle(o, 3.2, Paint()..color = col);
      canvas.drawCircle(
          o,
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withValues(alpha: inSel ? 1 : 0.3));
      if (!inSel) continue; // подписи только для активных
      tp.text = TextSpan(
          text: p.label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)]));
      tp.layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _MapViewPainter old) => true;
}
