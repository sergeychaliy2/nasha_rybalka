import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/player.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/fishing_enums.dart';
import '../../shared/content_images.dart';
import '../../shared/rendering/gear_icons.dart';
import '../shell/responsive.dart';
import '../shell/ui_kit.dart';
import 'gear_detail.dart';
import 'gear_stats.dart';

/// Магазин по рефу: слева — категории, справа — сетка карточек товара
/// в коллекционном TCG-стиле (рамка по редкости со свечением, тёмное окно
/// с предметом на светлом подиуме, золотой ценник).
class ShopTab extends ConsumerStatefulWidget {
  const ShopTab({super.key});

  @override
  ConsumerState<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends ConsumerState<ShopTab> {
  // По умолчанию открываем удилища (без вкладки «Все»).
  GearCategory _category = GearCategory.rod;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(gearCatalogProvider);
    final player = ref.watch(playerControllerProvider).value;

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (catalog) {
        final categories = <GearCategory>[];
        for (final g in catalog) {
          if (!categories.contains(g.category)) categories.add(g.category);
        }
        // Премиум — заметной вкладкой наверх списка категорий.
        if (categories.remove(GearCategory.premium)) {
          categories.insert(0, GearCategory.premium);
        }
        if (!categories.contains(_category) && categories.isNotEmpty) {
          _category = categories.first;
        }
        final items =
            catalog.where((g) => g.category == _category).toList();

        final compact = context.compact;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Сайдбар категорий (иконка + подпись).
            SizedBox(
              width: compact ? 66 : 92,
              child: ListView(
                children: [
                  for (final c in categories) _catTile(c, _categoryLabel(c)),
                ],
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            // Товары выбранной категории.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _categoryBanner(_category, items.length),
                  ),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: compact ? 168 : 236,
                        mainAxisExtent: compact ? 214 : 304,
                        crossAxisSpacing: compact ? 8 : 14,
                        mainAxisSpacing: compact ? 8 : 14,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) =>
                          _ProductCard(item: items[i], player: player),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _catTile(GearCategory c, String label) {
    final active = c == _category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => setState(() => _category = c),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? kGold.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? kGold : Colors.white.withValues(alpha: 0.1),
                  width: active ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE9E4D8), Color(0xFFC9C2B2)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: GearIcon(c, size: 30),
                ),
                const SizedBox(height: 4),
                Text(
                  _shortCatLabel(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? kGold : Colors.white60,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Короткая подпись для узкого сайдбара.
  String _shortCatLabel(String full) => switch (full) {
        'Катушки (поплавок)' => 'КАТУШКИ',
        'Катушки (спиннинг)' => 'КАТУШКИ СП.',
        _ => full.toUpperCase(),
      };

  /// Баннер категории: тематическое фото-полотно с названием и счётчиком
  /// поверх. Ключ по категории — AnimatedSwitcher плавно перелистывает баннеры.
  Widget _categoryBanner(GearCategory c, int count) {
    return Padding(
      key: ValueKey(c),
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 78,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/art/cat_${c.name}.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF141A20)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xE60C1218),
                      Color(0x770C1218),
                      Color(0x110C1218)
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 4, height: 30, color: kGold),
                    const SizedBox(width: 11),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_categoryLabel(c),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 8)
                                ])),
                        Text('$count шт. в наличии',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11.5)),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _categoryLabel(GearCategory c) => switch (c) {
        GearCategory.rod => 'Удилища',
        GearCategory.spinningRod => 'Спиннинги',
        GearCategory.floatReel => 'Катушки (поплавок)',
        GearCategory.spinningReel => 'Катушки (спиннинг)',
        GearCategory.line => 'Леска',
        GearCategory.braid => 'Шнур',
        GearCategory.hook => 'Крючки',
        GearCategory.bait => 'Наживки',
        GearCategory.lure => 'Приманки',
        GearCategory.echoSounder => 'Эхолоты',
        GearCategory.groundbait => 'Прикормка',
        GearCategory.spray => 'Спреи',
        GearCategory.energy => 'Энергия',
        GearCategory.premium => 'Премиум',
      };
}

/// Карточка товара в TCG-стиле бестиария: рамка/свечение по редкости, тёмное
/// окно с предметом на светлом подиуме, мини-шкала характеристики, ценник.
class _ProductCard extends ConsumerStatefulWidget {
  const _ProductCard({required this.item, required this.player});

  final GearItem item;
  final Player? player;

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = widget.player;
    final owned = p != null && p.inventory.any((e) => e.gearId == item.id);
    final consumable = _isConsumable(item.category);
    final levelOk = p != null && p.level >= item.requiredLevel;
    final affordable = p != null && p.wallet.canAfford(item.price);
    final canBuy = levelOk && affordable && (!owned || consumable);

