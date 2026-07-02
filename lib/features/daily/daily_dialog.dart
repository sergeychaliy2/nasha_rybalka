import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shell/ui_kit.dart';

/// Открывает окно ежедневной награды (лесенка 7 дней).
Future<void> showDailyReward(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const Dialog(
      backgroundColor: Colors.transparent,
      child: _DailyDialog(),
    ),
  );
}

class _DailyDialog extends ConsumerStatefulWidget {
  const _DailyDialog();

  @override
  ConsumerState<_DailyDialog> createState() => _DailyDialogState();
}

class _DailyDialogState extends ConsumerState<_DailyDialog> {
  bool _busy = false;
  DailyClaim? _claimed;

  Future<void> _claim() async {
    setState(() => _busy = true);
    final res = await ref.read(playerControllerProvider.notifier).claimDaily();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _claimed = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider).value;
    if (player == null) return const SizedBox.shrink();
    final available = player.dailyAvailable;
    final currentIndex = (player.dailyNextStreak - 1) % 7; // 0..6

    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: 470,
          maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: SingleChildScrollView(
        child: HeaderPanel(
        header: 'Ежедневная награда',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              available
                  ? 'Заходи каждый день — награда растёт всю неделю.'
                  : 'Сегодня уже получено. Возвращайся завтра!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayCard(
                    day: i + 1,
                    silver: kDailySilverLadder[i],
                    gold: i == 6 ? kDailyGoldDay7 : 0,
                    claimed: available ? i < currentIndex : i <= currentIndex,
                    isToday: available && i == currentIndex,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_claimed != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Получено: +${_claimed!.silver} серебра'
                  '${_claimed!.gold > 0 ? ' · +${_claimed!.gold} золота' : ''}'
                  '  ·  серия ${_claimed!.streak} дн.',
                  style: const TextStyle(
                      color: kGold, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            Row(children: [
              Expanded(
                child: GoldButton(
                  label: available ? 'Забрать награду' : 'Уже получено',
                  icon: Icons.card_giftcard,
                  enabled: available && !_busy,
                  onTap: _claim,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть',
                    style: TextStyle(color: Colors.white60)),
              ),
            ]),
          ],
        ),
      ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.silver,
    required this.gold,
    required this.claimed,
    required this.isToday,
  });

  final int day;
  final int silver;
  final int gold;
  final bool claimed;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final border = isToday
        ? kGold
        : claimed
            ? kGold.withValues(alpha: 0.35)
            : Colors.white12;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? kGold.withValues(alpha: 0.16)
            : Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border, width: isToday ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('День $day',
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 6),
          Icon(
            claimed ? Icons.check_circle : Icons.card_giftcard,
            color: claimed
                ? kGold
                : (isToday ? kGold : Colors.white38),
            size: 22,
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.circle, size: 8, color: kSilver),
            const SizedBox(width: 3),
            Text('$silver',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ]),
          if (gold > 0)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.circle, size: 8, color: kGold),
              const SizedBox(width: 3),
              Text('$gold',
                  style: const TextStyle(color: kGold, fontSize: 11)),
            ]),
        ],
      ),
    );
  }
}
