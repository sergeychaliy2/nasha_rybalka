import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../shared/rendering/rod_geometry.dart';
import '../../shared/rendering/spring.dart';

enum FlamePhase { freeWater, casting, waiting, bite, fight }

/// Flame‑вариант сцены ловли (для сравнения с Canvas‑вариантом).
///
/// Та же снасть/леска/поплавок (общий модуль [rod_geometry]); всплески —
/// через систему частиц Flame, рябь — отдельными компонентами.
class FishingFlameGame extends FlameGame with TapCallbacks {
  final Spring bend = Spring(value: 0.07, stiffness: 70, damping: 8);
  final Spring floatDip = Spring(value: 0, stiffness: 130, damping: 12);
  final math.Random rnd = math.Random();

  double time = 0;
  double stateTimer = 0;
  double castT = 0;
  double lineTaut = 0;
  double biteWindow = 3;
  double nextSwirl = 2;
  double fightTimer = 0;

  FlamePhase phase = FlamePhase.freeWater;

  Vector2 floatPos = Vector2.zero();
  Vector2 castTarget = Vector2.zero();
  Vector2 launch = Vector2.zero();

  /// Колбэк смены фазы — для обновления HUD во Flutter‑оверлее.
  void Function(FlamePhase)? onPhase;

  late final SpriteComponent _bg;
  late final _RigComponent _rig;
  bool _ready = false;

  @override
  Future<void> onLoad() async {
    // Грузим фон напрямую через rootBundle (без зависимости от префикса Flame).
    final bytes = await rootBundle.load('assets/locations/misty_pier_dawn.png');
    final image = await decodeImageFromList(bytes.buffer.asUint8List());
    _bg = SpriteComponent(sprite: Sprite(image), anchor: Anchor.center)
      ..priority = -10;
    add(_bg);
    _rig = _RigComponent()..priority = 10;
    add(_rig);
    _ready = true;
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ready) _layout();
  }

  void _layout() {
    final img = _bg.sprite!.srcSize;
    final scale = math.max(size.x / img.x, size.y / img.y);
    _bg.size = img * scale;
    _bg.position = size / 2;
    launch = Vector2(size.x * 0.60, size.y * 0.06);
    if (floatPos == Vector2.zero()) {
      floatPos = Vector2(size.x * 0.42, size.y * 0.60);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
    stateTimer += dt;
    bend.update(dt);
    floatDip.update(dt);
    _advance(dt);
  }

  void _setPhase(FlamePhase p) {
    phase = p;
    stateTimer = 0;
    onPhase?.call(p);
  }

  void _advance(double dt) {
    switch (phase) {
      case FlamePhase.freeWater:
        bend.target = 0.06;
        lineTaut = _approach(lineTaut, 0, dt, 2);
        _ambient(dt);
        break;
      case FlamePhase.casting:
        castT = (castT + dt / 0.7).clamp(0.0, 1.0);
        if (castT < 0.30) {
          bend.target = -0.20;
          floatPos = launch.clone();
          lineTaut = 1;
        } else {
          bend.target = 0.34 * (1 - (castT - 0.3));
          final e = ((castT - 0.30) / 0.70).clamp(0.0, 1.0);
          final eased = Curves.easeIn.transform(e);
          final arc = math.sin(eased * math.pi) * size.y * 0.10;
          floatPos = launch + (castTarget - launch) * eased - Vector2(0, arc);
          lineTaut = 1;
        }
        if (castT >= 1) {
          floatPos = castTarget.clone();
          _spawnSplash(castTarget, 16);
          _spawnRipple(castTarget, 64, 1);
          _spawnRipple(castTarget, 38, 0.7);
          bend.target = 0.08;
          _setPhase(FlamePhase.waiting);
          biteWindow = 2.2 + rnd.nextDouble() * 2.6;
        }
        break;
      case FlamePhase.waiting:
        bend.target = 0.08;
        lineTaut = _approach(lineTaut, 0.25, dt, 2);
        _ambient(dt);
        if (stateTimer >= biteWindow) _startBite();
        break;
      case FlamePhase.bite:
        bend.target = 0.26 + math.sin(time * 8) * 0.04;
        floatDip.target = 0.9;
        lineTaut = _approach(lineTaut, 1, dt, 6);
        if (rnd.nextDouble() < dt * 6) _spawnRipple(floatPos, 26, 0.7);
        if (stateTimer >= biteWindow) {
          floatDip.target = 0;
          _spawnRipple(floatPos, 40, 0.7);
          _setPhase(FlamePhase.waiting);
          biteWindow = 2.5 + rnd.nextDouble() * 3;
        }
        break;
      case FlamePhase.fight:
        // Упрощённое вываживание (для сравнения рендера): рывки + авто‑победа.
        final pull = 0.34 + 0.22 * math.sin(time * 2.4) + 0.14 * math.sin(time * 6.1);
        bend.target = 0.30 + pull * 0.4;
        fightTimer -= dt;
        if (rnd.nextDouble() < dt * 5) _spawnRipple(floatPos, 22, 0.5);
        if (fightTimer <= 0) {
          _spawnSplash(floatPos, 22);
          _spawnRipple(floatPos, 80, 1);
          _setPhase(FlamePhase.freeWater);
          floatPos = launch.clone();
        }
        break;
    }
  }

  void _ambient(double dt) {
    nextSwirl -= dt;
    if (nextSwirl <= 0) {
      nextSwirl = 2.5 + rnd.nextDouble() * 4;
      final p = Vector2(
        size.x * (0.08 + rnd.nextDouble() * 0.70),
        size.y * (0.44 + rnd.nextDouble() * 0.32),
      );
      _spawnRipple(p, 30 + rnd.nextDouble() * 24, 0.6);
      _spawnSplash(p, 4);
    }
  }

  void cast(Vector2 target) {
    if (phase == FlamePhase.fight || phase == FlamePhase.bite) return;
    castTarget = Vector2(
      target.x.clamp(size.x * 0.06, size.x * 0.82),
      target.y.clamp(size.y * 0.42, size.y * 0.78),
    );
    castT = 0;
    floatDip.snapTo(0);
    _setPhase(FlamePhase.casting);
  }

  void strike() {
    if (phase != FlamePhase.bite) return;
    bend.impulse(6);
    floatDip.snapTo(0);
    _spawnSplash(floatPos, 10);
    _spawnRipple(floatPos, 44, 0.9);
    fightTimer = 2.6;
    _setPhase(FlamePhase.fight);
  }

  // --- Эффекты (частицы Flame + компоненты ряби) ---------------------------

  void _spawnSplash(Vector2 pos, int count) {
    add(
      ParticleSystemComponent(
        position: pos.clone(),
        priority: 20,
        particle: Particle.generate(
          count: count,
          generator: (i) {
            final ang = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 1.7;
            final speed = 70 + rnd.nextDouble() * 150;
            return AcceleratedParticle(
              acceleration: Vector2(0, 320),
              speed: Vector2(math.cos(ang), math.sin(ang)) * speed,
              lifespan: 0.5 + rnd.nextDouble() * 0.4,
              child: CircleParticle(
                radius: 1.4 + rnd.nextDouble() * 2.2,
                paint: Paint()..color = Colors.white.withValues(alpha: 0.85),
              ),
            );
          },
        ),
      ),
    );
  }

  void _spawnRipple(Vector2 pos, double maxR, double strength) {
    add(_RippleComponent(pos.clone(), maxR, strength)..priority = 0);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition;
    if (phase == FlamePhase.bite) {
      strike();
    } else {
      cast(p);
    }
  }

  double _approach(double v, double target, double dt, double rate) =>
      v + (target - v) * (dt * rate).clamp(0.0, 1.0);

  void _startBite() {
    floatDip.snapTo(0.2);
    _spawnRipple(floatPos, 30, 0.8);
    _setPhase(FlamePhase.bite);
    biteWindow = 2.2;
  }

  /// Триггеры предпросмотра из HUD.
  void preview(FlamePhase p) {
    switch (p) {
      case FlamePhase.casting:
        cast(Vector2(size.x * 0.40, size.y * 0.60));
        break;
      case FlamePhase.bite:
        floatPos = Vector2(size.x * 0.40, size.y * 0.60);
        floatDip.snapTo(0);
        _startBite();
        biteWindow = 6;
        break;
      case FlamePhase.fight:
        floatPos = Vector2(size.x * 0.40, size.y * 0.58);
        bend.impulse(6);
        fightTimer = 4;
        _setPhase(FlamePhase.fight);
        break;
      default:
        _setPhase(FlamePhase.freeWater);
        floatPos = launch.clone();
        floatDip.snapTo(0);
    }
  }
}

