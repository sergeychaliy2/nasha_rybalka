import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/player.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/fishing_enums.dart';
import '../../shared/rendering/gear_icons.dart';
import '../shell/ui_kit.dart';
import '../shop/gear_detail.dart';

/// Снаряжение: по центру — рыбак на подиуме, по бокам — крупные слоты
/// экипировки. Тап по слоту открывает подборщик: надеть из рюкзака или
/// купить прямо здесь (купленное надевается сразу).
///
/// Отдельного тумблера «поплавок/спиннинг» нет: в слоте «В руках» лежат и
/// удочки, и спиннинги — что экипировал, тем и ловишь.
class GearTab extends ConsumerStatefulWidget {
  const GearTab({super.key, this.shopAllowed = true});

  /// На воде покупка запрещена — пикер предлагает только замену из рюкзака.
  final bool shopAllowed;

  @override
  ConsumerState<GearTab> createState() => _GearTabState();
}

/// Логические слоты экипировки.
enum _Slot { rod, reel, line, hook, bait, echo }

class _GearTabState extends ConsumerState<GearTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(gearCatalogProvider);
    final player = ref.watch(playerControllerProvider).value;

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (catalog) {
        if (player == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final byId = {for (final g in catalog) g.id: g};
        final l = player.loadout;
        final spin = l.mode == FishingMode.spinning;

        final left = [_Slot.rod, _Slot.reel, _Slot.line];
        final right = [
          if (!spin) _Slot.hook,
          _Slot.bait,
          _Slot.echo,
        ];

        return LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 760;
          final slotW = narrow ? 180.0 : 215.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: slotW,
                child: ListView(
                  children: [
                    for (final s in left)
                      _slotCard(s, _equippedItem(byId, l, s, spin), spin,
                          catalog, player),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Центральный подиум с персонажем.
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1C242C), Color(0xFF0F1419)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGold.withValues(alpha: 0.35)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 14),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [kGoldLight, kGold]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          spin
                              ? 'СПИННИНГОВАЯ ЛОВЛЯ'
                              : 'ПОПЛАВОЧНАЯ ЛОВЛЯ',
                          style: const TextStyle(
                              color: kTextDark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8),
                        ),
                      ),
                      Expanded(child: _fishermanView(spin)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Text(
                          'Нажми на слот, чтобы экипировать из рюкзака или купить',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: slotW,
                child: ListView(
                  children: [
                    for (final s in right)
                      _slotCard(s, _equippedItem(byId, l, s, spin), spin,
                          catalog, player),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }

  /// Персонаж в центре подиума: сгенерённый рыбак (фото) с мягким золотым
  /// свечением, тенью под ногами и лёгким «дыханием» (idle-боб). Если ассета
  /// нет — откат на векторного рыбака [_FishermanPainter].
  Widget _fishermanView(bool spin) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Золотое свечение за спиной.
        Align(
          alignment: const Alignment(0, -0.05),
          child: FractionallySizedBox(
            widthFactor: 0.82,
            heightFactor: 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kGold.withValues(alpha: 0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
        // Тень-подиум под ногами.
        Align(
          alignment: const Alignment(0, 0.9),
          child: FractionallySizedBox(
            widthFactor: 0.6,
            heightFactor: 0.06,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(200),
                gradient: const RadialGradient(
                    colors: [Color(0x77000000), Color(0x00000000)]),
              ),
            ),
          ),
        ),
        // Персонаж-фото с лёгким «дыханием».
        AnimatedBuilder(
          animation: _idle,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, -2 + _idle.value * 4),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Image.asset(
              'assets/art/fisherman.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (_, _, _) => CustomPaint(
                painter: _FishermanPainter(spinning: spin),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Слоты -----------------------------------------------------------------

  String _slotTitle(_Slot s, bool spin) => switch (s) {
        _Slot.rod => 'В РУКАХ',
        _Slot.reel => 'КАТУШКА',
        _Slot.line => spin ? 'ШНУР' : 'ЛЕСКА',
        _Slot.hook => 'КРЮЧОК',
        _Slot.bait => spin ? 'ПРИМАНКА' : 'НАЖИВКА',
        _Slot.echo => 'ЭХОЛОТ',
      };

  List<GearCategory> _slotCategories(_Slot s, bool spin) => switch (s) {
        _Slot.rod => [GearCategory.rod, GearCategory.spinningRod],
        _Slot.reel => [
            spin ? GearCategory.spinningReel : GearCategory.floatReel
          ],
        _Slot.line => [spin ? GearCategory.braid : GearCategory.line],
        _Slot.hook => [GearCategory.hook],
        _Slot.bait => [spin ? GearCategory.lure : GearCategory.bait],
        _Slot.echo => [GearCategory.echoSounder],
      };

  GearItem? _equippedItem(
      Map<String, GearItem> byId, Loadout l, _Slot s, bool spin) {
    final id = switch (s) {
      _Slot.rod => spin ? l.spinningRodId : l.rodId,
      _Slot.reel => spin ? l.spinningReelId : l.floatReelId,
      _Slot.line => spin ? l.braidId : l.lineId,
      _Slot.hook => l.hookId,
      _Slot.bait => spin ? l.lureId : l.baitId,
      _Slot.echo => l.echoSounderId,
    };
    return id == null ? null : byId[id];
  }

  Widget _slotCard(_Slot s, GearItem? item, bool spin, List<GearItem> catalog,
      Player player) {
    final qty = item == null
        ? 0
        : player.inventory
            .where((e) => e.gearId == item.id)
            .fold<int>(0, (sum, e) => sum + e.quantity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openSlotPicker(s, spin, catalog),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: kPanelBody,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: item == null
                    ? kGold.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.45)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: kPanelHeader,
                padding:
                    const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_slotTitle(s, spin),
                          style: const TextStyle(
                              color: kGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                    ),
                    Icon(Icons.swap_horiz,
                        size: 13, color: Colors.white.withValues(alpha: 0.4)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: item == null
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFE9E4D8),
                                  Color(0xFFC9C2B2)
                                ],
                              ),
                        color: item == null
                            ? Colors.black.withValues(alpha: 0.3)
                            : null,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: item == null
                                ? kGold.withValues(alpha: 0.5)
                                : gearRarityColor(item.rarity),
                            width: item == null ? 1.2 : 1.8),
                      ),
                      child: item == null
                          ? const Icon(Icons.add, color: kGold, size: 26)
                          : Padding(
                              padding: const EdgeInsets.all(4),
                              child: GearIcon(item.category, size: 44),
                            ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item?.name ?? 'Подобрать…',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color:
                                    item == null ? kGoldLight : Colors.white,
                                fontSize: 12,
                                height: 1.15,
                                fontWeight: FontWeight.w800),
                          ),
                          if (item != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (item.category == GearCategory.rod)
                                  'удочка',
                                if (item.category ==
                                    GearCategory.spinningRod)
                                  'спиннинг',
                                _shortStat(item),
                                if (qty > 1) '×$qty',
                              ].where((x) => x.isNotEmpty).join(' · '),
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.55),
                                  fontSize: 10.5),
                            ),
                          ],
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

  String _shortStat(GearItem g) => switch (g) {
        RodItem(:final maxWeight) =>
          'до ${(maxWeight.grams / 1000).toStringAsFixed(0)} кг',
        ReelItem(:final maxWeight) =>
          'до ${(maxWeight.grams / 1000).toStringAsFixed(0)} кг',
        LineItem(:final maxWeight, :final lengthMeters) =>
          '${(maxWeight.grams / 1000).toStringAsFixed(0)} кг · $lengthMeters м',
        HookItem(:final escapeChance) =>
          'сход ${(escapeChance * 100).round()}%',
        LureItem(:final lureType) => lureType.label,
        EchoSounderItem(:final rangeMeters) => 'до $rangeMeters м',
        PremiumItem(:final days) => '$days дн.',
      };

  // --- Подборщик слота: надеть из рюкзака или купить ---------------------------

  Future<void> _openSlotPicker(
      _Slot s, bool spin, List<GearItem> catalog) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Consumer(builder: (context, ref, _) {
        final player = ref.watch(playerControllerProvider).value;
        if (player == null) return const SizedBox.shrink();
        final cats = _slotCategories(s, spin);
        final ownedIds = {for (final e in player.inventory) e.gearId};
        final equipped =
            _equippedItem({for (final g in catalog) g.id: g},
                player.loadout, s, spin);

        final ownedItems = catalog
            .where((g) => cats.contains(g.category) && ownedIds.contains(g.id))
            .toList();
        final shopItems = catalog
            .where((g) =>
                cats.contains(g.category) &&
                (!ownedIds.contains(g.id) || _isConsumable(g.category)))
            .toList()
          ..sort((a, b) => a.requiredLevel != b.requiredLevel
              ? a.requiredLevel.compareTo(b.requiredLevel)
              : a.price.amount.compareTo(b.price.amount));

        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.72),
          decoration: const BoxDecoration(
            color: kPanelBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: kGold, width: 1.5)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Container(width: 4, height: 18, color: kGold),
                    const SizedBox(width: 8),
                    Text(_slotTitle(s, spin), style: displayStyle(size: 18)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon:
                          const Icon(Icons.close, color: Colors.white60),
                    ),
                  ]),
                ),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    shrinkWrap: true,
                    children: [
                      // Необязательный слот (эхолот) можно освободить.
                      if (s == _Slot.echo && equipped != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () {
                              ref
                                  .read(playerControllerProvider.notifier)
                                  .unequipEcho();
                              Navigator.of(sheetCtx).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE5483B)
                                        .withValues(alpha: 0.6)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.do_not_disturb_on_outlined,
                                      size: 16, color: Color(0xFFE5483B)),
                                  SizedBox(width: 8),
                                  Text('Снять эхолот',
                                      style: TextStyle(
                                          color: Color(0xFFE5483B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (ownedItems.isNotEmpty) ...[
                        _sectionLabel('В РЮКЗАКЕ — экипировать'),
                        for (final g in ownedItems)
                          _pickerTile(
                            sheetCtx,
                            g,
                            player,
                            equipped: equipped?.id == g.id,
                            owned: true,
                          ),
                        const SizedBox(height: 8),
                      ],
                      if (!widget.shopAllowed) ...[
                        if (ownedItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                                'В рюкзаке пусто. Покупки недоступны на воде — '
                                'вернись на берег.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12.5)),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Покупки недоступны на воде — только замена.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11)),
                          ),
                      ] else ...[
                        _sectionLabel(ownedItems.isEmpty
                            ? 'В РЮКЗАКЕ ПУСТО — купи и экипируй'
                            : 'МАГАЗИН — купить и экипировать'),
                        if (shopItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('Новинок для этого слота пока нет.',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12)),
                          )
                        else
                          for (final g in shopItems)
                            _pickerTile(
                              sheetCtx,
                              g,
                              player,
                              equipped: false,
                              owned: false,
                            ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 7),
        child: Text(text,
            style: TextStyle(
                color: kGold.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7)),
      );

  static bool _isConsumable(GearCategory c) =>
      c == GearCategory.bait ||
      c == GearCategory.groundbait ||
      c == GearCategory.spray ||
      c == GearCategory.energy;

  Widget _pickerTile(BuildContext sheetCtx, GearItem g, Player player,
      {required bool equipped, required bool owned}) {
    final qty = player.inventory
        .where((e) => e.gearId == g.id)
        .fold<int>(0, (sum, e) => sum + e.quantity);
    final levelOk = player.level >= g.requiredLevel;
    final affordable = player.wallet.canAfford(g.price);
    final isGoldPrice = g.price.type == CurrencyType.gold;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        // Тап по строке — осмотр со шкалами и сравнением с экипированным.
        onTap: () => showGearDetail(context,
            item: g, allowBuy: widget.shopAllowed, allowEquip: true),
        borderRadius: BorderRadius.circular(10),
        child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: equipped
              ? kGold.withValues(alpha: 0.13)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: equipped ? kGold : Colors.white12,
              width: equipped ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE9E4D8), Color(0xFFC9C2B2)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: gearRarityColor(g.rarity), width: 1.8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: GearIcon(g.category, size: 40),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (g.category == GearCategory.rod) 'удочка',
                      if (g.category == GearCategory.spinningRod) 'спиннинг',
                      _shortStat(g),
                      if (owned && qty > 0) '×$qty',
                      if (!owned && g.requiredLevel > 1)
                        'ур. ${g.requiredLevel}',
                    ].where((x) => x.isNotEmpty).join(' · '),
                    style: TextStyle(
                        color: !owned && !levelOk
                            ? const Color(0xFFE5483B)
                            : Colors.white.withValues(alpha: 0.55),
                        fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (equipped)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.check_circle, color: kGold, size: 20),
              )
            else if (owned)
              GoldButton(
                label: 'Экипировать',
                onTap: () async {
                  await ref
                      .read(playerControllerProvider.notifier)
                      .equip(g);
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  _toast('Экипировано: ${g.name}');
                },
              )
            else
              GoldButton(
                label: g.price.amount == 0
                    ? 'Взять'
                    : '${isGoldPrice ? '💎' : '🪙'} ${g.price.amount}',
                enabled: levelOk && affordable,
                onTap: () async {
                  final notifier =
                      ref.read(playerControllerProvider.notifier);
                  final res = await notifier.purchase(g);
                  if (res == PurchaseResult.ok) {
                    await notifier.equip(g);
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    _toast('Куплено и экипировано: ${g.name}');
                  } else {
                    _toast(switch (res) {
                      PurchaseResult.notEnoughMoney =>
                        'Недостаточно средств',
                      PurchaseResult.levelTooLow =>
                        'Нужен уровень ${g.requiredLevel}',
                      PurchaseResult.alreadyOwned => 'Уже куплено',
                      _ => 'Не удалось купить',
                    });
                  }
                },
              ),
          ],
        ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
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

