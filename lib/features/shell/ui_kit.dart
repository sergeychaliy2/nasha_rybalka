import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/player.dart';
import '../../domain/value_objects/currency.dart';
import '../skills/skills_screen.dart';
import 'responsive.dart';

/// Общий визуальный язык по видео-рефу: фотофоны, круглые кнопки с золотым
/// ободом, серые панели с тёмными шапками, золотые CTA, верхний пилл
/// «монеты | уровень | опыт». Один модуль — единый вид всех экранов.

const kGold = Color(0xFFE2A63D);
const kGoldLight = Color(0xFFF4CA70);
const kSilver = Color(0xFFC9CDD2);
const kBronze = Color(0xFFB87333);
const kPanelBorder = Color(0x33E6A23C);

/// Серые панели окон (как в рефе: профиль/магазин/награды).
const kPanelBg = Color(0xF21E2227);
const kPanelBody = Color(0xEE343940);
const kPanelHeader = Color(0xFF1A1D21);
const kTextDark = Color(0xFF3A2A0A);

/// Цвет редкости предмета (рамки/подсветка в магазине и слотах).
Color gearRarityColor(GearRarity r) => switch (r) {
  GearRarity.common => const Color(0xFF9AA4AD),
  GearRarity.uncommon => const Color(0xFF5FB85F),
  GearRarity.rare => const Color(0xFF4E9CF5),
  GearRarity.epic => const Color(0xFFB266FF),
  GearRarity.legendary => const Color(0xFFFFA928),
};

// Снасть нельзя «выбить» — её покупают, поэтому у товаров не «редкость», а
// КЛАСС (уровень исполнения). Цвета-ступени те же, что у рамок.
String gearRarityLabel(GearRarity r) => switch (r) {
  GearRarity.common => 'Базовый',
  GearRarity.uncommon => 'Любительский',
  GearRarity.rare => 'Спортивный',
  GearRarity.epic => 'Профессиональный',
  GearRarity.legendary => 'Турнирный',
};

/// Сила свечения рамки снасти по редкости: (alpha, blur). Обычная — без
/// свечения, дальше ярче. Та же логика, что у карточек бестиария.
(double, double) gearRarityGlow(GearRarity r) => switch (r) {
  GearRarity.common => (0.0, 0.0),
  GearRarity.uncommon => (0.22, 16.0),
  GearRarity.rare => (0.34, 18.0),
  GearRarity.epic => (0.5, 22.0),
  GearRarity.legendary => (0.62, 26.0),
};

/// Декоративный заголовок (плотный «игровой» стиль).
TextStyle displayStyle({double size = 26, Color color = Colors.white}) =>
    TextStyle(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
      height: 1.05,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
    );

// ---------------------------------------------------------------------------
// Верхний статус-пилл: «монеты | уровень в кольце | опыт».
// ---------------------------------------------------------------------------

/// Живой статус игрока, как в рефе: серебро, уровень с золотым кольцом,
/// опыт до следующего уровня, плюс малый чип золота.
class StatusPill extends ConsumerWidget {
  const StatusPill({super.key, this.showSkillsButton = true});

