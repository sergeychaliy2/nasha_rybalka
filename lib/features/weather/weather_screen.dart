import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed/content_state.dart';
import '../map/region_store.dart';
import '../map/russia_geo.dart';
import '../shell/ui_kit.dart';
import 'weather_forecast.dart';

/// Прогноз погоды на НАШЕЙ карте России по субъектам (как основная карта):
/// регионы красятся по своей погоде, осадки анимированы (капли/снег), есть
/// зум/панорама как на карте и таймлайн-ползунок в стиле Яндекс.Погоды.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen>
    with TickerProviderStateMixin {
  WxLayer _layer = WxLayer.precip;
  double _hourAhead = 0; // 0..maxHours, плавно (без шага)
  static const _maxHours = 48;

  late final int _daySeed;
  late final DateTime _now;
  late final Map<String, String> _names;
  late final List<WxCell> _cells;
  late final AnimationController _anim;
  late final AnimationController _play; // авто-прокрутка времени (радар-петля)
  bool _playing = false;

  // Зум/панорама (как на основной карте).
  double _s = 1;
  Offset _o = Offset.zero;
  double _pinchStart = 1;
  Size _viewport = Size.zero;
  late final AnimationController _zoomCtrl; // плавный зум по кнопкам
  double _zsFrom = 1, _zsTo = 1;
  Offset _zoFrom = Offset.zero, _zoTo = Offset.zero;

  Size? _cacheSize;
  List<_RegionShape> _shapes = const [];
  Path _clip = Path(); // контур суши для клипа поля осадков

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _daySeed = _now.year * 1000 + _now.month * 31 + _now.day;
    _names = {for (final l in activeLocations()) l.id: l.name};
    _cells = weatherCells(_daySeed);
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _play = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..addListener(() {
        if (_playing) setState(() => _hourAhead = _play.value * _maxHours);
      });
    _zoomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280))
      ..addListener(() {
        final e = Curves.easeOutCubic.transform(_zoomCtrl.value);
        setState(() {
          _s = _zsFrom + (_zsTo - _zsFrom) * e;
          _o = Offset.lerp(_zoFrom, _zoTo, e)!;
        });
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    _play.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _play.repeat(); // 0→48ч за 16с, затем заново — тучи «перетекают»
      } else {
        _play.stop();
      }
    });
  }

  WxPoint _wx(String id, double lat, int hourAhead) => WeatherForecast.at(
      locId: id, lat: lat, hourAhead: hourAhead, daySeed: _daySeed);

  // --- Зум/панорама -----------------------------------------------------------

  void _applyZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    if (next == _s) return;
    final k = next / _s;
    _o = anchor - (anchor - _o) * k;
    _s = next;
    _clampPan();
    setState(() {});
  }

  void _panBy(Offset d) {
    if (_s <= 1) return;
    _o += d;
    _clampPan();
    setState(() {});
  }

  void _clampPan() {
    final minX = _viewport.width * (1 - _s);
    final minY = _viewport.height * (1 - _s);
    _o = Offset(_o.dx.clamp(minX, 0.0), _o.dy.clamp(minY, 0.0));
  }

  /// Плавный зум к якорю (для кнопок): анимируем масштаб и смещение.
  void _animateZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    if (next == _s) return;
    final k = next / _s;
    var o = anchor - (anchor - _o) * k;
    final minX = _viewport.width * (1 - next);
    final minY = _viewport.height * (1 - next);
    o = Offset(o.dx.clamp(minX, 0.0), o.dy.clamp(minY, 0.0));
    _zsFrom = _s;
    _zsTo = next;
    _zoFrom = _o;
    _zoTo = o;
    _zoomCtrl.forward(from: 0);
  }

  void _animateReset() {
    _zsFrom = _s;
    _zsTo = 1;
    _zoFrom = _o;
    _zoTo = Offset.zero;
    _zoomCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(russiaRegionsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A1018),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _layerTabs(),
            Expanded(
              child: regionsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Ошибка карты: $e',
                        style: const TextStyle(color: Colors.white54))),
                data: (regions) => LayoutBuilder(
                  builder: (context, c) {
                    final size = Size(c.maxWidth, c.maxHeight);
                    _viewport = size;
                    final bounds = RussiaMapTransform.projectedBoundsOf(
                        regions.expand((r) => r.rings).expand((ring) => ring));
                    final t = RussiaMapTransform.fitRaw(bounds, size,
                        paddingFrac: 0.04);
                    if (_cacheSize != size) {
                      _shapes = _buildShapes(regions, t);
                      _clip = _buildClip(_shapes);
                      _cacheSize = size;
                    }
                    return Stack(children: [
                      Listener(
                        onPointerSignal: (e) {
                          if (e is PointerScrollEvent) {
                            _applyZoom(
                                math.exp(-e.scrollDelta.dy / 380),
                                e.localPosition);
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTapDown: (d) => _applyZoom(
                              _s < 4 ? 2.0 : 1 / _s, d.localPosition),
                          onScaleStart: (_) => _pinchStart = _s,
                          onScaleUpdate: (d) {
                            if (d.scale != 1) {
                              _applyZoom(
                                  (_pinchStart * d.scale) / _s,
                                  d.localFocalPoint);
                            } else {
                              _panBy(d.focalPointDelta);
                            }
                          },
                          child: ClipRect(
                            child: Transform(
                              transform: Matrix4.identity()
                                ..translateByDouble(_o.dx, _o.dy, 0, 1)
                                ..scaleByDouble(_s, _s, 1, 1),
                              child: SizedBox(
                                width: size.width,
                                height: size.height,
                                child: Stack(fit: StackFit.expand, children: [
                                  CustomPaint(
                                    painter: _WxRegionPainter(_shapes, _layer,
                                        _hourAhead, _daySeed, _cells),
                                  ),
                                  if (_layer == WxLayer.precip ||
                                      _layer == WxLayer.snow)
                                    AnimatedBuilder(
                                      animation: _anim,
                                      builder: (_, _) => CustomPaint(
                                        painter: _CloudFieldPainter(
                                          t: t,
                                          cells: _cells,
                                          hour: _hourAhead,
                                          phase: _anim.value,
                                          snowOnly: _layer == WxLayer.snow,
                                          clip: _clip,
                                        ),
                                      ),
                                    ),
                                  for (final e in activeWaterGeo().entries)
                                    _pin(e.key, e.value, t),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _zoomControls(),
                    ]);
                  },
                ),
              ),
            ),
            _timeline(),
          ],
        ),
      ),
    );
  }

  List<_RegionShape> _buildShapes(List<RuRegion> regions, RussiaMapTransform t) {
    final out = <_RegionShape>[];
    for (final r in regions) {
      final path = Path();
      var sx = 0.0, sy = 0.0;
      var n = 0;
      for (final ring in r.rings) {
        for (var i = 0; i < ring.length; i++) {
          final q = t.map(ring[i].dx, ring[i].dy);
          if (i == 0) {
            path.moveTo(q.dx, q.dy);
          } else {
            path.lineTo(q.dx, q.dy);
          }
          sx += ring[i].dx;
          sy += ring[i].dy;
          n++;
        }
        path.close();
      }
      out.add(
          _RegionShape(path, n > 0 ? sx / n : 0, n > 0 ? sy / n : 0, r.nameEn));
    }
    return out;
  }

  /// Объединённый контур суши (все регионы) — клип-маска для поля осадков,
  /// чтобы тучи не вылезали в «море». Строится один раз на размер.
  Path _buildClip(List<_RegionShape> shapes) {
    final p = Path();
    for (final s in shapes) {
      p.addPath(s.path, Offset.zero);
    }
    return p;
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Icon(Icons.cloud_outlined, color: kGold, size: 20),
        const SizedBox(width: 8),
        const Text('Прогноз погоды · Россия',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _layerTabs() {
    const tabs = [
      (WxLayer.precip, Icons.cloud, 'Осадки'),
      (WxLayer.temp, Icons.thermostat, 'Температура'),
      (WxLayer.wind, Icons.air, 'Ветер'),
      (WxLayer.pressure, Icons.speed, 'Давление'),
      (WxLayer.snow, Icons.ac_unit, 'Снег'),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (layer, icon, label) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _layer = layer),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _layer == layer
                        ? kGold.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: _layer == layer
                            ? kGold
                            : Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon,
                        size: 16,
                        color: _layer == layer ? kGold : Colors.white70),
                    const SizedBox(width: 7),
                    Text(label,
                        style: TextStyle(
                            color: _layer == layer ? kGold : Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _zoomControls() {
    Widget btn(IconData i, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF15181C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(i, color: Colors.white, size: 20),
          ),
        );
    return Positioned(
      right: 12,
      top: 12,
      child: SafeArea(
        child: Column(children: [
          btn(Icons.add,
              () => _animateZoom(1.6, _viewport.center(Offset.zero))),
          btn(Icons.remove,
              () => _animateZoom(1 / 1.6, _viewport.center(Offset.zero))),
          btn(Icons.center_focus_strong, _animateReset),
        ]),
      ),
    );
  }

  // --- Таймлайн-ползунок (как в Яндекс.Погоде) -------------------------------

  String _clockLabel(int hourAhead) {
    if (hourAhead == 0) return 'Сейчас';
    final dt = _now.add(Duration(hours: hourAhead));
    return '${dt.hour.toString().padLeft(2, '0')}:00';
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _playing
              ? kGold.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: _playing ? kGold : Colors.white24),
        ),
        child: Icon(_playing ? Icons.pause : Icons.play_arrow,
            color: _playing ? kGold : Colors.white70, size: 22),
      ),
    );
  }

  Widget _timeline() {
    const marks = [0, 6, 12, 18, 24, 30, 36, 42, 48];
    return Container(
      height: 74,
      decoration: const BoxDecoration(
        color: Color(0xFF11161D),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
      child: Row(children: [
        _playButton(),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            double xOf(num h) => (h / _maxHours) * w;
            final px = xOf(_hourAhead);
            void setFromX(double x) => setState(() {
                  if (_playing) {
                    _playing = false;
                    _play.stop();
                  }
                  _hourAhead =
                      (x / w * _maxHours).clamp(0.0, _maxHours.toDouble());
                });
            final wx = _wxAtNearestWater(_hourAhead.round());
            return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setFromX(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => setFromX(d.localPosition.dx),
          child: Stack(clipBehavior: Clip.none, children: [
            // Подписи времени.
            for (final h in marks)
              Positioned(
                left: (xOf(h) - 20).clamp(0.0, w - 40),
                top: 8,
                width: 40,
                child: Text(
                  _clockLabel(h),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: h == _hourAhead.round() ? kGold : Colors.white60,
                    fontSize: 11,
                    fontWeight: h == 0 ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            // Дорожка.
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Заполненная часть.
            Positioned(
              left: 0,
              bottom: 20,
              width: px.clamp(0.0, w),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [kGoldLight, kGold]),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Красная линия-указатель.
            Positioned(
              left: px - 1,
              top: 4,
              bottom: 8,
              child: Container(width: 2, color: const Color(0xFFE5483B)),
            ),
            // Бегунок-облако с текущей погодой.
            Positioned(
              left: px - 16,
              bottom: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2027),
                  shape: BoxShape.circle,
                  border: Border.all(color: kGold, width: 1.6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6)
                  ],
                ),
                child: Icon(wxIcon(wx.kind), size: 17, color: wxColor(wx.kind)),
              ),
            ),
          ]),
            );
          }),
        ),
      ]),
    );
  }

  /// Усреднённая «погода-бегунок» — берём ближайший к центру водоём для иконки.
  WxPoint _wxAtNearestWater(int hourAhead) {
    final first = activeWaterGeo().entries.first;
    return _wx(first.key, first.value.$2, hourAhead);
  }

  // --- Метка погоды над водоёмом (контр-масштаб, чтобы не росла при зуме) -----

  Widget _pin(String id, (double, double) lonLat, RussiaMapTransform t) {
    final p = t.map(lonLat.$1, lonLat.$2);
    final wx = _wx(id, lonLat.$2, _hourAhead.round());
    return Positioned(
      left: p.dx,
      top: p.dy,
      child: Transform.scale(
        scale: 1 / _s,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: GestureDetector(
            onTap: () => _showDetail(id, lonLat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGold.withValues(alpha: 0.5)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 6)
                ],
              ),
              child: _chipContent(wx),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipContent(WxPoint wx) {
    switch (_layer) {
      case WxLayer.precip:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(wxIcon(wx.kind), size: 16, color: wxColor(wx.kind)),
          const SizedBox(width: 4),
          Text(tempStr(wx.tempC),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ]);
      case WxLayer.temp:
        return Text(tempStr(wx.tempC),
            style: TextStyle(
                color: tempColor(wx.tempC),
                fontSize: 15,
                fontWeight: FontWeight.w900));
      case WxLayer.wind:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.air, size: 14, color: Color(0xFF8FC4DC)),
          const SizedBox(width: 3),
          Text('${wx.windKmh}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ]);
      case WxLayer.pressure:
        return Text('${wx.pressure}',
            style: const TextStyle(
                color: Color(0xFFC9CDD2),
                fontSize: 12.5,
                fontWeight: FontWeight.w800));
      case WxLayer.snow:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.ac_unit, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(wx.snowCm > 0 ? '${wx.snowCm} см' : '—',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]);
    }
  }

  void _showDetail(String id, (double, double) lonLat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12161B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: kGold, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Text(_names[id] ?? 'Водоём',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Прогноз по времени',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final h in WeatherForecast.slotsHours)
                    _detailSlot(_wx(id, lonLat.$2, h), h),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  Widget _detailSlot(WxPoint wx, int h) {
    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(WeatherForecast.slotLabel(h),
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 6),
        Icon(wxIcon(wx.kind), size: 22, color: wxColor(wx.kind)),
        const SizedBox(height: 6),
        Text(tempStr(wx.tempC),
            style: TextStyle(
                color: tempColor(wx.tempC),
                fontSize: 14,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text('${wx.windKmh} км/ч',
            style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
      ]),
    );
  }
}

class _RegionShape {
  _RegionShape(this.path, this.lon, this.lat, this.id);
  final Path path;
  final double lon;
  final double lat;
  final String id;
}

String tempStr(int t) => '${t > 0 ? '+' : ''}$t°';

IconData wxIcon(WxKind k) => switch (k) {
      WxKind.clear => Icons.wb_sunny,
      WxKind.partly => Icons.cloud_queue,
      WxKind.cloudy => Icons.cloud,
      WxKind.rain => Icons.grain,
      WxKind.snow => Icons.ac_unit,
    };

Color wxColor(WxKind k) => switch (k) {
      WxKind.clear => const Color(0xFFE6A23C),
      WxKind.partly => const Color(0xFFD7C9A8),
      WxKind.cloudy => const Color(0xFF9AA4AD),
      WxKind.rain => const Color(0xFF6FA8D9),
      WxKind.snow => Colors.white,
    };

Color tempColor(int t) {
  if (t <= -5) return const Color(0xFF4A90D9);
  if (t <= 5) return const Color(0xFF5FB8D9);
  if (t <= 15) return const Color(0xFF5FB85F);
  if (t <= 22) return const Color(0xFFE6C23C);
  if (t <= 28) return const Color(0xFFE6A23C);
  return const Color(0xFFE5483B);
}

/// Карта по субъектам: каждый регион залит по своей погоде; тонкие границы
/// дают «разделение» как на основной карте.
class _WxRegionPainter extends CustomPainter {
  _WxRegionPainter(this.shapes, this.layer, this.hour, this.daySeed, this.cells);
  final List<_RegionShape> shapes;
  final WxLayer layer;
  final double hour;
  final int daySeed;
  final List<WxCell> cells;

  static const _land = Color(0xFF1A2620);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height),
            const [Color(0xFF0E2230), Color(0xFF070F15)]),
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF0B141A).withValues(alpha: 0.8);
    final h = hour.round();
    for (final s in shapes) {
      final Color fill;
      if (layer == WxLayer.precip) {
        fill = _precipTint(s, h);
      } else {
        final wx = WeatherForecast.at(
            locId: s.id, lat: s.lat, hourAhead: h, daySeed: daySeed);
        fill = _regionColor(wx);
      }
      canvas.drawPath(s.path, Paint()..color = fill);
      canvas.drawPath(s.path, border);
    }
  }

  /// Тон региона на слое осадков: базовое состояние неба (ясно/перем./пасмурно)
  /// + подсветка под дрейфующими тучами — регион «загорается» синим под дождём и
  /// белёсым под снегом и гаснет, когда туча уходит (синхронно с перемоткой).
  Color _precipTint(_RegionShape s, int h) {
    final wx = WeatherForecast.at(
        locId: s.id, lat: s.lat, hourAhead: h, daySeed: daySeed);
    var c = switch (wx.kind) {
      WxKind.clear => _land,
      WxKind.partly => const Color(0xFF223029),
      WxKind.cloudy => const Color(0xFF2A333B),
      WxKind.rain => const Color(0xFF2A333B),
      WxKind.snow => const Color(0xFF2C353D),
    };
    var rain = 0.0, snow = 0.0;
    for (final cell in cells) {
      final inten = cell.intensityAt(hour);
      if (inten <= 0.02) continue;
      final dLon = cell.lonAt(hour) - s.lon;
      final dLat = cell.latAt(hour) - s.lat;
      final dist = math.sqrt(dLon * dLon + dLat * dLat);
      final f = (1 - dist / (cell.radiusDeg * 1.25)).clamp(0.0, 1.0);
      if (f <= 0) continue;
      if (cell.kind == WxKind.snow) {
        snow += inten * f;
      } else {
        rain += inten * f;
      }
    }
    if (snow > 0.01) {
      c = Color.lerp(c, const Color(0xFF45596E), snow.clamp(0.0, 1.0))!;
    }
    if (rain > 0.01) {
      c = Color.lerp(c, const Color(0xFF1E5C84), rain.clamp(0.0, 1.0))!;
    }
    return c;
  }

  Color _regionColor(WxPoint wx) {
    switch (layer) {
      case WxLayer.precip:
        return _land; // не используется (см. _precipTint)
      case WxLayer.temp:
        return Color.lerp(_land, tempColor(wx.tempC), 0.5)!;
      case WxLayer.wind:
        return Color.lerp(_land, const Color(0xFF3C5A6E),
            (wx.windKmh / 25).clamp(0.0, 1.0))!;
      case WxLayer.pressure:
        final f = ((wx.pressure - 735) / 25).clamp(0.0, 1.0);
        return Color.lerp(
            const Color(0xFF5A3030), const Color(0xFF2E4A5E), f)!;
      case WxLayer.snow:
        return Color.lerp(const Color(0xFF1E2630), const Color(0xFFAFC6D8),
            (wx.snowCm / 12).clamp(0.0, 1.0))!;
    }
  }

  @override
  bool shouldRepaint(covariant _WxRegionPainter old) =>
      old.layer != layer ||
      old.hour != hour ||
      !identical(old.cells, cells) ||
      !identical(old.shapes, shapes);
}