// ---------------------------------------------------------------------------
// Персонаж.
// ---------------------------------------------------------------------------

/// Рыбак в забродном костюме: кепка, борода, куртка с воротником, лямки,
/// высокие сапоги; удилище в двух руках. Подиум с золотым свечением.
class _FishermanPainter extends CustomPainter {
  _FishermanPainter({required this.spinning});

  final bool spinning;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final scale = math.min(w / 240, h / 320);
    canvas.translate(w / 2, h * 0.54);
    canvas.scale(scale);

    // Палитра.
    const jacket = Color(0xFF2E4636); // оливковая куртка
    const jacketDark = Color(0xFF223427);
    const waders = Color(0xFF20262E); // забродный полукомбинезон
    const wadersDark = Color(0xFF161B21);
    const skin = Color(0xFFC09068);
    const beard = Color(0xFF6E5B45);
    const cap = Color(0xFF1B2228);

    // Свечение и подиум.
    canvas.drawCircle(
        const Offset(0, -20),
        130,
        Paint()
          ..color = kGold.withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 148), width: 190, height: 34),
        Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 144), width: 170, height: 28),
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0xFF2A3036),
            Color(0xFF14181D),
          ]).createShader(Rect.fromCenter(
              center: const Offset(0, 144), width: 170, height: 28)));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 144), width: 170, height: 28),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = kGold.withValues(alpha: 0.4));

    // --- Ноги-сапоги (заброды). ---
    Path leg(double cx) => Path()
      ..moveTo(cx - 12, 38)
      ..lineTo(cx - 13, 120)
      ..quadraticBezierTo(cx - 13, 134, cx + 2, 134)
      ..lineTo(cx + 14, 134)
      ..quadraticBezierTo(cx + 18, 134, cx + 17, 126)
      ..lineTo(cx + 13, 120)
      ..lineTo(cx + 12, 38)
      ..close();
    canvas.drawPath(leg(-16), Paint()..color = waders);
    canvas.drawPath(leg(18), Paint()..color = waders);
    // Отвороты сапог.
    for (final cx in [-16.0, 18.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 14, 92, 28, 10), const Radius.circular(3)),
          Paint()..color = wadersDark);
    }

    // --- Корпус: полукомбинезон + куртка. ---
    final torso = Path()
      ..moveTo(-30, -34)
      ..quadraticBezierTo(-36, 6, -28, 44)
      ..lineTo(28, 44)
      ..quadraticBezierTo(36, 6, 30, -34)
      ..quadraticBezierTo(0, -44, -30, -34)
      ..close();
    canvas.drawPath(torso, Paint()..color = jacket);
    // Нагрудник забродов поверх низа куртки.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-22, 6, 44, 40), const Radius.circular(6)),
        Paint()..color = waders);
    // Лямки.
    final strap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = wadersDark;
    canvas.drawLine(const Offset(-14, -30), const Offset(-14, 10), strap);
    canvas.drawLine(const Offset(14, -30), const Offset(14, 10), strap);
    for (final dx in [-14.0, 14.0]) {
      canvas.drawCircle(Offset(dx, 8), 2.6, Paint()..color = kGold);
    }
    // Воротник куртки.
    final collar = Path()
      ..moveTo(-16, -40)
      ..lineTo(0, -28)
      ..lineTo(16, -40)
      ..lineTo(10, -46)
      ..lineTo(-10, -46)
      ..close();
    canvas.drawPath(collar, Paint()..color = jacketDark);
    // Карман на нагруднике.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-12, 16, 24, 16), const Radius.circular(4)),
        Paint()..color = wadersDark);

    // --- Руки: правая поперёк к комлю, левая поддерживает бланк. ---
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = jacket;
    // Правая (от правого плеча к комлю слева-внизу).
    canvas.drawLine(const Offset(24, -24), const Offset(-18, 16), arm);
    // Левая (от левого плеча вперёд-вверх к бланку).
    canvas.drawLine(const Offset(-24, -22), const Offset(22, -34), arm);
    // Кисти.
    canvas.drawCircle(const Offset(-18, 16), 7, Paint()..color = skin);
    canvas.drawCircle(const Offset(22, -34), 7, Paint()..color = skin);

    // --- Голова: кепка с козырьком, борода. ---
    canvas.drawCircle(const Offset(0, -62), 16, Paint()..color = skin);
    // Борода.
    final beardPath = Path()
      ..moveTo(-12, -60)
      ..quadraticBezierTo(-13, -44, 0, -42)
      ..quadraticBezierTo(13, -44, 12, -60)
      ..quadraticBezierTo(0, -52, -12, -60)
      ..close();
    canvas.drawPath(beardPath, Paint()..color = beard);
    // Кепка.
    canvas.drawArc(Rect.fromCircle(center: const Offset(0, -66), radius: 16),
        math.pi, math.pi, true, Paint()..color = cap);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -72, 26, 7), const Radius.circular(3)),
        Paint()..color = cap);
    // Глаз (профиль в три четверти).
    canvas.drawCircle(const Offset(6, -62), 1.7,
        Paint()..color = const Color(0xFF20262C));

    // --- Удилище в руках (диагональ), катушка, леска. ---
    final rodButt = const Offset(-26, 24);
    final rodTip =
        spinning ? const Offset(98, -128) : const Offset(108, -162);
    // Бланк с лёгким изгибом.
    final rodPath = Path()
      ..moveTo(rodButt.dx, rodButt.dy)
      ..quadraticBezierTo((rodButt.dx + rodTip.dx) / 2 + 8,
          (rodButt.dy + rodTip.dy) / 2 + 6, rodTip.dx, rodTip.dy);
    canvas.drawPath(
        rodPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF6E563A));
    // Рукоять.
    canvas.drawLine(
        rodButt,
        Offset.lerp(rodButt, rodTip, 0.16)!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF3A2E1E));
    // Кольца.
    for (final t in [0.40, 0.62, 0.84]) {
      final p = Offset.lerp(rodButt, rodTip, t)!;
      canvas.drawCircle(
          p + const Offset(2.5, 3.5),
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = kGold.withValues(alpha: 0.8));
    }
    // Катушка под бланком у кисти.
    final reelC = const Offset(-6, 12);
    canvas.drawCircle(reelC, 8.5, Paint()..color = const Color(0xFF39424C));
    canvas.drawCircle(
        reelC,
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = kGold.withValues(alpha: 0.7));
    canvas.drawCircle(reelC, 3.4, Paint()..color = const Color(0xFFC9CDD2));
    // Леска от кончика вниз.
    canvas.drawLine(
        rodTip,
        Offset(rodTip.dx + 5, 76),
        Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.45));
    if (spinning) {
      final lure = Offset(rodTip.dx + 5, 70);
      canvas.drawOval(
          Rect.fromCenter(center: lure, width: 7, height: 13),
          Paint()..color = kGold);
    } else {
      final fl = Offset(rodTip.dx + 5, 64);
      canvas.drawOval(Rect.fromCenter(center: fl, width: 8, height: 16),
          Paint()..color = const Color(0xFFE5483B));
      canvas.drawLine(
          fl - const Offset(0, 12),
          fl - const Offset(0, 20),
          Paint()
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFEFE7DA));
    }

    // Золотой контурный свет слева.
    canvas.drawPath(
        torso,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = kGold.withValues(alpha: 0.22));
  }

  @override
  bool shouldRepaint(covariant _FishermanPainter old) =>
      old.spinning != spinning;
}
