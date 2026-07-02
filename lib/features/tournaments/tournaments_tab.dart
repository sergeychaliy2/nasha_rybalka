import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/value_objects/currency.dart';
import '../fishing/fishing_screen.dart';
import '../../shared/content_images.dart';
import '../shell/ui_kit.dart';
import 'tournament.dart';

/// Раздел «Турниры»: соревнования с ботами. Вход за взнос → зачётная сессия
/// ловли на время → итоговая таблица и призовые по месту.
class TournamentsTab extends ConsumerWidget {
  const TournamentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(playerControllerProvider).value?.level ?? 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Турниры', icon: Icons.shield_outlined),
        const SizedBox(height: 14),
        for (final t in activeTournaments()) ...[
          _TournamentCard(tournament: t, playerLevel: level),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

String _stageWord(int n) =>
    n == 1 ? 'ЭТАП' : (n >= 2 && n <= 4 ? 'ЭТАПА' : 'ЭТАПОВ');

String _fmtKg(int grams) => '${(grams / 1000).toStringAsFixed(2)} кг';

class _TournamentCard extends ConsumerWidget {
  const _TournamentCard({required this.tournament, required this.playerLevel});

  final Tournament tournament;
  final int playerLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    final levelOk = playerLevel >= t.requiredLevel;
    return GamePanel(
      padding: EdgeInsets.zero,
      onTap: () => showDialog(
        context: context,
        builder: (_) => _TournamentDialog(t),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 178,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фон — живописный вид водоёма турнира.
              contentImage(
                assetStem(t.backdrop),
                t.backdrop,
                alignment: Alignment.centerRight,
                fallback: (_) =>
                    const ColoredBox(color: Color(0xFF1A1F25)),
              ),
              // Затемнение слева — под заголовок и призы.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF20B1117),
                      Color(0xBF0B1117),
                      Color(0x220B1117),
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            _stageChip(t),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                t.dateRange,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11.5),
                              ),
                            ),
                          ]),
                          const Spacer(),
                          Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: displayStyle(size: 23)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.place, size: 13, color: kGold),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(t.locationName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.timer,
                                size: 13, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text('${t.durationSec ~/ 60} мин',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                          ]),
                          const SizedBox(height: 12),
                          _rewards(t),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Панель управления: уровень + вход.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _levelGauge(t.requiredLevel, levelOk),
                          const SizedBox(height: 12),
                          GoldButton(
                            label: 'УЧАСТВОВАТЬ',
                            icon: Icons.login,
                            enabled: levelOk,
                            onTap: () => _showEntry(context, ref, t),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageChip(Tournament t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kGoldLight, kGold]),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text('${t.stageCount} ${_stageWord(t.stageCount)}',
            style: const TextStyle(
                color: kTextDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4)),
      );

  /// Окно подтверждения: выбор валюты взноса и старт сессии.
  void _showEntry(BuildContext context, WidgetRef ref, Tournament t) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: HeaderPanel(
            header: 'Вход в турнир',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.title,
                    style: displayStyle(size: 18), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                    'Сессия ${t.durationSec ~/ 60} мин на «${t.locationName}». '
                    'Лови как можно больше — в зачёт идёт суммарный вес. '
                    'Соперники — 12 рыбаков.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: GoldButton(
                      label: '🥈 ${t.entrySilver}',
                      icon: Icons.login,
                      onTap: () => _enter(
                          context, dialogCtx, ref, t, Money.silver(t.entrySilver)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GoldButton(
                      label: '🥇 ${t.entryGold}',
                      icon: Icons.login,
                      onTap: () => _enter(
                          context, dialogCtx, ref, t, Money.gold(t.entryGold)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Отмена',
                      style: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enter(BuildContext pageCtx, BuildContext dialogCtx, WidgetRef ref,
      Tournament t, Money entry) async {
    final nav = Navigator.of(pageCtx);
    final res = await ref.read(playerControllerProvider.notifier).enterTournament(
          t.id,
          requiredLevel: t.requiredLevel,
          entry: entry,
          durationSec: t.durationSec,
        );
    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
    if (!pageCtx.mounted) return;
    switch (res) {
      case UnlockResult.ok:
        nav.push(fishingCurtainRoute(
          FishingScreen(locationId: t.locationId),
          caption: t.title,
        ));
      case UnlockResult.levelTooLow:
        _snack(pageCtx, 'Нужен ${t.requiredLevel}-й уровень');
      case UnlockResult.notEnoughMoney:
        _snack(pageCtx, 'Недостаточно средств для взноса');
      case UnlockResult.error:
        _snack(pageCtx, 'Не удалось войти в турнир');
    }
  }

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1F25),
      ));
  }

  Widget _rewards(Tournament t) {
    Widget medal(int place, int amount) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            MedalBadge(place, size: 22),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.circle, size: 10, color: kSilver),
              const SizedBox(width: 3),
              Text('$amount',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        );
    return Row(children: [
      medal(1, t.reward1),
      medal(2, t.reward2),
      medal(3, t.reward3),
    ]);
  }

  Widget _levelGauge(int required, bool ok) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: ok ? kGold : const Color(0xFFE5483B), width: 2),
        ),
        child: Text('$required',
            style: TextStyle(
                color: ok ? kGold : const Color(0xFFE5483B),
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ),
      const SizedBox(height: 2),
      const Text('уровень',
          style: TextStyle(color: Colors.white38, fontSize: 9)),
    ]);
  }
}

