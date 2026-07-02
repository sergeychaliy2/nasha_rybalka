import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'fishing_scene_screen.dart';
import 'flame/fishing_flame_screen.dart';

/// Временный хаб: открыть сцену ловли в двух рендерах для сравнения.
/// Не финальное меню — только инструмент выбора визуального подхода.
class RenderCompareHome extends StatelessWidget {
  const RenderCompareHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF12161B), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phishing,
                      size: 56, color: AppColors.accent),
                  const SizedBox(height: 12),
                  const Text('Наша Рыбалка',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('Сравнение рендера сцены ловли',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14)),
                  const SizedBox(height: 36),
                  _SceneButton(
                    title: 'Сцена на Canvas',
                    subtitle: 'CustomPainter + пружинная физика',
                    icon: Icons.brush,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FishingSceneScreen())),
                  ),
                  const SizedBox(height: 14),
                  _SceneButton(
                    title: 'Сцена на Flame',
                    subtitle: 'Игровой движок + частицы',
                    icon: Icons.local_fire_department,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FishingFlameScreen())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneButton extends StatelessWidget {
  const _SceneButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
