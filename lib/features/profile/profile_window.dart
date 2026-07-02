import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/player.dart';
import '../../domain/value_objects/currency.dart';
import '../daily/daily_dialog.dart';
import '../menu/main_menu_screen.dart';
import '../shell/ui_kit.dart';
import '../skills/skills_screen.dart';

/// Тело окна «Профиль игрока»: карточка персонажа (аватар-рыбак, кольцо
/// уровня, полоса опыта) + плитки статистики с иконками + настройки.
class ProfileWindowBody extends ConsumerWidget {
  const ProfileWindowBody({super.key});

  static String _rank(int lvl) {
    if (lvl >= 25) return 'Легенда';
    if (lvl >= 20) return 'Мастер';
    if (lvl >= 15) return 'Эксперт';
    if (lvl >= 10) return 'Рыболов';
    if (lvl >= 5) return 'Любитель';
    return 'Новичок';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider).value;
    final leveling = ref.watch(levelingServiceProvider);
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final caught = player.speciesCounts.values.fold<int>(0, (s, v) => s + v);
    final record = player.trophies.isEmpty
        ? '—'
        : player.trophies.first.weight.formatted;
    final toNext = leveling.gramsToNext(player.totalCaughtGrams);
    final frac = leveling.progressToNext(player.totalCaughtGrams);

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HeaderPanel(
                  header: 'Ваш профиль',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _hero(player, frac, toNext),
                      const SizedBox(height: 12),
                      _grid(player, caught, record),
                      const SizedBox(height: 10),
                      _premium(player),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: GoldButton(
                            label: 'Древо навыков',
                            icon: Icons.account_tree,
                            onTap: () => GameWindow.show(
                                context, 'Навыки', const SkillsTree()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GoldButton(
                            label: 'Награда дня',
                            icon: Icons.card_giftcard,
                            onTap: () => showDailyReward(context),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: GoldButton(
                          label: 'Выйти в главное меню',
                          icon: Icons.logout,
                          onTap: () =>
                              Navigator.of(context).popUntil((r) => r.isFirst),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const SizedBox(width: 360, child: SettingsWindowBody()),
            ],
          ),
        ),
      ),
    );
  }

  /// Карточка персонажа: аватар-рыбак в кольце уровня + звание + полоса опыта.
  Widget _hero(Player player, double frac, int toNext) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26313F), Color(0xFF141A22)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.4)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
      ),
      child: Row(
        children: [
          // Аватар + кольцо прогресса уровня.
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: frac,
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(kGold),
                  ),
                ),
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Image.asset(
                      'assets/art/fisherman.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.72),
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF1A2027),
                        child: const Icon(Icons.person,
                            color: kGold, size: 34),
                      ),
                    ),
                  ),
                ),
                // Бейдж уровня.
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kGoldLight, kGold]),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFF141A22), width: 1.5),
                    ),
                    child: Text('${player.level}',
                        style: const TextStyle(
                            color: kTextDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_rank(player.level), style: displayStyle(size: 21)),
                const SizedBox(height: 2),
                Text('Уровень ${player.level}',
                    style: const TextStyle(
                        color: kGold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(kGold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(toNext / 1000).toStringAsFixed(1)} кг до ур. ${player.level + 1}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(Player player, int caught, String record) {
    final silver = player.wallet.balanceOf(CurrencyType.silver);
    final gold = player.wallet.balanceOf(CurrencyType.gold);
    Widget row(Widget a, Widget b) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ]),
        );
    return Column(
      children: [
        row(
          _stat(Icons.paid, const Color(0xFFCBD3DA), 'Монеты', '$silver'),
          _stat(Icons.diamond, kGold, 'Золото', '$gold'),
        ),
        row(
          _stat(Icons.emoji_events, const Color(0xFFB98CFF), 'Рекордный улов',
              record),
          _stat(Icons.phishing, const Color(0xFF5AA9E6), 'Поймано рыб',
              '$caught'),
        ),
        row(
          _stat(Icons.menu_book, const Color(0xFF54C9C9), 'Видов открыто',
              '${player.discoveredSpeciesIds.length}'),
          _stat(Icons.scale, const Color(0xFF7FD4A3), 'Всего выловлено',
              '${(player.totalCaughtGrams / 1000).toStringAsFixed(1)} кг'),
        ),
        row(
          _stat(Icons.shield, const Color(0xFFE0864A), 'Побед в турнирах',
              '${player.tournamentWins}'),
          _stat(Icons.bolt, const Color(0xFF8FD14F), 'Энергия',
              '${player.currentEnergy} / ${Player.maxEnergy}'),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, Color col, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                col.withValues(alpha: 0.26),
                col.withValues(alpha: 0.06),
              ]),
              border: Border.all(color: col.withValues(alpha: 0.5), width: 1.3),
            ),
            child: Icon(icon, color: col, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premium(Player player) {
    final active = player.isPremium;
    final text = active
        ? 'до ${player.premiumUntil!.day.toString().padLeft(2, '0')}.'
            '${player.premiumUntil!.month.toString().padLeft(2, '0')} · ур. ${player.premiumTier}'
        : 'не активен';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          (active ? kGold : Colors.white).withValues(alpha: 0.12),
          Colors.black.withValues(alpha: 0.25),
        ]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: (active ? kGold : Colors.white).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.workspace_premium,
            color: active ? kGold : Colors.white38, size: 22),
        const SizedBox(width: 10),
        const Text('ПРЕМИУМ',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
        const Spacer(),
        Text(text,
            style: TextStyle(
                color: active ? kGold : Colors.white54,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
