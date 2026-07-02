import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/fishing_location.dart';
import '../../domain/entities/gear.dart';
import '../../shared/sound_service.dart';

/// Цветовая схема экрана сонара (классические палитры рыбопоисковых эхолотов).
class _Palette {
  const _Palette(
      this.bg, this.water, this.bottom, this.fish, this.text, this.grid);
  final Color bg;
  final Color water;
  final Color bottom;
  final Color fish;
  final Color text;
  final Color grid;

  static const amber = _Palette(Color(0xFF0A0D07), Color(0xFF15180E),
      Color(0xFF7A521A), Color(0xFFE6A23C), Color(0xFFFFD68A), Color(0x22E6A23C));
  static const blue = _Palette(Color(0xFF05101A), Color(0xFF0B2233),
      Color(0xFF1C4A66), Color(0xFF53C6F2), Color(0xFFBFE6F7), Color(0x224FC3F7));
  static const green = _Palette(Color(0xFF03130C), Color(0xFF0A2417),
      Color(0xFF1E5C39), Color(0xFF2EE6A6), Color(0xFF9CFFD6), Color(0x222EE6A6));
  static const all = [amber, blue, green];
}

/// «Цель» на сонаре — отражение реальной рыбы из пула локации: относительный
/// размер, предпочтительная глубина и обилие (частота появления). Именно эти
/// рыбы и клюют — что видно на эхолоте, то и ловится.
class EchoTarget {
  const EchoTarget({
    required this.sizeFrac,
    required this.depthFrac,
    required this.abundance,
    required this.minKg,
    required this.maxKg,
  });
  final double sizeFrac; // 0..1 относительный размер (для размера иконки)
  final double depthFrac; // 0..1 предпочтительная глубина
  final double abundance; // вес для частоты появления
  final double minKg; // диапазон веса вида — для подписи (weightTag)
  final double maxKg;
}

/// Устройство-эхолот на воде: вызывается кнопкой, показывает «живой» экран
/// сонара (мягкая толща воды, плавное дно, рыба из реального пула локации,
/// заброшенная снасть), настройки под функции модели и выключение с анимацией.
class EchoSounderDevice extends StatefulWidget {
  const EchoSounderDevice({
    super.key,
    required this.echo,
    required this.profile,
    required this.depthMeters,
    required this.fishInZone,
    required this.biteActive,
    required this.castActive,
    required this.rigDepthFrac,
    required this.rigXFrac,
    required this.targets,
    required this.onClose,
  });

  final EchoSounderItem echo;
  final DepthProfile profile;
  final double? depthMeters;
  final int fishInZone;
  final bool biteActive;

  /// Снасть в воде (есть заброс) — иначе крючок не рисуем.
  final bool castActive;

  /// Глубина крючка 0..1 (0 — у поверхности, 1 — у дна) — по слайдеру; при
  /// подтягивании/вываживании уменьшается (крючок ползёт вверх).
  final double rigDepthFrac;

  /// Горизонталь крючка 0..1 — куда заброшено (влево/вправо).
  final double rigXFrac;

  /// Реальные рыбы локации (что видно — то и клюёт).
  final List<EchoTarget> targets;

  final VoidCallback onClose;

  @override
  State<EchoSounderDevice> createState() => _EchoSounderDeviceState();
}

