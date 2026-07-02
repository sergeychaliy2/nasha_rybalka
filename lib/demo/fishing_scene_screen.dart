import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../shared/rendering/spring.dart';
import 'fishing_painter.dart';

/// Фазы рыбалки на локации.
enum Phase { freeWater, casting, waiting, bite, fight, landed }

/// Демо-сцена ловли: фотофон + Canvas-снасть с физикой.
///
/// Управление:
///  • Тап по воде — заброс в точку.
///  • На поклёвке — кнопка «ПОДСЕЧКА» (или тап).
///  • На вываживании — удерживай катушку, держа натяжение в зелёной зоне.
///  • Нижние чипы — мгновенно показать любой эффект для оценки.
class FishingSceneScreen extends StatefulWidget {
  const FishingSceneScreen({super.key});

  @override
  State<FishingSceneScreen> createState() => _FishingSceneScreenState();
}

class _FishingSceneScreenState extends State<FishingSceneScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  final _rnd = math.Random();

  // Физика снасти.
  final Spring _bend = Spring(value: 0.07, stiffness: 70, damping: 8);
  final Spring _floatDip = Spring(value: 0, stiffness: 130, damping: 12);

  // Эффекты воды.
  final List<Ripple> _ripples = [];
  final List<Splash> _splashes = [];
  final List<FishSwirl> _swirls = [];

  Phase _phase = Phase.freeWater;
  Offset _floatN = const Offset(0.42, 0.60);
  Offset _castTarget = const Offset(0.42, 0.60);
  static const _launchN = Offset(0.60, 0.06); // у кончика удилища

  double _castT = 0; // прогресс заброса 0..1
  double _lineTaut = 0;
  double _stateTimer = 0; // отсчёт внутри фазы
  double _biteWindow = 0; // окно на подсечку
  double _nextSwirl = 2;

  // Вываживание.
  double _tension = 0.5; // положение индикатора 0..1
  bool _reeling = false;
  double _fightProgress = 0;
  double _reelAngle = 0;
  double _dangerHold = 0; // сколько держим у красной зоны
  double _slackHold = 0;

  String _caughtName = '';
  double _caughtKg = 0;

  static const _greenLo = 0.40;
  static const _greenHi = 0.76;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _time += dt;

    _bend.update(dt);
    _floatDip.update(dt);
    _advance(dt);
    _stepEffects(dt);

    setState(() {});
  }

  // --- Логика фаз -----------------------------------------------------------

  void _advance(double dt) {
    _stateTimer += dt;

    switch (_phase) {
      case Phase.freeWater:
        _bend.target = 0.06;
        _lineTaut = _approach(_lineTaut, 0, dt, 2);
        _ambientLife(dt);
        break;

      case Phase.casting:
        _castT = (_castT + dt / 0.7).clamp(0.0, 1.0);
        if (_castT < 0.30) {
          // Загрузка назад (замах).
          _bend.target = -0.20;
          _floatN = _launchN;
          _lineTaut = 1;
        } else {
          // Хлёст вперёд и полёт поплавка по дуге в точку.
          _bend.target = 0.34 * (1 - (_castT - 0.3));
          final e = ((_castT - 0.30) / 0.70).clamp(0.0, 1.0);
          final eased = Curves.easeIn.transform(e);
          final arc = math.sin(eased * math.pi) * 0.10;
          _floatN = Offset.lerp(_launchN, _castTarget, eased)! -
              Offset(0, arc);
          _lineTaut = 1;
        }
        if (_castT >= 1) {
          _floatN = _castTarget;
          _splash(_castTarget, 16, 0.20);
          _ring(_castTarget, 64, 1.0);
          _ring(_castTarget, 38, 0.7);
          _bend.target = 0.08;
          _enter(Phase.waiting);
          _biteWindow = 2.2 + _rnd.nextDouble() * 2.6; // до поклёвки
        }
        break;

      case Phase.waiting:
        _bend.target = 0.08;
        _lineTaut = _approach(_lineTaut, 0.25, dt, 2);
        _ambientLife(dt);
        if (_stateTimer >= _biteWindow) _startBite();
        break;

      case Phase.bite:
        _bend.target = 0.26 + math.sin(_time * 8) * 0.04;
        _floatDip.target = 0.9;
        _lineTaut = _approach(_lineTaut, 1, dt, 6);
        // Дёрганье + кольца вокруг поплавка.
        if (_rnd.nextDouble() < dt * 6) _ring(_floatN, 26, 0.7);
        if (_stateTimer >= _biteWindow) _missBite();
        break;

      case Phase.fight:
        _stepFight(dt);
        break;

      case Phase.landed:
        _bend.target = 0.05;
        _floatDip.target = 0;
        break;
    }
  }

  void _ambientLife(double dt) {
    _nextSwirl -= dt;
    if (_nextSwirl <= 0) {
      _nextSwirl = 2.5 + _rnd.nextDouble() * 4;
      final p = Offset(
        0.08 + _rnd.nextDouble() * 0.70,
        0.44 + _rnd.nextDouble() * 0.32,
      );
      _swirls.add(FishSwirl(
        posN: p,
        life: 1.2,
        dir: _rnd.nextBool() ? 1 : -1,
      ));
      _ring(p, 30 + _rnd.nextDouble() * 24, 0.6);
      _splash(p, 4, 0.05);
    }
  }

  void _startBite() {
    HapticFeedback.mediumImpact();
    _floatDip.snapTo(0.2);
    _ring(_floatN, 30, 0.8);
    _enter(Phase.bite);
    _biteWindow = 2.2; // окно на реакцию
  }

  void _missBite() {
    _floatDip.target = 0;
    _ring(_floatN, 40, 0.7);
    _enter(Phase.waiting);
    _biteWindow = 2.5 + _rnd.nextDouble() * 3;
  }

  void _strike() {
    if (_phase != Phase.bite) return;
    HapticFeedback.heavyImpact();
    _bend.impulse(6); // резкий рывок кончика
    _floatDip.snapTo(0);
    _splash(_floatN, 10, 0.12);
    _ring(_floatN, 44, 0.9);
    _tension = 0.55;
    _fightProgress = 0;
    _dangerHold = 0;
    _slackHold = 0;
    _enter(Phase.fight);
  }

  void _stepFight(double dt) {
    // Рывки рыбы — сумма гармоник для «живого» сопротивления.
    final pull = 0.34 +
        0.22 * math.sin(_time * 2.4) +
        0.14 * math.sin(_time * 6.1 + 1);
    final reel = _reeling ? 0.85 : 0.0;
    _tension += (reel - pull) * dt;
    _tension = _tension.clamp(0.0, 1.0);

    // Прогресс копится, пока держим натяжение в зелёной зоне.
    final inGreen = _tension >= _greenLo && _tension <= _greenHi;
    if (inGreen && _reeling) _fightProgress += 0.20 * dt;

    // Реечная анимация катушки.
    if (_reeling) _reelAngle += dt * 11;

    // Изгиб удилища под нагрузкой.
    _bend.target = 0.22 + _tension * 0.5 + pull * 0.18;

    // Опасные зоны: перетяг (обрыв) / слабина (сход).
    if (_tension > 0.95) {
      _dangerHold += dt;
      if (_dangerHold > 1.3) return _breakOff();
    } else {
      _dangerHold = math.max(0, _dangerHold - dt);
    }
    if (_tension < 0.05) {
      _slackHold += dt;
      if (_slackHold > 1.6) return _fishOff();
    } else {
      _slackHold = math.max(0, _slackHold - dt);
    }

    // Поплавок/приманка подтягивается к кончику по мере вываживания.
    _floatN = Offset.lerp(_castTarget, _launchN, _fightProgress * 0.5)!;
    if (_rnd.nextDouble() < dt * 5) {
      _ring(_floatN, 22, 0.5);
    }

    if (_fightProgress >= 1) _land();
  }

  void _breakOff() {
    _bend.impulse(-7);
    _enter(Phase.freeWater);
    _floatN = _launchN;
    _toast('Обрыв! Перетянул леску.');
  }

  void _fishOff() {
    _enter(Phase.freeWater);
    _floatN = _launchN;
    _toast('Сход. Рыба сорвалась.');
  }

  void _land() {
    HapticFeedback.heavyImpact();
    _splash(_floatN, 22, 0.26);
    _ring(_floatN, 80, 1);
    _ring(_floatN, 50, 0.8);
    final fish = _fishTable[_rnd.nextInt(_fishTable.length)];
    _caughtName = fish.$1;
    _caughtKg = fish.$2 + _rnd.nextDouble() * fish.$3;
    _enter(Phase.landed);
  }

  // --- Эффекты --------------------------------------------------------------

  void _stepEffects(double dt) {
    for (final r in _ripples) {
      r.age += dt;
    }
    _ripples.removeWhere((r) => r.isDead);
    for (final s in _swirls) {
      s.age += dt;
    }
    _swirls.removeWhere((s) => s.isDead);

    const gravity = 0.9;
    for (final s in _splashes) {
      s.age += dt;
      s.posN += s.velN * dt;
      s.velN = Offset(s.velN.dx * 0.98, s.velN.dy + gravity * dt);
    }
    _splashes.removeWhere((s) => s.isDead);
  }

  void _ring(Offset posN, double maxR, double strength) {
    _ripples.add(Ripple(posN: posN, maxRadius: maxR, life: 1.4, strength: strength));
  }

  void _splash(Offset posN, int count, double power) {
    for (var i = 0; i < count; i++) {
      final ang = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 1.8;
      final speed = power * (0.4 + _rnd.nextDouble());
      _splashes.add(Splash(
        posN: posN,
        velN: Offset(math.cos(ang), math.sin(ang)) * speed,
        life: 0.5 + _rnd.nextDouble() * 0.4,
        size: 1.4 + _rnd.nextDouble() * 2.2,
      ));
    }
  }

  // --- Действия игрока ------------------------------------------------------

  void _castTo(Offset localN) {
    if (_phase == Phase.fight || _phase == Phase.bite) return;
    // Заброс возможен только в зону воды.
    final t = Offset(
      localN.dx.clamp(0.06, 0.82),
      localN.dy.clamp(0.42, 0.78),
    );
    _castTarget = t;
    _castT = 0;
    _floatDip.snapTo(0);
    _enter(Phase.casting);
    HapticFeedback.selectionClick();
  }

  void _enter(Phase p) {
    _phase = p;
    _stateTimer = 0;
  }

  void _reset() {
    _enter(Phase.freeWater);
    _floatN = _launchN;
    _floatDip.snapTo(0);
    _bend.snapTo(0.06);
  }

  // Чипы предпросмотра — мгновенно показать эффект.
  void _preview(Phase p) {
    switch (p) {
      case Phase.casting:
        _castTo(const Offset(0.40, 0.60));
        break;
      case Phase.bite:
        _floatN = const Offset(0.40, 0.60);
        _floatDip.snapTo(0);
        _enter(Phase.waiting);
        _startBite();
        _biteWindow = 6; // подольше, чтобы рассмотреть
        break;
      case Phase.fight:
        _floatN = const Offset(0.40, 0.58);
        _castTarget = _floatN;
        _strikeForce();
        break;
      default:
        _reset();
    }
  }

  void _strikeForce() {
    _tension = 0.55;
    _fightProgress = 0;
    _dangerHold = 0;
    _slackHold = 0;
    _bend.impulse(6);
    _enter(Phase.fight);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1F25),
      ));
  }

  static const _fishTable = <(String, double, double)>[
    ('Щука', 1.2, 6.0),
    ('Окунь', 0.2, 1.1),
    ('Судак', 0.8, 4.0),
    ('Лещ', 0.4, 2.2),
    ('Карп', 1.5, 7.5),
    ('Сом', 4.0, 18.0),
    ('Форель', 0.6, 3.0),
  ];

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (_phase == Phase.bite) {
                _strike();
              } else {
                _castTo(Offset(
                  d.localPosition.dx / size.width,
                  d.localPosition.dy / size.height,
                ));
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Фотофон локации.
                Image.asset(
                  'assets/locations/misty_pier_dawn.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerLeft,
                ),
                // Лёгкая дымка/виньетка для глубины и читаемости интерфейса.
                const _SceneScrim(),
                // Снасть и эффекты воды.
                CustomPaint(
                  painter: FishingPainter(
                    time: _time,
                    bend: _bend.value,
                    floatPosN: _floatN,
                    floatDip: _floatDip.value,
                    lineTaut: _lineTaut,
                    ripples: _ripples,
                    splashes: _splashes,
                    swirls: _swirls,
                    showRig: _phase != Phase.freeWater,
                  ),
                ),
                _topHud(),
                _bottomHud(),
                if (_phase == Phase.bite) _strikePrompt(),
                if (_phase == Phase.fight) _fightHud(),
                if (_phase == Phase.landed) _catchCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: _glassPill(
                child: const Text('‹ Назад',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            _glassPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.place_outlined, size: 16, color: Color(0xFFE6A23C)),
                  SizedBox(width: 6),
                  Text('Туманный причал',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Spacer(),
            _glassPill(child: _currency(Icons.circle, '1 240', const Color(0xFFC9CDD2))),
            const SizedBox(width: 8),
            _glassPill(child: _currency(Icons.circle, '86', const Color(0xFFE6A23C))),
          ],
        ),
      ),
    );
  }

  Widget _currency(IconData i, String v, Color c) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 12, color: c),
      const SizedBox(width: 6),
      Text(v,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _bottomHud() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 14, right: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Чипы предпросмотра эффектов.
              Wrap(
                spacing: 8,
                children: [
                  _previewChip('Свободно', Phase.freeWater),
                  _previewChip('Заброс', Phase.casting),
                  _previewChip('Поклёвка', Phase.bite),
                  _previewChip('Вываживание', Phase.fight),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _statusLine()),
                  _reelButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLine() {
    final (text, hint) = switch (_phase) {
      Phase.freeWater => ('Тишина на воде', 'Тапни по воде — заброс'),
      Phase.casting => ('Заброс…', ''),
      Phase.waiting => ('Ждём поклёвку', 'Следи за поплавком'),
      Phase.bite => ('ПОКЛЁВКА!', 'Подсекай!'),
      Phase.fight => ('Вываживание', 'Держи зелёную зону'),
      Phase.landed => ('Есть рыба!', ''),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: TextStyle(
                color: _phase == Phase.bite
                    ? const Color(0xFFE5483B)
                    : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
        if (hint.isNotEmpty)
          Text(hint,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
      ],
    );
  }

  /// Круглая катушка: тап — подсечка; удержание на вываживании — подмотка.
  Widget _reelButton() {
    final active = _phase == Phase.fight;
    return GestureDetector(
      onTapDown: (_) {
        if (_phase == Phase.bite) _strike();
        if (active) _reeling = true;
      },
      onTapUp: (_) => _reeling = false,
      onTapCancel: () => _reeling = false,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF2A2F36), Color(0xFF12161B)],
          ),
          border: Border.all(
              color: active
                  ? const Color(0xFFE6A23C)
                  : Colors.white.withValues(alpha: 0.25),
              width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Transform.rotate(
          angle: _reelAngle,
          child: const Icon(Icons.settings, size: 38, color: Color(0xFFC9CDD2)),
        ),
      ),
    );
  }

  Widget _strikePrompt() {
    final pulse = 0.5 + 0.5 * math.sin(_time * 10);
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Opacity(
        opacity: 0.65 + 0.35 * pulse,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE5483B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app, color: Colors.white),
            SizedBox(width: 8),
            Text('ПОДСЕЧКА',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ]),
        ),
      ),
    );
  }

  Widget _fightHud() {
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Шкала натяжения с зелёной зоной.
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 16,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                // Зелёная зона.
                Positioned(
                  left: w * _greenLo,
                  width: w * (_greenHi - _greenLo),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Индикатор натяжения.
                Positioned(
                  left: (w * _tension - 3).clamp(0.0, w - 6),
                  top: -2,
                  bottom: -2,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: _tension > 0.95 || _tension < 0.05
                          ? const Color(0xFFE5483B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, blurRadius: 4)
                      ],
                    ),
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 10),
          // Прогресс вываживания.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _fightProgress,
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFFE6A23C)),
            ),
          ),
          const SizedBox(height: 6),
          Text('Удерживай катушку • не дай уйти в красное',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
        ]),
      ),
    );
  }

  Widget _catchCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF12161B).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6A23C), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, color: Color(0xFFE6A23C), size: 40),
          const SizedBox(height: 10),
          Text(_caughtName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${_caughtKg.toStringAsFixed(2)} кг',
              style: const TextStyle(
                  color: Color(0xFFE6A23C),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _cardButton('Отпустить', Icons.water, false, _reset),
            const SizedBox(width: 12),
            _cardButton('Забрать', Icons.check, true, _reset),
          ]),
        ]),
      ),
    );
  }

  Widget _cardButton(String label, IconData i, bool primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFE6A23C) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: primary ? Colors.transparent : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 18, color: primary ? Colors.black : Colors.white),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  color: primary ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _previewChip(String label, Phase p) {
    return GestureDetector(
      onTap: () => _preview(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _glassPill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }

  double _approach(double v, double target, double dt, double rate) {
    return v + (target - v) * (dt * rate).clamp(0.0, 1.0);
  }
}

/// Дымка/виньетка поверх фото — глубина сцены и читаемость интерфейса.
class _SceneScrim extends StatelessWidget {
  const _SceneScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.30),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45),
            ],
            stops: const [0, 0.22, 0.6, 1],
          ),
        ),
      ),
    );
  }
}
