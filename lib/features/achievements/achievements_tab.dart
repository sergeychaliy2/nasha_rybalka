import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/value_objects/currency.dart';
import '../shell/ui_kit.dart';

/// Раздел «Достижения»: цели с прогрессом, считаются от текущего профиля.
/// Набор статический, прогресс — живой (от сейва игрока).
class AchievementsTab extends ConsumerWidget {
  const AchievementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider).value;
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final silver = player.wallet.balanceOf(CurrencyType.silver);
    final gold = player.wallet.balanceOf(CurrencyType.gold);
    final grams = player.totalCaughtGrams;
    final species = player.discoveredSpeciesIds.length;
    final heaviest =
        player.trophies.isEmpty ? 0 : player.trophies.first.weight.grams;
    final totalCatches =
        player.speciesCounts.values.fold<int>(0, (s, v) => s + v);
    final skillLevels = player.skills.values.fold<int>(0, (s, v) => s + v);

    const cBook = Color(0xFF5AA9E6); // бестиарий/виды
    const cLevel = Color(0xFFE0C24A); // уровень
    const cWeight = Color(0xFF7FD4A3); // вес
    const cTrophy = Color(0xFFB98CFF); // трофей
    const cCount = Color(0xFF54C9C9); // счётчики
    const cTravel = Color(0xFF6FBF73); // путешествия
    const cSport = Color(0xFFE0864A); // спорт/турнир/навыки
    final items = <_Achi>[
      _Achi('Первый улов', 'Открой свой первый вид рыбы', Icons.set_meal,
          species, 1, cBook),
      _Achi('Натуралист', 'Открой 6 видов в бестиарии', Icons.menu_book,
          species, 6, cBook),
      _Achi('Зоолог', 'Открой 12 видов в бестиарии', Icons.pets, species, 12,
          cBook),
      _Achi('Рыболов', 'Достигни 5 уровня', Icons.military_tech, player.level, 5,
          cLevel),
      _Achi('Бывалый', 'Достигни 10 уровня', Icons.workspace_premium,
          player.level, 10, cLevel),
      _Achi('Тяжеловес', 'Налови суммарно 10 кг', Icons.scale, grams, 10000,
          cWeight),
      _Achi('Центнер', 'Налови суммарно 100 кг', Icons.fitness_center, grams,
          100000, cWeight),
      _Achi('Трофейщик', 'Поймай рыбу от 3 кг', Icons.emoji_events, heaviest,
          3000, cTrophy),
      _Achi('Гигант на крючке', 'Поймай рыбу от 8 кг', Icons.whatshot, heaviest,
          8000, cTrophy),
      _Achi('Сотня хвостов', 'Поймай 100 рыб', Icons.tag, totalCatches, 100,
          cCount),
      _Achi('Запасливый', 'Накопи 1000 серебра', Icons.savings, silver, 1000,
          kGold),
      _Achi('Богач', 'Накопи 10 000 серебра', Icons.account_balance, silver,
          10000, kGold),
      _Achi('Золотой запас', 'Накопи 50 золота', Icons.diamond, gold, 50, kGold),
      _Achi('Путешественник', 'Открой 5 водоёмов', Icons.travel_explore,
          player.unlockedLocationIds.length, 5, cTravel),
      _Achi('Покоритель стран', 'Открой 3 страны', Icons.public,
          player.unlockedCountryIds.length, 3, cTravel),
      _Achi('Чемпион', 'Выиграй турнир', Icons.shield, player.tournamentWins, 1,
          cSport),
      _Achi('Мастер', 'Прокачай 10 уровней навыков', Icons.account_tree,
          skillLevels, 10, cSport),
    ];

    final done = items.where((a) => a.done).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Достижения', icon: Icons.emoji_events_outlined),
        const SizedBox(height: 12),
        _SummaryBar(done: done, total: items.length),
        const SizedBox(height: 14),
        for (final a in items) ...[
          _AchiRow(a),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: kGold, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Выполнено $done из $total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(kGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Achi {
  _Achi(this.title, this.desc, this.icon, this.current, this.target,
      [this.color = kGold]);
  final String title;
  final String desc;
  final IconData icon;
  final int current;
  final int target;
  final Color color;
  bool get done => current >= target;
  double get progress => (current / target).clamp(0.0, 1.0);
}

class _AchiRow extends StatelessWidget {
  const _AchiRow(this.a);
  final _Achi a;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                a.color.withValues(alpha: a.done ? 0.42 : 0.22),
                a.color.withValues(alpha: 0.06),
              ]),
              border: Border.all(
                  color: a.color.withValues(alpha: a.done ? 0.7 : 0.4),
                  width: 1.4),
            ),
            child: Icon(a.icon,
                color: a.done ? a.color : a.color.withValues(alpha: 0.75),
                size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(a.desc,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: a.progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(
                              a.done ? kGold : const Color(0xFF5FB85F)),
                        ),
                      ),
                    ),
                    if (!a.done) ...[
                      const SizedBox(width: 8),
                      Text('${a.current}/${a.target}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(a.done ? Icons.check_circle : Icons.lock_outline,
              color: a.done ? kGold : Colors.white24, size: 22),
        ],
      ),
    );
  }
}
