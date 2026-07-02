import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/gear.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/fishing_enums.dart';
import '../../shared/rendering/gear_icons.dart';
import '../shell/ui_kit.dart';
import 'gear_stats.dart';

/// Открывает карточку-деталь предмета: иконка, описание, шкалы характеристик
/// со сравнением с уже экипированным (зелёное — лучше, красное — хуже) и
/// действие (купить / надеть) в зависимости от контекста.
Future<void> showGearDetail(
  BuildContext context, {
  required GearItem item,
  bool allowBuy = true,
  bool allowEquip = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        _GearDetailSheet(item: item, allowBuy: allowBuy, allowEquip: allowEquip),
  );
}

class _GearDetailSheet extends ConsumerWidget {
  const _GearDetailSheet({
    required this.item,
    required this.allowBuy,
    required this.allowEquip,
  });

  final GearItem item;
  final bool allowBuy;
  final bool allowEquip;

  static bool _consumable(GearCategory c) =>
      c == GearCategory.bait ||
      c == GearCategory.groundbait ||
      c == GearCategory.spray ||
      c == GearCategory.energy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider).value;
    final stats = ref.watch(gearStatsProvider);
    final catalog = ref.watch(gearCatalogProvider).value ?? const [];
    final byId = {for (final g in catalog) g.id: g};

    final rc = gearRarityColor(item.rarity);
    final itemStats = stats?.statsFor(item) ?? const [];
    final echo = item is EchoSounderItem ? item as EchoSounderItem : null;
    final feats =
        echo == null ? gearFeatures(item) : const <(IconData, String)>[];

    // С чем сравниваем — предмет того же слота из лоадаута.
    GearItem? equipped;
    if (player != null) {
      final id = equippedIdForCategory(player.loadout, item.category);
      if (id != null && id != item.id) equipped = byId[id];
    }
    final eqStats = equipped == null ? null : stats?.statsFor(equipped);
    final isEquipped = player != null &&
        equippedIdForCategory(player.loadout, item.category) == item.id;

    final owned = player != null && player.inventory.any((e) => e.gearId == item.id);
    final qty = player == null
        ? 0
        : player.inventory
            .where((e) => e.gearId == item.id)
            .fold<int>(0, (s, e) => s + e.quantity);
    final consumable = _consumable(item.category);
    final levelOk = player != null && player.level >= item.requiredLevel;
    final affordable = player != null && player.wallet.canAfford(item.price);

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: kPanelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Шапка: нейтральный фон + тонкий акцент редкости снизу.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                decoration: BoxDecoration(
                  color: kPanelHeader,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(bottom: BorderSide(color: rc, width: 2.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE9E4D8), Color(0xFFC9C2B2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: rc, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: GearIcon(item.category, size: 54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.name, style: displayStyle(size: 19)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rc.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: rc),
                            ),
                            child: Text(gearRarityLabel(item.rarity),
                                style: TextStyle(
                                    color: rc,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  shrinkWrap: true,
                  children: [
                    Text(item.description,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4)),
                    // Возможности эхолота: чем дороже модель, тем больше умеет.
                    if (echo != null) ...[
                      const SizedBox(height: 14),
                      const Text('ВОЗМОЖНОСТИ',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 9),
                      _capRow(Icons.wifi_tethering,
                          'Дальность луча — ${echo.rangeMeters} м'),
                      for (final cap in SounderCapability.values
                          .where(echo.capabilities.contains))
                        _capRow(capabilityInfo(cap).$1, capabilityInfo(cap).$2),
                    ] else if (feats.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('ОСОБЕННОСТИ',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 9),
                      for (final f in feats) _capRow(f.$1, f.$2),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      const Text('ХАРАКТЕРИСТИКИ',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                      const Spacer(),
                      if (equipped != null)
                        Flexible(
                          child: Text('сравнение с: ${equipped.name}',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: kGold.withValues(alpha: 0.8),
                                  fontSize: 10.5)),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    for (final st in itemStats)
                      _StatBarRow(stat: st, equipped: _match(eqStats, st.key)),
                    if (isEquipped)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: const [
                          Icon(Icons.check_circle, size: 15, color: kGold),
                          SizedBox(width: 6),
                          Text('Сейчас экипировано',
                              style: TextStyle(
                                  color: kGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    if (item.requiredLevel > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(children: [
                          Icon(Icons.military_tech,
                              size: 14,
                              color: levelOk
                                  ? Colors.white54
                                  : const Color(0xFFE5483B)),
                          const SizedBox(width: 6),
                          Text('Требуемый уровень: ${item.requiredLevel}',
                              style: TextStyle(
                                  color: levelOk
                                      ? Colors.white54
                                      : const Color(0xFFE5483B),
                                  fontSize: 12)),
                        ]),
                      ),
                  ],
                ),
              ),
              // Действие.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _action(context, ref,
                    owned: owned,
                    consumable: consumable,
                    isEquipped: isEquipped,
                    levelOk: levelOk,
                    affordable: affordable,
                    qty: qty),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GearStat? _match(List<GearStat>? list, String key) {
    if (list == null) return null;
    for (final s in list) {
      if (s.key == key) return s;
    }
    return null;
  }

  Widget _action(BuildContext context, WidgetRef ref,
      {required bool owned,
      required bool consumable,
      required bool isEquipped,
      required bool levelOk,
      required bool affordable,
      required int qty}) {
    final isGold = item.price.type == CurrencyType.gold;
    final priceLabel = item is PremiumItem
        ? 'Активировать · ${isGold ? '💎' : '🪙'} ${item.price.amount}'
        : item.price.amount == 0
            ? 'Получить'
            : 'Купить · ${isGold ? '💎' : '🪙'} ${item.price.amount}';

    // Снаряжение: можно надеть из рюкзака.
    if (allowEquip && owned && !isEquipped) {
      return SizedBox(
        width: double.infinity,
        child: GoldButton(
          label: 'Экипировать',
          icon: Icons.checklist_rtl,
          onTap: () async {
            await ref.read(playerControllerProvider.notifier).equip(item);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      );
    }
    if (isEquipped) {
      return const SizedBox(
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Экипировано',
                style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
        ),
      );
    }
    if (owned && !consumable && !allowBuy) {
      return const SizedBox(
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('В рюкзаке',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ),
      );
    }
    if (!allowBuy) {
      return const SizedBox(
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Покупки доступны только на берегу',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ),
      );
    }
    // Покупка (магазин). Купленное снаряжение в пикере сразу надеваем.
    return SizedBox(
      width: double.infinity,
      child: GoldButton(
        label: owned && !consumable ? 'В рюкзаке' : priceLabel,
        icon: Icons.shopping_bag,
        enabled: levelOk && affordable && !(owned && !consumable),
        onTap: () async {
          if (!await confirmPurchase(context, item)) return;
          if (!context.mounted) return;
          final n = ref.read(playerControllerProvider.notifier);
          final res = await n.purchase(item);
          if (res == PurchaseResult.ok && allowEquip && item is! PremiumItem) {
            await n.equip(item);
          }
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _toast(
              context,
              switch (res) {
                PurchaseResult.ok when item is PremiumItem =>
                  'Премиум активирован',
                PurchaseResult.ok => 'Куплено: ${item.name}',
                PurchaseResult.notEnoughMoney => 'Недостаточно средств',
                PurchaseResult.levelTooLow =>
                  'Нужен уровень ${item.requiredLevel}',
                PurchaseResult.alreadyOwned => 'Уже куплено',
                PurchaseResult.error => 'Не удалось купить',
              });
        },
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
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

/// Строка шкалы: подпись, дорожка с заполнением и маркером экипированного,
/// значение и цветная дельта (▲ лучше / ▼ хуже).
class _StatBarRow extends StatelessWidget {
  const _StatBarRow({required this.stat, this.equipped});

  final GearStat stat;
  final GearStat? equipped;

  @override
  Widget build(BuildContext context) {
    String? deltaText;
    Color deltaColor = Colors.white54;
    IconData? deltaIcon;
    if (equipped != null && !stat.neutral) {
      final d = stat.raw - equipped!.raw;
      if (d.abs() > 1e-6) {
        final better = (d > 0) == stat.higherBetter;
        deltaColor =
            better ? const Color(0xFF5FB85F) : const Color(0xFFE5483B);
        deltaIcon = better ? Icons.arrow_drop_up : Icons.arrow_drop_down;
        if (stat.key == 'hold') {
          deltaText = better ? 'надёжнее' : 'слабее';
        } else {
          final shown = stat.key == 'smooth' ? d * 100 : d;
          final mag = shown.abs();
          final numStr = mag < 1
              ? mag.toStringAsFixed(2)
              : mag.round().toString();
          deltaText = '$numStr ${stat.unit}'.trim();
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12)),
              ),
              Text(stat.display,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
              if (deltaText != null) ...[
                const SizedBox(width: 8),
                Icon(deltaIcon, size: 16, color: deltaColor),
                Text(deltaText,
                    style: TextStyle(
                        color: deltaColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
              ],
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 9,
              child: Stack(children: [
                // Дорожка.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const SizedBox.expand(),
                ),
                // Заполнение.
                FractionallySizedBox(
                  widthFactor: stat.value01,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [kGoldLight, kGold]),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                // Маркер значения экипированного предмета.
                if (equipped != null)
                  Positioned(
                    left: (w * equipped!.value01 - 1).clamp(0.0, w - 2),
                    top: -2,
                    bottom: -2,
                    child: Container(
                      width: 2.4,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

/// Иконка и человекочитаемое описание возможности эхолота.
(IconData, String) capabilityInfo(SounderCapability c) => switch (c) {
      SounderCapability.depthReadout =>
        (Icons.straighten, 'Точная глубина в точке заброса'),
      SounderCapability.bottomProfile => (Icons.terrain, 'Профиль дна'),
      SounderCapability.fishArches => (Icons.set_meal, 'Дуги рыбы (стаи в зоне)'),
      SounderCapability.fishIdHint =>
        (Icons.straighten, 'Крупность рыбы по размеру дуги'),
      SounderCapability.biteIndicator =>
        (Icons.notifications_active, 'Индикатор жора'),
      SounderCapability.bestDepthHint =>
        (Icons.gps_fixed, 'Подсказка лучшей глубины'),
      SounderCapability.temperature => (Icons.thermostat, 'Температура воды'),
      SounderCapability.thermocline => (Icons.layers, 'Термоклин (слой скачка)'),
      SounderCapability.zoom => (Icons.zoom_in, 'Зум придонного слоя'),
      SounderCapability.depthAlarm =>
        (Icons.alarm, 'Сигнализатор глубины'),
      SounderCapability.gpsMarks => (Icons.push_pin, 'Метки точек (GPS)'),
      SounderCapability.structureScan =>
        (Icons.grain, 'Структура дна (коряги/камни)'),
      SounderCapability.liveScope =>
        (Icons.sensors, 'Живой сонар в реальном времени'),
      SounderCapability.weightTag =>
        (Icons.scale, 'Подпись веса рыбы цифрами'),
      SounderCapability.weightAlarm =>
        (Icons.notifications_active, 'Сигнал по весу: задаёшь диапазон — маячок'),
    };

/// Качественные «особенности» прочих снастей (то, что отличает их помимо
/// числовых шкал). Пусто — если у предмета нет особых отличий.
List<(IconData, String)> gearFeatures(GearItem item) {
  switch (item) {
    case RodItem r:
      final spin = r.category == GearCategory.spinningRod;
      return [
        spin
            ? (Icons.bolt, 'Спиннинг: ловля хищника на проводке приманки')
            : (Icons.water_drop,
                'Поплавочная снасть: деликатная подача, мирная рыба'),
        (Icons.fitness_center, 'Комфортная рыба — до ${r.maxWeight.formatted}'),
      ];
    case ReelItem rl:
      return [
        (Icons.donut_large,
            'Плавный ход: мягче зона удержания при вываживании'),
        (Icons.fitness_center,
            'Уверенно тянет рыбу до ${rl.maxWeight.formatted}'),
      ];
    case LineItem l:
      final braid = l.category == GearCategory.braid;
      return [
        braid
            ? (Icons.show_chart,
                'Плетёный шнур: не тянется, выше чувствительность и прочность')
            : (Icons.waves, 'Монолеска: тянется и прощает рывки рыбы'),
        (Icons.straighten, 'Разрывная нагрузка — до ${l.maxWeight.formatted}'),
        (Icons.timeline, 'Запас на катушке — ${l.lengthMeters} м'),
      ];
    case HookItem h:
      return [
        (
          Icons.phishing,
          h.escapeChance < 0.12
              ? 'Острый и цепкий — рыба почти не сходит'
              : 'Надёжное засекание рыбы',
        ),
      ];
    case LureItem lr:
      switch (lr.category) {
        case GearCategory.groundbait:
          return [
            (
              Icons.check_circle_outline,
              lr.targetGroups.isEmpty
                  ? 'Подходит для: всех семейств водоёма'
                  : 'Подходит для: ${lr.targetGroups.join(', ')}'
            ),
            (Icons.trending_up,
                'Повышает шанс вылова этих рыб, пока действует'),
            (Icons.timer, 'Время действия — ${lr.chumSeconds} с'),
            (Icons.inventory_2, 'Расходник — используется на воде'),
          ];
        case GearCategory.energy:
          return const [
            (Icons.bolt, 'Перекус — восстанавливает энергию рыбака'),
            (Icons.inventory_2, 'Расходник — съедается на воде'),
          ];
        case GearCategory.spray:
          return const [
            (Icons.shield, 'Защита от насекомых на берегу'),
          ];
        default:
          final isLure = lr.category == GearCategory.lure;
          return [
            (Icons.category, 'Тип — ${lr.lureType.label}'),
            isLure
                ? (Icons.bolt,
                    'Искусственная приманка: для хищника, играет на проводке')
                : (Icons.grass, 'Наживка: привлекает мирную рыбу'),
            (Icons.inventory_2, 'Расходник — запас тратится на забросах'),
          ];
      }
    case PremiumItem p:
      return [
        (Icons.schedule, 'Срок действия — ${p.days} дн.'),
        (Icons.savings, '×2 серебро и опыт за каждый улов'),
        if (p.tier >= 2) (Icons.bolt, 'Активнее клёв: +15% к шансу поклёвки'),
        if (p.tier >= 3) (Icons.eco, 'Наживка расходуется вдвое реже'),
      ];
    case EchoSounderItem _:
      return const [];
  }
}

/// Строка возможности эхолота: иконка + текст.
Widget _capRow(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Icon(icon, size: 15, color: kGold),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ),
      ]),
    );

/// Подтверждение покупки (бесплатное — без вопроса). true — покупать.
Future<bool> confirmPurchase(BuildContext context, GearItem item) async {
  if (item.price.amount == 0) return true;
  final isGold = item.price.type == CurrencyType.gold;
  final premium = item is PremiumItem;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: HeaderPanel(
          header: premium ? 'Активировать премиум' : 'Покупка',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                premium
                    ? 'Активировать «${item.name}»?'
                    : 'Купить «${item.name}»?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isGold ? Icons.diamond : Icons.monetization_on,
                    size: 18, color: kGold),
                const SizedBox(width: 6),
                Text('${item.price.amount}',
                    style: const TextStyle(
                        color: kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GoldButton(
                    label: premium ? 'Активировать' : 'Купить',
                    icon: Icons.check,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Отмена',
                      style: TextStyle(color: Colors.white60)),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}
