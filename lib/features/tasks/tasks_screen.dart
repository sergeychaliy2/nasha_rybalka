import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../achievements/achievements_tab.dart';
import '../shell/ui_kit.dart';
import 'daily_tasks.dart';

/// Экран «Задания»: вкладки «Поручения» (ежедневные, с наградами) и «Цели»
/// (постоянные достижения).
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _tabBtn('ПОРУЧЕНИЯ', 0),
            _tabBtn('ЦЕЛИ', 1),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _tab == 0 ? const _DailyTasks() : const AchievementsTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: active ? kGold : Colors.white12, width: 2),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? kGold : Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyTasks extends ConsumerWidget {
  const _DailyTasks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider).value;
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final isToday = player.dailyTaskDate == taskDayKey(DateTime.now());
    final tasks = dailyTasksFor(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Обновляются каждый день. Лови, выполняй — и забирай награду.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        for (final t in tasks) ...[
          _TaskRow(
            task: t,
            progress: isToday ? (player.dailyProgress[t.metric] ?? 0) : 0,
            claimed: player.dailyClaimed.contains(t.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Иконка + цвет по метрике задания/цели (наглядно, что делать).
(IconData, Color) metricIcon(String metric) => switch (metric) {
      'catch' => (Icons.phishing, const Color(0xFF5AA9E6)),
      'release' => (Icons.waves, const Color(0xFF54C9C9)),
      'keep' => (Icons.inventory_2, const Color(0xFFD9A441)),
      'weight' => (Icons.monitor_weight, kGold),
      'big' => (Icons.straighten, const Color(0xFF6FBF73)),
      'trophy' => (Icons.emoji_events, const Color(0xFFB98CFF)),
      'spend' => (Icons.shopping_cart, const Color(0xFFE0864A)),
      'species' => (Icons.menu_book, const Color(0xFF7FB3D5)),
      'level' => (Icons.military_tech, const Color(0xFFE0C24A)),
      'total' => (Icons.scale, const Color(0xFF7FD4A3)),
      _ => (Icons.flag, kGold),
    };

/// Круглый значок задания с иконкой-подсказкой по метрике.
class MetricBadge extends StatelessWidget {
  const MetricBadge(this.metric, {super.key, this.done = false, this.size = 46});

  final String metric;
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, col) = metricIcon(metric);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          col.withValues(alpha: done ? 0.42 : 0.26),
          col.withValues(alpha: 0.07),
        ]),
        border: Border.all(color: col.withValues(alpha: 0.6), width: 1.4),
      ),
      child: Icon(icon, color: col, size: size * 0.5),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({
    required this.task,
    required this.progress,
    required this.claimed,
  });

  final DailyTask task;
  final int progress;
  final bool claimed;

  String _fmt(int v) =>
      task.metric == 'weight' ? (v / 1000).toStringAsFixed(1) : '$v';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = progress.clamp(0, task.target);
    final done = progress >= task.target;
    final frac = task.target == 0 ? 0.0 : cur / task.target;

    return GamePanel(
      child: Row(
        children: [
          MetricBadge(task.metric, done: done),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.circle, size: 12, color: kSilver),
                  const SizedBox(width: 5),
                  Text('${task.silver}',
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w700)),
                  if (task.gold > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.circle, size: 12, color: kGold),
                    const SizedBox(width: 5),
                    Text('${task.gold}',
                        style: const TextStyle(
                            color: kGold, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (claimed)
            const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, color: kGold, size: 30),
              SizedBox(height: 2),
              Text('Получено',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ])
          else if (done)
            GoldButton(
              label: 'Забрать',
              icon: Icons.card_giftcard,
              onTap: () async {
                final ok = await ref
                    .read(playerControllerProvider.notifier)
                    .claimDailyTask(
                        task.id, task.metric, task.target, task.silver, task.gold);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                      content: Text('Награда получена: +${task.silver} серебра'
                          '${task.gold > 0 ? ' · +${task.gold} золота' : ''}'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(milliseconds: 1500),
                      backgroundColor: const Color(0xFF1A1F25),
                    ));
                }
              },
            )
          else
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: frac.clamp(0.0, 1.0),
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(kGold),
                    ),
                  ),
                  Text(
                    '${_fmt(cur)}/${_fmt(task.target)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
