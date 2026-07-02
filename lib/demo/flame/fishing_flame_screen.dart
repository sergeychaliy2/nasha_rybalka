import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'fishing_flame_game.dart';

/// Экран Flame‑варианта сцены: GameWidget + лёгкий HUD поверх (как и в Canvas,
/// HUD здесь временный — только чтобы прогонять фазы для сравнения).
class FishingFlameScreen extends StatefulWidget {
  const FishingFlameScreen({super.key});

  @override
  State<FishingFlameScreen> createState() => _FishingFlameScreenState();
}

class _FishingFlameScreenState extends State<FishingFlameScreen> {
  late final FishingFlameGame _game;
  FlamePhase _phase = FlamePhase.freeWater;

  @override
  void initState() {
    super.initState();
    _game = FishingFlameGame()
      ..onPhase = (p) {
        if (mounted) setState(() => _phase = p);
      };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _back(),
                  const Spacer(),
                  _pill('Flame'),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_statusText(),
                        style: TextStyle(
                            color: _phase == FlamePhase.bite
                                ? AppColors.danger
                                : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 6)
                            ])),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      _chip('Свободно', FlamePhase.freeWater),
                      _chip('Заброс', FlamePhase.casting),
                      _chip('Поклёвка', FlamePhase.bite),
                      _chip('Вываживание', FlamePhase.fight),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() => switch (_phase) {
        FlamePhase.freeWater => 'Тишина на воде · тапни по воде',
        FlamePhase.casting => 'Заброс…',
        FlamePhase.waiting => 'Ждём поклёвку',
        FlamePhase.bite => 'ПОКЛЁВКА! Тапни — подсечка',
        FlamePhase.fight => 'Вываживание…',
      };

  Widget _back() => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: _pill('‹ Назад'),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _chip(String label, FlamePhase p) => GestureDetector(
        onTap: () => _game.preview(p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      );
}