/// Снасть: рисует удилище/леску/поплавок через общий модуль [rod_geometry].
class _RigComponent extends Component with HasGameReference<FishingFlameGame> {
  @override
  void render(Canvas canvas) {
    final g = game;
    if (g.phase == FlamePhase.freeWater) return;

    final geo = computeRod(
      Size(g.size.x, g.size.y),
      g.bend.value,
      g.time,
    );
    final dip = g.floatDip.value;
    final bob = math.sin(g.time * 2.1) * 2.4 * (1 - dip);
    final floatPx = Offset(g.floatPos.x, g.floatPos.y + bob + dip * 26);

    paintLine(canvas, geo.tip, floatPx, g.lineTaut);
    paintFloat(canvas, floatPx, dip);
    paintRod(canvas, geo);
  }
}

/// Кольцо ряби как Flame‑компонент (растёт и затухает, сам себя удаляет).
class _RippleComponent extends Component {
  _RippleComponent(this.pos, this.maxR, this.strength);

  final Vector2 pos;
  final double maxR;
  final double strength;
  double age = 0;
  static const life = 1.4;

  @override
  void update(double dt) {
    age += dt;
    if (age >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (age / life).clamp(0.0, 1.0);
    final r = maxR * Curves.easeOut.transform(t);
    final alpha = (1 - t) * 0.5 * strength;
    if (alpha <= 0.01) return;
    canvas.save();
    canvas.translate(pos.x, pos.y);
    canvas.scale(1, 0.34);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(2.2, 0.5, t)
        ..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