class _EchoSounderDeviceState extends State<EchoSounderDevice>
    with TickerProviderStateMixin {
  // Непрерывное время (секунды) — без зацикливания, поэтому нет «обновления».
  late final Ticker _ticker;
  double _clock = 0;

  late final AnimationController _power = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final AnimationController _boot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  double _gain = 0.6;
  bool _fishId = true;
  bool _weightTag = true;
  bool _zoom = false;
  bool _alarm = false;
  bool _structure = true;
  bool _live = false;
  int _palette = 0;
  int _marks = 0;
  bool _shuttingDown = false;

  // Сигнализатор по весу (топовые эхолоты): диапазон кг и вкл/выкл.
  bool _weightAlarm = false;
  RangeValues _alarmKg = const RangeValues(1, 5);

  /// Мигание кнопки сигнала, когда режим включён и рыба нужного размера в зоне.
  bool get _alarmChipHot {
    if (!_weightAlarm) return false;
    final present = widget.targets.any(
        (tg) => tg.maxKg >= _alarmKg.start && tg.minKg <= _alarmKg.end);
    return present && math.sin(_clock * 7) > 0;
  }

  String _fmtKg(double kg) => kg >= 1
      ? '${kg.toStringAsFixed(kg < 10 ? 1 : 0)}кг'
      : '${(kg * 1000).round()}г';

  @override
  void initState() {
    super.initState();
    _palette = widget.echo.rangeMeters % _Palette.all.length;
    SoundService.sonarBeep(); // писк включения
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() => _clock = elapsed.inMicroseconds / 1e6);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _power.dispose();
    _boot.dispose();
    super.dispose();
  }

  void _powerOff() {
    if (_shuttingDown) return;
    setState(() => _shuttingDown = true);
    HapticFeedback.heavyImpact();
    SoundService.sonarBeep(); // писк выключения
    _power.forward().whenComplete(widget.onClose);
  }

  double get _tempC {
    final base = 9 + (widget.echo.id.hashCode % 12);
    return base + (widget.castActive ? 0 : 4);
  }

  bool _can(SounderCapability c) => widget.echo.can(c);

  @override
  Widget build(BuildContext context) {
    final pal = _Palette.all[_palette];
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF20262D), Color(0xFF10141A)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF3A444E)),
          boxShadow: [
            const BoxShadow(
                color: Colors.black87, blurRadius: 24, offset: Offset(0, 12)),
            BoxShadow(color: pal.fish.withValues(alpha: 0.18), blurRadius: 22),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(pal),
            const SizedBox(height: 9),
            _screen(pal),
            const SizedBox(height: 10),
            _controls(pal),
          ],
        ),
      ),
    );
  }

  Widget _header(_Palette pal) {
    final on = !_shuttingDown || (_power.value * 8).floor().isEven;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? const Color(0xFF4CE0A0) : const Color(0xFF20302A),
            boxShadow: on
                ? [const BoxShadow(color: Color(0xFF4CE0A0), blurRadius: 7)]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.echo.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        GestureDetector(
          onTap: _powerOff,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A1416),
              border: Border.all(color: const Color(0xFFE5483B)),
            ),
            child: const Icon(Icons.power_settings_new,
                size: 16, color: Color(0xFFE5483B)),
          ),
        ),
      ],
    );
  }

  Widget _screen(_Palette pal) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SonarPainter(
                t: _clock,
                boot: Curves.easeOut.transform(_boot.value),
                power: _power.value,
                pal: pal,
                profile: widget.profile,
                targets: widget.targets,
                gain: _gain,
                showFish: _can(SounderCapability.fishArches),
                fishId: _fishId && _can(SounderCapability.fishIdHint),
                weightTag: _weightTag && _can(SounderCapability.weightTag),
                showStructure:
                    _structure && _can(SounderCapability.structureScan),
                showBottom: _can(SounderCapability.bottomProfile),
                thermo: _can(SounderCapability.thermocline),
                zoom: _zoom && _can(SounderCapability.zoom),
                live: _live && _can(SounderCapability.liveScope),
                depthMeters: widget.depthMeters,
                rangeMeters: widget.echo.rangeMeters.toDouble(),
                tempC: _can(SounderCapability.temperature) ? _tempC : null,
                bite:
                    widget.biteActive && _can(SounderCapability.biteIndicator),
                castActive: widget.castActive,
                rigDepthFrac: widget.rigDepthFrac,
                rigXFrac: widget.rigXFrac,
                weightAlarm:
                    _weightAlarm && _can(SounderCapability.weightAlarm),
                alarmMin: _alarmKg.start,
                alarmMax: _alarmKg.end,
              ),
            ),
            if (_can(SounderCapability.fishArches))
              Positioned(
                left: 8,
                top: 6,
                child: Opacity(
                  opacity: (1 - _power.value).clamp(0.0, 1.0),
                  child: Text(
                    'Рыба в зоне: ${widget.fishInZone}',
                    style: TextStyle(
                      color: pal.text.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controls(_Palette pal) {
    final chips = <Widget>[
      _GainControl(
          value: _gain,
          color: pal.fish,
          onChanged: (v) => setState(() => _gain = v)),
    ];
    if (_can(SounderCapability.fishIdHint)) {
      chips.add(_toggle('Размер', Icons.straighten, _fishId, pal.fish,
          () => setState(() => _fishId = !_fishId)));
    }
    if (_can(SounderCapability.weightTag)) {
      chips.add(_toggle('Вес', Icons.scale, _weightTag, pal.fish,
          () => setState(() => _weightTag = !_weightTag)));
    }
    if (_can(SounderCapability.zoom)) {
      chips.add(_toggle('Зум дна', Icons.zoom_in, _zoom, pal.fish,
          () => setState(() => _zoom = !_zoom)));
    }
    if (_can(SounderCapability.structureScan)) {
      chips.add(_toggle('Структура', Icons.grain, _structure, pal.fish,
          () => setState(() => _structure = !_structure)));
    }
    if (_can(SounderCapability.depthAlarm)) {
      chips.add(_toggle('Сигнал', Icons.notifications_active, _alarm, pal.fish,
          () => setState(() => _alarm = !_alarm)));
    }
    if (_can(SounderCapability.weightAlarm)) {
      chips.add(_toggle(
          'Вес-сигнал',
          Icons.monitor_weight,
          _weightAlarm,
          _alarmChipHot ? const Color(0xFFFF6A5A) : pal.fish,
          () => setState(() => _weightAlarm = !_weightAlarm)));
    }
    if (_can(SounderCapability.liveScope)) {
      chips.add(_toggle('LIVE', Icons.sensors, _live, pal.fish,
          () => setState(() => _live = !_live)));
    }
    if (_can(SounderCapability.gpsMarks)) {
      chips.add(_button('Метка${_marks > 0 ? ' ·$_marks' : ''}', Icons.push_pin,
          pal.fish, () => setState(() => _marks++)));
    }
    chips.add(_button('Цвет', Icons.palette, pal.fish,
        () => setState(() => _palette = (_palette + 1) % _Palette.all.length)));
    final wrap = Wrap(spacing: 7, runSpacing: 7, children: chips);
    if (_weightAlarm && _can(SounderCapability.weightAlarm)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [wrap, const SizedBox(height: 8), _alarmRange(pal)],
      );
    }
    return wrap;
  }

  /// Диапазон веса, с которого сигналить (для эхолотов с weightAlarm).
  Widget _alarmRange(_Palette pal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Icon(Icons.scale, size: 13, color: pal.fish),
        const SizedBox(width: 6),
        Text(_fmtKg(_alarmKg.start),
            style: TextStyle(
                color: pal.fish, fontSize: 10, fontWeight: FontWeight.w800)),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: pal.fish,
              inactiveTrackColor: Colors.white24,
              thumbColor: pal.fish,
              overlayShape: SliderComponentShape.noOverlay,
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: RangeSlider(
              values: _alarmKg,
              max: 25,
              onChanged: (v) => setState(() => _alarmKg = v),
            ),
          ),
        ),
        Text(_fmtKg(_alarmKg.end),
            style: TextStyle(
                color: pal.fish, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _toggle(String label, IconData icon, bool on, Color accent,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.18) : Colors.black26,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: on ? accent : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: on ? accent : Colors.white54),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: on ? accent : Colors.white60,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _button(String label, IconData icon, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _GainControl extends StatelessWidget {
  const _GainControl(
      {required this.value, required this.color, required this.onChanged});
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Icon(Icons.tune, size: 13, color: color),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: Colors.white24,
              thumbColor: color,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
      ]),
    );
  }
}

