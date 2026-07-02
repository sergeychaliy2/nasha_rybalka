import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../features/map/region_store.dart';
import '../features/map/russia_geo.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Точка на карте админки.
typedef MapPin = ({String id, String label, double lon, double lat});

/// Полноэкранная карта РФ с границами регионов и точками (турниры/локации).
/// Плавный зум (+/−, колесо, двойной тап), панорама, тап по точке → onTapPin.
class AdminMapView extends StatefulWidget {
  const AdminMapView({
    super.key,
    required this.title,
    required this.regions,
    required this.bounds,
    required this.pins,
    required this.onTapPin,
    this.pinColor = _gold,
  });
  final String title;
  final List<RuRegion> regions;
  final Rect bounds;
  final List<MapPin> pins;
  final void Function(String id) onTapPin;

  /// Цвет точек (локации — золотые, турниры — красные).
  final Color pinColor;

  @override
  State<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends State<AdminMapView>
    with SingleTickerProviderStateMixin {
  double _s = 1;
  Offset _o = Offset.zero;
  double _pinchStart = 1;
  Size _viewport = Size.zero;

  late final AnimationController _zoom;
  double _sFrom = 1, _sTo = 1;
  Offset _oFrom = Offset.zero, _oTo = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280))
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

  void _animateZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    if (next == _s) return;
    final k = next / _s;
    var o = anchor - (anchor - _o) * k;
    final minX = _viewport.width * (1 - next);
    final minY = _viewport.height * (1 - next);
    o = Offset(o.dx.clamp(minX, 0.0), o.dy.clamp(minY, 0.0));
    _sFrom = _s;
    _sTo = next;
    _oFrom = _o;
    _oTo = o;
    _zoom.forward(from: 0);
  }

  void _animateReset() {
    _sFrom = _s;
    _sTo = 1;
    _oFrom = _o;
    _oTo = Offset.zero;
    _zoom.forward(from: 0);
  }

  void _panBy(Offset d) {
    if (_s <= 1) return;
    _o += d;
    _clampPan();
    setState(() {});
  }

  void _tap(Offset local, RussiaMapTransform t) {
    // Экран → базовые координаты карты (до зума).
    final base = (local - _o) / _s;
    String? best;
    var bestD = 22.0 / _s;
    for (final p in widget.pins) {
      final dd = (t.map(p.lon, p.lat) - base).distance;
      if (dd < bestD) {
        bestD = dd;
        best = p.id;
      }
    }
    if (best != null) widget.onTapPin(best);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(widget.title, style: const TextStyle(color: _gold)),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _viewport = size;
        final t = RussiaMapTransform.fitRaw(widget.bounds, size,
            paddingFrac: 0.03);
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
              onTapUp: (d) => _tap(d.localPosition, t),
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
                          t, widget.regions, widget.pins, widget.pinColor),
                    ),
                  ),
                ),
              ),
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
            child: Text('Тап по точке — открыть на правку',
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
  _MapViewPainter(this.t, this.regions, this.pins, this.pinColor);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<MapPin> pins;
  final Color pinColor;

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
      canvas.drawPath(path, Paint()..color = const Color(0xFF16221B));
      canvas.drawPath(path, border);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final p in pins) {
      final o = t.map(p.lon, p.lat);
      canvas.drawCircle(
          o, 6, Paint()..color = pinColor.withValues(alpha: 0.25));
      canvas.drawCircle(o, 3.2, Paint()..color = pinColor);
      canvas.drawCircle(
          o,
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black);
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