  /// Показывать ли кнопку «Древо навыков» в попапе уровня. У воды — нет
  /// (прокачка навыков — занятие «на базе», не на спине во время заброса).
  final bool showSkillsButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider).value;
    final leveling = ref.watch(levelingServiceProvider);
    final silver = player?.wallet.balanceOf(CurrencyType.silver) ?? 0;
    final gold = player?.wallet.balanceOf(CurrencyType.gold) ?? 0;
    final energy = player?.currentEnergy ?? 100;
    final eColor = energy <= 20
        ? const Color(0xFFE5483B)
        : energy <= 50
        ? kGold
        : const Color(0xFF5FB85F);
    final level = player?.level ?? 1;
    final total = player?.totalCaughtGrams ?? 0;
    final lo = leveling.requiredTotalFor(level);
    final hi = leveling.requiredTotalFor(level + 1);
    final progress = hi > lo ? ((total - lo) / (hi - lo)).clamp(0.0, 1.0) : 0.0;
    final toNext = (hi - total).clamp(0, 1 << 31);

    return SizedBox(
      height: context.compact ? 32 : 46,
      child: FittedBox(
        fit: BoxFit.fitHeight,
        child: SizedBox(
          height: 46,
          child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _halfPill(
                left: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, size: 16, color: kGold),
                    const SizedBox(width: 6),
                    Text(_fmt(silver), style: _pillText),
                    const SizedBox(width: 12),
                    // Энергия — тап показывает, через сколько пополнится.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: player == null
                          ? null
                          : () => _showEnergyInfo(context, player),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 15, color: eColor),
                          const SizedBox(width: 3),
                          Text('$energy', style: _pillText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 44),
              _halfPill(
                left: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, size: 14, color: kGold),
                    const SizedBox(width: 4),
                    Text('$gold', style: _pillText),
                    const SizedBox(width: 12),
                    const Icon(Icons.scale, size: 14, color: Color(0xFF53A9F2)),
                    const SizedBox(width: 5),
                    Text(
                      '${(total / 1000).toStringAsFixed(1)} кг',
                      style: _pillText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Кольцо уровня с прогрессом и инфо по тапу.
          GestureDetector(
            onTap: () => _showLevelInfo(
              context,
              level,
              progress,
              toNext,
              showSkillsButton,
            ),
            // Долгий тап — тестовый чит (выдать 22 уровень и валюту).
            onLongPress: () => _confirmTestGrant(context, ref),
            child: _levelRing(level, progress),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _showLevelInfo(
    BuildContext context,
    int level,
    double progress,
    int toNextGrams,
    bool showSkills,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: HeaderPanel(
            header: 'Уровень $level',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Прогресс до уровня ${level + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Stack(
                      children: [
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const SizedBox.expand(),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kGoldLight, kGold],
                              ),
                            ),
                            child: SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).round()} %  ·  осталось '
                  '${(toNextGrams / 1000).toStringAsFixed(1)} кг улова',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Уровень растёт от суммарного веса всей пойманной рыбы — '
                  'и за «Забрать», и за «Отпустить». Каждый новый уровень '
                  'приносит опыт мастерства для древа навыков.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                if (showSkills)
                  Row(
                    children: [
                      Expanded(
                        child: GoldButton(
                          label: 'Древо навыков',
                          icon: Icons.account_tree,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            GameWindow.show(
                              context,
                              'Навыки',
                              const SkillsTree(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Закрыть',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Закрыть',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _halfPill({required bool left, required Widget child}) {
    return Container(
      height: 34,
      padding: EdgeInsets.only(left: left ? 14 : 24, right: left ? 24 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF222831).withValues(alpha: 0.95),
            const Color(0xFF11151A).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(left ? 18 : 0),
          right: Radius.circular(left ? 0 : 18),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: Center(child: child),
    );
  }

  /// Инфо по энергии: сколько сейчас, через сколько +1 и полный бак.
  void _showEnergyInfo(BuildContext context, Player player) {
    final cur = player.currentEnergy;
    final max = Player.maxEnergy;
    final regen = Player.energyRegenSeconds;
    String mmss(int s) =>
        '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    String human(int s) {
      if (s >= 3600) return '${s ~/ 3600} ч ${(s % 3600) ~/ 60} мин';
      if (s >= 60) return '${s ~/ 60} мин ${s % 60} с';
      return '$s с';
    }

    String nextLine;
    String fullLine = '';
    if (cur >= max) {
      nextLine = 'Бак полон — энергия максимальна';
    } else {
      final last = player.lastEnergyAt;
      final elapsed =
          last == null ? 0 : DateTime.now().difference(last).inSeconds;
      final toNext = regen - (elapsed % regen);
      final toFull = (max - cur - 1) * regen + toNext;
      nextLine = '+1 энергии через ${mmss(toNext)}';
      fullLine = 'Полный бак через ${human(toFull)}';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: HeaderPanel(
            header: 'Энергия',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt, color: kGold, size: 26),
                    const SizedBox(width: 6),
                    Text('$cur / $max',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(nextLine,
                    style: const TextStyle(
                        color: kGold, fontSize: 14, fontWeight: FontWeight.w800)),
                if (fullLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(fullLine,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                Text(
                  'Заброс тратит 3 энергии. Восстанавливается со временем '
                  '(1 ед. за 5 мин) и полностью — при каждом запуске игры. '
                  'Перекус из рюкзака пополняет сразу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Закрыть',
                        style: TextStyle(color: Colors.white60)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Тестовый чит (долгий тап по кольцу уровня): выдать 22-й уровень и валюту.
  void _confirmTestGrant(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: HeaderPanel(
            header: 'Тест',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Выдать 22-й уровень и валюту для тестирования?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GoldButton(
                        label: '22 уровень',
                        icon: Icons.bolt,
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .grantTestProgress();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Отмена',
                          style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Кольцо уровня: тёмный диск, дуга прогресса золотом, номер по центру.
  Widget _levelRing(int level, double progress) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF12161B),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.5,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(kGold),
            ),
          ),
          Text(
            '$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static const _pillText = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

// ---------------------------------------------------------------------------
// Круглая кнопка с золотым ободом (углы сцены/карты).
// ---------------------------------------------------------------------------

class CircleIconButton extends StatefulWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 56,
    this.badge,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? badge;
  final String? tooltip;

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  bool _pressed = false;

  IconData get icon => widget.icon;
  double get size => widget.size;
  String? get badge => widget.badge;
  String? get tooltip => widget.tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFF7F1DC), Color(0xFFD9CFAF)],
              ),
              border: Border.all(color: kGold, width: 2.6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.5, color: const Color(0xFF5B4423)),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5483B),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                ),
                alignment: Alignment.center,
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

// ---------------------------------------------------------------------------
// Панель с тёмной шапкой-заголовком (как «ВАШ ПРОФИЛЬ» / карточки магазина).
// ---------------------------------------------------------------------------

class HeaderPanel extends StatelessWidget {
  const HeaderPanel({
    super.key,
    required this.header,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final String header;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kPanelBody,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: kPanelHeader,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            child: Text(
              header.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Тёмная ячейка «подпись + значение» (профиль, характеристики товара).
class StatCell extends StatelessWidget {
  const StatCell({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Полноэкранное игровое окно: скрим + ✕ + статус-пилл + золотой титул.
// ---------------------------------------------------------------------------

class GameWindow extends StatelessWidget {
  const GameWindow({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  /// Открывает окно поверх текущего экрана (затемняя его, как в рефе).
  /// Появление «дорогое»: лёгкий подъём + масштаб + растворение.
  static Future<void> show(BuildContext context, String title, Widget child) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => GameWindow(title: title, child: child),
      transitionBuilder: (_, anim, _, w) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(curved),
              child: w,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Непрозрачный атмосферный фон — игровой экран позади не просвечивает.
    return Material(
      color: const Color(0xFF0B0E12),
      child: AtmosphereBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: context.compact
                    ? const EdgeInsets.fromLTRB(8, 4, 8, 2)
                    : const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    _closeButton(context),
                    const Spacer(),
                    const StatusPill(),
                    const Spacer(),
                    _titlePill(),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: context.compact
                      ? const EdgeInsets.fromLTRB(10, 2, 10, 8)
                      : const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    final d = context.compact ? 30.0 : 38.0;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: const Color(0xFF15181C),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(Icons.close,
            color: Colors.white, size: context.compact ? 17 : 20),
      ),
    );
  }

  Widget _titlePill() {
    return Builder(builder: (context) {
      final c = context.compact;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: c ? 10 : 16, vertical: c ? 5 : 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kGoldLight, kGold],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: kTextDark,
            fontSize: c ? 11 : 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Кнопки.
// ---------------------------------------------------------------------------

/// Главная золотая кнопка (CTA) — как «ОТКРЫТЬ» / «КУПИТЬ» в рефе.
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final icon = widget.icon;
    final label = widget.label;
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: InkWell(
      onTap: enabled ? widget.onTap : null,
      onHighlightChanged: (v) => setState(() => _pressed = v && enabled),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kGoldLight, kGold],
                )
              : null,
          color: enabled ? null : const Color(0xFF4A4E54),
          borderRadius: BorderRadius.circular(9),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: enabled ? kTextDark : Colors.white38),
              const SizedBox(width: 7),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: enabled ? kTextDark : Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Переход на полноэкранную сцену: мягкое растворение с лёгким наездом.
Route<T> fadeScaleRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 1.03, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Тематический «занавес-заброс» при выходе на воду: крючок на леске опускается
/// под воду, рыба подходит и клюёт, леска вытягивает её к поверхности —
/// затем занавес растворяется и открывает сцену ловли.
Route<T> fishingCurtainRoute<T>(Widget page, {String? caption}) {
  return PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _FishingCurtain(caption: caption, child: page),
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _FishingCurtain extends StatefulWidget {
  const _FishingCurtain({required this.child, this.caption});
  final Widget child;
  final String? caption;

  @override
  State<_FishingCurtain> createState() => _FishingCurtainState();
}

class _FishingCurtainState extends State<_FishingCurtain>
    with SingleTickerProviderStateMixin {
  bool _done = false;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )
    ..addStatusListener((s) {
      // По завершении убираем оверлей полностью — чтобы он не мог
      // перехватывать жесты сцены ни при каких обстоятельствах.
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // После завершения занавеса оставляем ТОЛЬКО сцену — никакого оверлея
    // сверху, чтобы он гарантированно не перехватывал тапы/жесты.
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final a = t < 0.80 ? 1.0 : (1 - (t - 0.80) / 0.20).clamp(0.0, 1.0);
            if (a <= 0) return const SizedBox.shrink();
            // Занавес — чисто визуальный слой: жесты проходят сквозь него
            // (IgnorePointer), он не может заблокировать сцену под собой.
            return IgnorePointer(
              child: Opacity(
                opacity: a,
                child: CustomPaint(
                  painter: _HookCatchPainter(t, widget.caption),
                  size: Size.infinite,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HookCatchPainter extends CustomPainter {
  _HookCatchPainter(this.t, this.caption);
  final double t;
  final String? caption;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Подводный градиент.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16384A), Color(0xFF06121C)],
        ).createShader(Offset.zero & size),
    );

    // Лучи света от поверхности.
    for (var i = 0; i < 3; i++) {
      final lx = cx + (i - 1) * w * 0.2;
      canvas.drawPath(
        Path()
          ..moveTo(lx - 12, 0)
          ..lineTo(lx + 12, 0)
          ..lineTo(lx + 64, h * 0.62)
          ..lineTo(lx - 64, h * 0.62)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.035),
      );
    }

    // Поверхность сверху.
    final sy = h * 0.12;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, sy),
      Paint()..color = const Color(0xFF2A5C6E).withValues(alpha: 0.45),
    );
    canvas.drawLine(
      Offset(0, sy),
      Offset(w, sy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 2,
    );

    // Пузырьки.
    for (var i = 0; i < 16; i++) {
      final bx = ((i * 71) % 100) / 100 * w;
      final phase = (t * 1.3 + i * 0.137) % 1.0;
      final by = h - phase * h;
      final r = 1.5 + (i % 4);
      canvas.drawCircle(
        Offset(bx + math.sin(phase * 6 + i) * 8, by),
        r.toDouble(),
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
    }

    // --- Крючок на леске ---
    final restY = h * 0.55;
    final topY = -h * 0.04;
    final descend = Curves.easeIn.transform((t / 0.40).clamp(0.0, 1.0));
    final reel = Curves.easeInOut.transform(((t - 0.58) / 0.30).clamp(0.0, 1.0));
    double hookY;
    if (t < 0.58) {
      hookY = topY + (restY - topY) * descend;
      if (t > 0.40) hookY += math.sin((t - 0.40) * 46) * 4; // дрожь при поклёвке
    } else {
      hookY = restY + (topY - restY) * reel;
    }
    final hookX = cx + math.sin(t * 5) * (w * 0.012);

    // Леска.
    canvas.drawLine(
      Offset(cx, -4),
      Offset(hookX, hookY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.4,
    );
    // Крючок (J).
    final hook = Path()
      ..moveTo(hookX, hookY)
      ..lineTo(hookX, hookY + 12)
      ..arcToPoint(Offset(hookX - 8, hookY + 16),
          radius: const Radius.circular(6), clockwise: false);
    canvas.drawPath(
      hook,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE7ECEF),
    );

    // --- Рыба ---
    if (t > 0.38) {
      final appear = ((t - 0.38) / 0.16).clamp(0.0, 1.0);
      Offset fp;
      if (t < 0.58) {
        fp = Offset.lerp(Offset(hookX - w * 0.24, hookY + 30),
            Offset(hookX + 2, hookY + 18), appear)!;
      } else {
        fp = Offset(hookX + 2, hookY + 18);
      }
      fp = fp + Offset(0, math.sin(t * 26) * 3);
      _fish(canvas, fp, w * 0.07, appear);

      // Кольцо-всплеск в момент поклёвки.
      if (t > 0.46 && t < 0.62) {
        final rt = (t - 0.46) / 0.16;
        canvas.drawCircle(
          Offset(hookX, hookY + 14),
          10 + rt * 40,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * (1 - rt)
            ..color = Colors.white.withValues(alpha: 0.4 * (1 - rt)),
        );
      }
    }

    // Всплеск у поверхности, когда рыбу выводят.
    if (t > 0.72 && t < 0.9) {
      final st = (t - 0.72) / 0.18;
      canvas.drawCircle(
        Offset(cx, sy),
        16 + st * 60,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - st)
          ..color = Colors.white.withValues(alpha: 0.5 * (1 - st)),
      );
    }

    if (caption != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: caption!.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w * 0.8);
      tp.paint(canvas, Offset(cx - tp.width / 2, h * 0.80));
    }
  }

  void _fish(Canvas canvas, Offset c, double len, double alpha) {
    final a = alpha.clamp(0.0, 1.0);
    final body = Paint()..color = const Color(0xFFB9C6CC).withValues(alpha: 0.7 * a);
    final half = len * 0.34;
    // Тело.
    final path = Path()
      ..moveTo(c.dx + len * 0.5, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - half, c.dx - len * 0.42, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + half, c.dx + len * 0.5, c.dy)
      ..close();
    canvas.drawPath(path, body);
    // Хвост.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - len * 0.42, c.dy)
        ..lineTo(c.dx - len * 0.64, c.dy - len * 0.22)
        ..lineTo(c.dx - len * 0.64, c.dy + len * 0.22)
        ..close(),
      body,
    );
    // Глаз.
    canvas.drawCircle(Offset(c.dx + len * 0.3, c.dy - len * 0.06), len * 0.05,
        Paint()..color = Colors.black.withValues(alpha: 0.6 * a));
  }

  @override
  bool shouldRepaint(covariant _HookCatchPainter old) =>
      old.t != t || old.caption != caption;
}

/// Тех. помощник для превью кадров «занавеса» (используется в test/tools).
void paintHookCatchPreview(
        Canvas canvas, Size size, double t, String? caption) =>
    _HookCatchPainter(t, caption).paint(canvas, size);

// ---------------------------------------------------------------------------
// Наследие (используется существующими разделами).
// ---------------------------------------------------------------------------

/// Атмосферный тёмный фон с елями (для окон без фотофона).
class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16221F), Color(0xFF0C1013), Color(0xFF07090B)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: CustomPaint(painter: _PineHorizonPainter(), child: child),
    );
  }
}

class _PineHorizonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.30;
    final paint = Paint()
      ..color = const Color(0xFF0A1412).withValues(alpha: 0.7);
    final rnd = math.Random(42);
    var x = -20.0;
    while (x < size.width + 20) {
      final h = 26 + rnd.nextDouble() * 46;
      final w = 14 + rnd.nextDouble() * 16;
      final path = Path()
        ..moveTo(x, baseY)
        ..lineTo(x + w / 2, baseY - h)
        ..lineTo(x + w, baseY)
        ..close();
      canvas.drawPath(path, paint);
      x += w * 0.72;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Панель с тёмной заливкой и золотистой рамкой (старый стиль разделов).
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kPanelBody,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

/// Заголовок раздела с золотой полосой.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 22, color: kGold),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(icon, color: kGold, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(text, style: displayStyle(size: 20))),
      ],
    );
  }
}

/// Кружок-медаль с номером места.
class MedalBadge extends StatelessWidget {
  const MedalBadge(this.place, {super.key, this.size = 26});

  final int place;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (place) {
      1 => kGold,
      2 => kSilver,
      3 => kBronze,
      _ => const Color(0xFF3A4047),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$place',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
