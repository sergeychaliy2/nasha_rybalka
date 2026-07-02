import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shell/ui_kit.dart';
import 'water_tips.dart';

/// Советы местного рыбака по КОНКРЕТНОМУ водоёму — вкладка в карточке
/// локации на карте. Намёки без прямых пар «вид → наживка».
class LocationTips extends ConsumerWidget {
  const LocationTips({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider).value;
    final tips = kWaterTips[locationId] ?? const [];
    final purchased = player?.purchasedTips ?? const <String>{};
    final bought = tips.where((t) => purchased.contains(t.id)).length;

    if (tips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Местные пока молчат — загляни позже.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFF3B4750), Color(0xFF222A30)]),
              border: Border.all(color: kGold.withValues(alpha: 0.6), width: 2),
            ),
            child: const Icon(Icons.person, color: Color(0xFFCBD2D8), size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Местный рыбак знает этот водоём как свои пять пальцев.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.3),
            ),
          ),
          Text('$bought/${tips.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        for (final t in tips) _TipRow(tip: t, owned: purchased.contains(t.id)),
      ],
    );
  }
}

class _TipRow extends ConsumerWidget {
  const _TipRow({required this.tip, required this.owned});

  final WaterTip tip;
  final bool owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        child: owned
            ? Row(
                key: const ValueKey('owned'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.format_quote, size: 16, color: kGold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              )
            : Container(
                key: const ValueKey('locked'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Совет местного рыбака',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12.5)),
                  ),
                  GoldButton(
                    label: '🪙 ${tip.cost}',
                    onTap: () async {
                      final ok = await ref
                          .read(playerControllerProvider.notifier)
                          .buyTip(tip.id, tip.cost);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(const SnackBar(
                            content: Text('Недостаточно серебра'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(milliseconds: 1300),
                            backgroundColor: Color(0xFF1A1F25),
                          ));
                      }
                    },
                  ),
                ]),
              ),
      ),
    );
  }
}