class _SonarPainter extends CustomPainter {
  _SonarPainter({
    required this.t,
    required this.boot,
    required this.power,
    required this.pal,
    required this.profile,
    required this.targets,
    required this.gain,
    required this.showFish,
    required this.fishId,
    required this.weightTag,
    required this.showStructure,
    required this.showBottom,
    required this.thermo,
    required this.zoom,
    required this.live,
    required this.depthMeters,
    required this.rangeMeters,
    required this.tempC,
    required this.bite,
    required this.castActive,
    required this.rigDepthFrac,
    required this.rigXFrac,
    required this.weightAlarm,
    required this.alarmMin,
    required this.alarmMax,
  });

  final double t; // непрерывное время в секундах
  final double boot;
  final double power;
  final _Palette pal;
  final DepthProfile profile;
  final List<EchoTarget> targets;
  final double gain;
  final bool showFish;
  final bool fishId;
  final bool weightTag;
  final bool showStructure;
  final bool showBottom;
  final bool thermo;
  final bool zoom;
  final bool live;
  final double? depthMeters;
  final double rangeMeters;
  final double? tempC;
  final bool bite;
  final bool castActive;
  final double rigDepthFrac;
  final double rigXFrac;
  final bool weightAlarm;
  final double alarmMin;
  final double alarmMax;