    final rc = gearRarityColor(item.rarity);
    final isCommon = item.rarity == GearRarity.common;
    final (glowA, glowB) = gearRarityGlow(item.rarity);
    final stats = ref.watch(gearStatsProvider);
    final mainStat =
        (stats?.statsFor(item) ?? const <GearStat>[]).firstOrNull;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.03 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: InkWell(
          // Тап по карточке — детальный осмотр со шкалами и сравнением.
          onTap: () => showGearDetail(context, item: item, allowBuy: true),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1C232B), Color(0xFF0F141A)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hover
                    ? rc
                    : rc.withValues(alpha: isCommon ? 0.5 : 0.9),
                width: 2,
              ),
              boxShadow: [
                const BoxShadow(
                    color: Colors.black54, blurRadius: 16, offset: Offset(0, 8)),
                if (glowA > 0)
                  BoxShadow(
                      color: rc.withValues(alpha: _hover ? glowA + 0.15 : glowA),
                      blurRadius: glowB,
                      spreadRadius: 1),
              ],
            ),
            child: Stack(
              children: [
                // Верхний блик рамки по редкости.
                if (!isCommon)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Colors.transparent, rc, Colors.transparent]),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Лента редкости + требуемый уровень.
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: rc,
                              shape: BoxShape.circle,
                              boxShadow: isCommon
                                  ? null
                                  : [BoxShadow(color: rc, blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              gearRarityLabel(item.rarity).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: rc,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6),
                            ),
                          ),
                          Text('УР. ${item.requiredLevel}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.34),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Тёмное окно-витрина с предметом на светлом подиуме.
                      Expanded(child: _showcase(rc)),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            height: 1.05),
                      ),
                      const SizedBox(height: 7),
                      if (mainStat != null) _statBar(mainStat),
                      const SizedBox(height: 9),
                      _footer(context, ref,
                          owned: owned,
                          consumable: consumable,
                          levelOk: levelOk,
                          canBuy: canBuy),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Тёмное окно #11151A с рарити-хало; предмет — на центральном светлом
  /// подиуме (иконки снастей нарисованы тёмным под светлый фон).
  Widget _showcase(Color rc) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF1A2027), Color(0xFF11151A)],
          stops: [0, 0.65],
        ),
        border: Border.all(color: rc.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Рарити-хало позади подиума.
            Align(
              alignment: const Alignment(0, -0.05),
              child: FractionallySizedBox(
                widthFactor: 0.92,
                heightFactor: 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      rc.withValues(alpha: 0.22),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
            // Фото предмета (загруженное в админке → ассет) заполняет витрину;
            // если фото нет — светлый подиум с векторной иконкой.
            contentImage(
              'item_${widget.item.id}',
              'assets/art/items/${widget.item.id}.png',
              fallback: (_) => _podium(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _podium() {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.76,
        heightFactor: 0.84,
        child: Container(
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              center: Alignment(0, -0.25),
              radius: 0.95,
              colors: [Color(0xFFF1ECE0), Color(0xFFCBC4B4)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Center(child: GearIcon(widget.item.category, size: 54)),
        ),
      ),
    );
  }

  Widget _statBar(GearStat s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9.5)),
            ),
            Text(s.display,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(children: [
              ColoredBox(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: const SizedBox.expand()),
              FractionallySizedBox(
                widthFactor: s.value01,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kGoldLight, kGold]),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    WidgetRef ref, {
    required bool owned,
    required bool consumable,
    required bool levelOk,
    required bool canBuy,
  }) {
    final item = widget.item;
    if (owned && !consumable) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3E44),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text('В РЮКЗАКЕ',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w900)),
      );
    }
    return InkWell(
      onTap: canBuy ? () => _buy(context, ref) : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: canBuy
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kGoldLight, kGold])
              : null,
          color: canBuy ? null : const Color(0xFF2A2F36),
          borderRadius: BorderRadius.circular(9),
          border: canBuy
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!levelOk) ...[
              const Icon(Icons.lock, size: 13, color: Colors.white38),
              const SizedBox(width: 5),
              Text('УРОВЕНЬ ${item.requiredLevel}',
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900)),
            ] else ...[
              Icon(
                  item.price.type == CurrencyType.gold
                      ? Icons.diamond
                      : Icons.monetization_on,
                  size: 14,
                  color: canBuy ? kTextDark : Colors.white38),
              const SizedBox(width: 5),
              Text(
                  item.price.amount == 0 ? 'БЕСПЛАТНО' : '${item.price.amount}',
                  style: TextStyle(
                      color: canBuy ? kTextDark : Colors.white60,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900)),
            ],
          ],
        ),
      ),
    );
  }

  static bool _isConsumable(GearCategory c) =>
      c == GearCategory.bait ||
      c == GearCategory.groundbait ||
      c == GearCategory.spray ||
      c == GearCategory.energy;

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final item = widget.item;
    if (!await confirmPurchase(context, item)) return;
    if (!context.mounted) return;
    final res =
        await ref.read(playerControllerProvider.notifier).purchase(item);
    if (!context.mounted) return;
    final msg = switch (res) {
      PurchaseResult.ok when item is PremiumItem =>
        'Премиум активирован: ${item.name}',
      PurchaseResult.ok => 'Куплено: ${item.name}',
      PurchaseResult.notEnoughMoney => 'Недостаточно средств',
      PurchaseResult.levelTooLow => 'Нужен уровень ${item.requiredLevel}',
      PurchaseResult.alreadyOwned => 'Уже куплено',
      PurchaseResult.error => 'Не удалось купить',
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1F25),
      ));
  }
}