/// Детали турнира: вкладки Информация / Призы / Рейтинг.
class _TournamentDialog extends StatefulWidget {
  const _TournamentDialog(this.tournament);
  final Tournament tournament;

  @override
  State<_TournamentDialog> createState() => _TournamentDialogState();
}

class _TournamentDialogState extends State<_TournamentDialog> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: GamePanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: Text(t.title, style: displayStyle(size: 22))),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _tabBtn('ИНФОРМАЦИЯ', 0),
                _tabBtn('ПРИЗЫ', 1),
                _tabBtn('СОПЕРНИКИ', 2),
              ]),
              const SizedBox(height: 14),
              Flexible(child: _body(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: active ? kGold : Colors.white12, width: 2),
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? kGold : Colors.white54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _body(Tournament t) {
    return switch (_tab) {
      0 => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.event, t.dateRange),
              _infoRow(Icons.place, t.locationName),
              _infoRow(Icons.timer, 'Сессия: ${t.durationSec ~/ 60} мин'),
              _infoRow(Icons.military_tech,
                  'Требуемый уровень: ${t.requiredLevel}'),
              _infoRow(Icons.login,
                  'Взнос: ${t.entrySilver} серебра или ${t.entryGold} золота'),
              const SizedBox(height: 12),
              Text(t.info,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      1 => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _prizeRow(1, t.reward1, t.goldReward),
            _prizeRow(2, t.reward2, (t.goldReward * 0.5).round()),
            _prizeRow(3, t.reward3, (t.goldReward * 0.25).round()),
          ],
        ),
      _ => _leaderboard(t),
    };
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: kGold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        ),
      ]),
    );
  }

  Widget _prizeRow(int place, int silver, int gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        MedalBadge(place),
        const SizedBox(width: 14),
        Text('$place место',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        const Icon(Icons.circle, size: 13, color: kSilver),
        const SizedBox(width: 6),
        Text('$silver',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        if (gold > 0) ...[
          const SizedBox(width: 12),
          const Icon(Icons.circle, size: 13, color: kGold),
          const SizedBox(width: 6),
          Text('$gold',
              style: const TextStyle(
                  color: kGold, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ]),
    );
  }

  Widget _leaderboard(Tournament t) {
    final rows = previewLeaderboard(t, t.id.hashCode);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            SizedBox(
                width: 48,
                child: Text('МЕСТО',
                    style: TextStyle(color: Colors.white38, fontSize: 11))),
            SizedBox(width: 8),
            Expanded(
                child: Text('РЫБАК',
                    style: TextStyle(color: Colors.white38, fontSize: 11))),
            Text('ЗАЧЁТ',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  SizedBox(
                    width: 48,
                    child: r.place <= 3
                        ? MedalBadge(r.place, size: 22)
                        : Text('${r.place}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.player,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(_fmtKg(r.rating),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}