  EchoTarget _pick(List<EchoTarget> ts, double r) {
    final total = ts.fold(0.0, (s, e) => s + e.abundance);
    var acc = r * (total <= 0 ? ts.length.toDouble() : total);
    for (final e in ts) {
      acc -= total <= 0 ? 1.0 : e.abundance;
      if (acc <= 0) return e;
    }
    return ts.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = pal.bg);

    if (power > 0) {
      final collapse = Curves.easeInCubic.transform(power);
      canvas.save();
      canvas.translate(0, h / 2);
      canvas.scale(1, (1 - collapse).clamp(0.0, 1.0));
      canvas.translate(0, -h / 2);
    }

    // Сигнал по весу — накапливаем попадание за кадр (для маячка).
    var alarmHit = false;
    var alarmKgHit = 0.0;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, h * boot));

    // Толща воды — мягкий вертикальный градиент.
    final waterTop = Color.lerp(pal.water, pal.fish, 0.16)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [waterTop, pal.bg],
        ).createShader(rect),
    );

    // Мягкое свечение и блики у поверхности.
    final surfRect = Rect.fromLTWH(0, 0, w, h * 0.24);
    canvas.drawRect(
      surfRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pal.text.withValues(alpha: 0.12), Colors.transparent],
        ).createShader(surfRect),
    );
    final shimmer = Paint()
      ..color = pal.text.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 6.0 + i * 5 + math.sin(t * 0.7 + i) * 1.5;
      canvas.drawLine(Offset(0, y), Offset(w, y), shimmer);
    }

    // Мягкие подписи глубины.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final depthSpan = zoom ? rangeMeters * 0.5 : rangeMeters;
    for (var i = 1; i <= 3; i++) {
      final y = h * i / 4;
      tp.text = TextSpan(
          text: '${(depthSpan * i / 4).toStringAsFixed(0)} м',
          style:
              TextStyle(color: pal.text.withValues(alpha: 0.3), fontSize: 8));
      tp.layout();
      tp.paint(canvas, Offset(4, y - tp.height - 1));
    }

    // Плавное дно: средний уровень — по глубине водоёма, форма — пологие
    // холмы из суммы синусов; лента медленно и непрерывно «уезжает» вбок.
    final depthRel = (profile.maxDepthMeters / 30).clamp(0.0, 1.0);
    final baseFrac = zoom ? 0.5 : 0.72 + 0.12 * depthRel;
    double bottomFracAt(double xN) {
      final wave = 0.05 * math.sin((xN * 1.8 + t * 0.05) * 2 * math.pi) +
          0.025 * math.sin((xN * 3.6 + t * 0.10) * 2 * math.pi + 1.3);
      return (baseFrac + wave).clamp(0.5, 0.94);
    }

    // Термоклин — мягкая размытая полоса.
    if (thermo) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * 0.44, w, h * 0.08),
        Paint()
          ..color = pal.text.withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Мягкое дно снизу.
    if (showBottom) {
      const steps = 40;
      Offset bp(int i) => Offset(w * i / steps, h * bottomFracAt(i / steps));
      final fill = Path()..moveTo(0, h);
      for (var i = 0; i <= steps; i++) {
        final p = bp(i);
        fill.lineTo(p.dx, p.dy);
      }
      fill
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pal.bottom.withValues(alpha: 0.6), pal.bottom],
          ).createShader(rect),
      );
      final edge = Path();
      for (var i = 0; i <= steps; i++) {
        final p = bp(i);
        if (i == 0) {
          edge.moveTo(p.dx, p.dy);
        } else {
          edge.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = pal.bottom.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color =
              Color.lerp(pal.bottom, pal.text, 0.45)!.withValues(alpha: 0.5),
      );
      // Структура — несколько мягких холмиков, плавно дрейфующих по дну.
      if (showStructure) {
        for (var i = 0; i < 4; i++) {
          final ph = t * 0.04 + i * 0.27;
          final fx = 1.0 - (ph - ph.floor());
          final by = h * bottomFracAt(fx);
          canvas.drawCircle(
            Offset(w * fx, by),
            5 + (i % 3) * 2,
            Paint()
              ..color = pal.bottom.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }

    // Лёгкая мягкая дымка по чувствительности.
    if (gain > 0.05) {
      canvas.drawRect(rect, Paint()..color = pal.fish.withValues(alpha: gain * 0.05));
    }

    // Рыба — реальные виды из пула локации. Плывут в обе стороны, иногда
    // разворачиваются; нос ВСЕГДА по ходу движения (не хвостом вперёд).
    if (showFish && targets.isNotEmpty) {
      const lanes = 7;
      for (var i = 0; i < lanes; i++) {
        final speed = (0.035 + i * 0.003) * (live ? 1.7 : 1.0);
        final phase = t * speed + i * 0.137;
        final inc = phase.floor();
        final p = phase - inc; // 0..1 прогресс прохода
        final rng = math.Random(i * 7919 + inc * 104729);
        final tgt = _pick(targets, rng.nextDouble());
        final goRight = rng.nextBool(); // направление прохода
        final turns = rng.nextDouble() < 0.28; // иногда разворот

        // Позиция [fx] и направление носа [face] (нос по ходу движения).
        double fx;
        double face; // +1 — нос вправо, -1 — нос влево
        if (turns) {
          final tri = p < 0.5 ? p * 2 : (1 - p) * 2; // 0→1→0
          if (goRight) {
            fx = tri * 0.6; // входит слева, доходит до середины, назад
            face = p < 0.5 ? 1.0 : -1.0;
          } else {
            fx = 1 - tri * 0.6; // входит справа, до середины, назад
            face = p < 0.5 ? -1.0 : 1.0;
          }
        } else {
          fx = goRight ? p : (1 - p);
          face = goRight ? 1.0 : -1.0;
        }

        final df =
            (tgt.depthFrac + (rng.nextDouble() - 0.5) * 0.12).clamp(0.1, 0.95);
        final by = h * (showBottom ? bottomFracAt(fx) : 0.92);
        const tm = 0.16;
        final x = w * fx;
        final y = h * tm +
            df * (by - h * tm - h * 0.06) +
            math.sin(t * 0.7 + i) * 2.2;
        final len = fishId ? (9 + tgt.sizeFrac * 16) : 12.0;
        final dir = face;

        // Оценка веса — для подписи и для сигнала по весу (скос к мелкому).
        final ww = math.pow(rng.nextDouble(), 2.0).toDouble();
        final kg = tgt.minKg + (tgt.maxKg - tgt.minKg) * ww;
        final inRange = weightAlarm && kg >= alarmMin && kg <= alarmMax;
        if (inRange) {
          alarmHit = true;
          alarmKgHit = kg;
        }

        final fp = Paint()
          ..color = pal.fish.withValues(alpha: inRange ? 0.92 : 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
        final body = Path()
          ..moveTo(x + dir * len * 0.5, y)
          ..quadraticBezierTo(x, y - len * 0.26, x - dir * len * 0.5, y)
          ..quadraticBezierTo(x, y + len * 0.26, x + dir * len * 0.5, y)
          ..close();
        final tail = Path()
          ..moveTo(x - dir * len * 0.5, y)
          ..lineTo(x - dir * len * 0.74, y - len * 0.17)
          ..lineTo(x - dir * len * 0.74, y + len * 0.17)
          ..close();
        canvas.drawPath(body, fp);
        canvas.drawPath(tail, fp);

        // «Нужная» рыба (по весу-сигналу) — пульсирующее золотое кольцо.
        if (inRange) {
          final pulse = 0.5 + 0.5 * math.sin(t * 6);
          canvas.drawCircle(
            Offset(x, y),
            len * 0.8 + 2 + pulse * 2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = const Color(0xFFFFC23C)
                  .withValues(alpha: 0.45 + pulse * 0.4),
          );
        }

        // Подпись приблизительного веса (только модели с weightTag).
        if (weightTag) {
          final label = kg >= 1
              ? '${kg.toStringAsFixed(1)} кг'
              : '${(kg * 1000).round()} г';
          final wtp = TextPainter(
            text: TextSpan(
                text: label,
                style: TextStyle(
                    color: pal.text.withValues(alpha: 0.75),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700)),
            textDirection: TextDirection.ltr,
          )..layout();
          wtp.paint(canvas, Offset(x - wtp.width / 2, y + len * 0.45));
        }
      }
    }

    // Заброшенная снасть: поплавок, леска вниз и крючок. Только при забросе;
    // глубина крючка — по слайдеру (выше при подтягивании), X — куда заброшено.
    if (castActive) {
      final rigXN = rigXFrac.clamp(0.08, 0.92).toDouble();
      final rigX = w * rigXN;
      final by = h * bottomFracAt(rigXN);
      const surfaceY = 4.0;
      final hookY = (surfaceY + rigDepthFrac.clamp(0.0, 1.0) * (by - surfaceY))
          .clamp(surfaceY + 8, by - 4)
          .toDouble();
      canvas.drawLine(
        Offset(rigX, surfaceY),
        Offset(rigX, hookY),
        Paint()
          ..color = pal.text.withValues(alpha: 0.65)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(rigX, surfaceY + 2), 2.6,
          Paint()..color = const Color(0xFFE5483B));
      canvas.drawCircle(Offset(rigX, hookY), 2.4, Paint()..color = pal.text);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(rigX, hookY + 3), width: 5, height: 6),
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = pal.text,
      );
    }

    canvas.restore(); // boot clip

    // Большое число глубины в точке заброса (только когда заброшено).
    if (depthMeters != null && castActive) {
      final dtp = TextPainter(
        text: TextSpan(
          text: '${depthMeters!.toStringAsFixed(1)} м',
          style: TextStyle(
              color: pal.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dtp.paint(canvas, Offset(10, h - dtp.height - 8));
    }

    if (tempC != null) {
      final ttp = TextPainter(
        text: TextSpan(
          text: '${tempC!.toStringAsFixed(1)}°',
          style: TextStyle(
              color: pal.text.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ttp.paint(canvas, Offset(w - ttp.width - 14, h - ttp.height - 6));
    }

    if (bite) {
      final btp = TextPainter(
        text: const TextSpan(
          text: '● ЖОР',
          style: TextStyle(
              color: Color(0xFFE5483B),
              fontSize: 11,
              fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      btp.paint(canvas, Offset(w - btp.width - 10, 6));
    }

    // Маячок сигнала по весу: армирован — тусклая точка сверху по центру;
    // при проходе рыбы нужного веса — ярко мигает и подписывает вес.
    if (weightAlarm) {
      final blink = 0.5 + 0.5 * math.sin(t * 8);
      final bx = w / 2;
      const byy = 10.0;
      const base = Color(0xFFFF5A48);
      canvas.drawCircle(
        Offset(bx, byy),
        alarmHit ? 5 + blink * 3 : 3,
        Paint()
          ..color =
              base.withValues(alpha: alarmHit ? 0.3 + blink * 0.5 : 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
          Offset(bx, byy),
          alarmHit ? 3 : 2,
          Paint()
            ..color = base.withValues(
                alpha: alarmHit ? 0.6 + blink * 0.4 : 0.35));
      if (alarmHit) {
        final atp = TextPainter(
          text: TextSpan(
            text: alarmKgHit >= 1
                ? '${alarmKgHit.toStringAsFixed(1)} кг'
                : '${(alarmKgHit * 1000).round()} г',
            style: TextStyle(
                color: const Color(0xFFFFC7BD)
                    .withValues(alpha: 0.75 + blink * 0.25),
                fontSize: 9,
                fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        atp.paint(canvas, Offset(bx + 9, byy - atp.height / 2));
      }
    }

    if (power > 0) {
      canvas.restore(); // collapse
      final flash = (1 - (power - 0.5).abs() * 2).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(0, h / 2 - 1, w, 2),
          Paint()..color = pal.text.withValues(alpha: flash));
      canvas.drawRect(
          rect, Paint()..color = Colors.black.withValues(alpha: power * 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant _SonarPainter old) => true;
}