/// Поле осадков-«радар» (как в Яндекс.Картах): мягкие дрейфующие тучи-кляксы,
/// которые рождаются, плывут на восток, усиливаются и затухают, плюс капли/
/// снежинки внутри. Форма органична (не по контуру региона); клип — суша.
class _CloudFieldPainter extends CustomPainter {
  _CloudFieldPainter({
    required this.t,
    required this.cells,
    required this.hour,
    required this.phase,
    required this.snowOnly,
    required this.clip,
  });
  final RussiaMapTransform t;
  final List<WxCell> cells;
  final double hour; // плавно, 0..48
  final double phase; // 0..1, зациклено (для капель)
  final bool snowOnly; // слой «Снег» → только снежные ячейки
  final Path clip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(clip);
    // Сколько пикселей в одном градусе долготы (примерно, по центру РФ).
    final pxPerDeg =
        (t.map(80, 58) - t.map(81, 58)).distance.clamp(2.0, 80.0);
    for (final cell in cells) {
      if (snowOnly && cell.kind != WxKind.snow) continue;
      final inten = cell.intensityAt(hour);
      if (inten <= 0.03) continue;
      final c = t.map(cell.lonAt(hour), cell.latAt(hour));
      final rPx = cell.radiusDeg * pxPerDeg;
      if (rPx < 6) continue;
      final isSnow = cell.kind == WxKind.snow;
      final col = isSnow ? const Color(0xFFCFE0EE) : const Color(0xFF4FA3E0);

      // Органичная форма тучи (не круг): замкнутый контур, модулированный
      // «гармониками» по углу, слегка вытянут и наклонён; мягкая заливка + блюр.
      final fr = math.Random(cell.seed);
      final body = _blobPath(
        c,
        rPx,
        1.15 + fr.nextDouble() * 0.6, // вытянутость
        (fr.nextDouble() - 0.5) * 0.7, // наклон
        0.16 + fr.nextDouble() * 0.18, // амплитуда волны 1
        0.08 + fr.nextDouble() * 0.14, // амплитуда волны 2
        fr.nextDouble() * 6.2832,
        fr.nextDouble() * 6.2832,
        2 + fr.nextInt(2),
        3 + fr.nextInt(3),
      );
      canvas.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.radial(c, rPx * 1.5, [
            col.withValues(alpha: 0.34 * inten),
            col.withValues(alpha: 0.20 * inten),
            col.withValues(alpha: 0),
          ], const [0.0, 0.55, 1.0])
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rPx * 0.16),
      );

      // Капли (дождь) или снежинки внутри тучи.
      final rnd = math.Random(cell.seed);
      final n = (inten * (isSnow ? 14 : 22)).round();
      if (isSnow) {
        final p = Paint()..color = Colors.white.withValues(alpha: 0.8 * inten);
        for (var i = 0; i < n; i++) {
          final ang = rnd.nextDouble() * 6.2832;
          final dr = math.sqrt(rnd.nextDouble()) * rPx * 0.95;
          final bx = c.dx + math.cos(ang) * dr;
          final by = c.dy + math.sin(ang) * dr;
          final sway = math.sin((phase + rnd.nextDouble()) * 6.2832) * 3;
          // Целое число циклов за период анимации → петля без «скачка».
          final fall = ((rnd.nextDouble() + phase) % 1.0) * rPx * 0.6;
          canvas.drawCircle(Offset(bx + sway, by - rPx * 0.3 + fall), 1.5, p);
        }
      } else {
        final p = Paint()
          ..color = const Color(0xFF9BD6FF).withValues(alpha: 0.78 * inten)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < n; i++) {
          final ang = rnd.nextDouble() * 6.2832;
          final dr = math.sqrt(rnd.nextDouble()) * rPx * 0.95;
          final bx = c.dx + math.cos(ang) * dr;
          final by = c.dy + math.sin(ang) * dr;
          // Целое число циклов за период анимации → петля без «скачка».
          final fall = ((rnd.nextDouble() + phase * 2) % 1.0) * rPx * 0.6;
          final y = by - rPx * 0.3 + fall;
          canvas.drawLine(Offset(bx, y), Offset(bx - 1.6, y + 6.5), p);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CloudFieldPainter old) => true;
}

/// Замкнутый «облачный» контур: радиус по углу модулируется двумя синусами
/// (даёт неровные выступы), фигура вытянута [stretch] и наклонена [tilt] —
/// получается органичная, не круглая туча.
Path _blobPath(Offset c, double r, double stretch, double tilt, double a1,
    double a2, double ph1, double ph2, int k1, int k2) {
  final path = Path();
  const steps = 40;
  final ct = math.cos(tilt), st = math.sin(tilt);
  for (var i = 0; i <= steps; i++) {
    final th = i / steps * 6.2832;
    final rad =
        r * (1 + a1 * math.sin(k1 * th + ph1) + a2 * math.sin(k2 * th + ph2));
    final lx = math.cos(th) * rad * stretch;
    final ly = math.sin(th) * rad;
    final px = c.dx + lx * ct - ly * st;
    final py = c.dy + lx * st + ly * ct;
    if (i == 0) {
      path.moveTo(px, py);
    } else {
      path.lineTo(px, py);
    }
  }
  path.close();
  return path;
}
