import '../value_objects/currency.dart';
import '../value_objects/fishing_enums.dart';
import '../value_objects/weight.dart';

/// Редкость предмета: окраска рамки, эффективность и цена растут вместе.
enum GearRarity { common, uncommon, rare, epic, legendary }

/// Возможности эхолота — флаги. Класс эхолота определяется набором флагов,
/// поэтому новые модели добавляются данными, без правок движка отрисовки.
enum SounderCapability {
  depthReadout, // число глубины в точке заброса
  bottomProfile, // профиль дна по лучу
  fishArches, // силуэты/дуги стай рыбы
  fishIdHint, // крупность рыбы видна по размеру дуги
  biteIndicator, // индикатор «жора»
  bestDepthHint, // подсветка лучшей глубины
  temperature, // температура воды
  thermocline, // слой термоклина
  zoom, // увеличение придонного участка
  depthAlarm, // сигнализатор глубины
  gpsMarks, // точки/маркеры мест
  structureScan, // структура дна (коряги/камни)
  liveScope, // живой сонар в реальном времени
  weightTag, // подпись приблизительного веса у дуг (топовые модели)
  weightAlarm, // сигнализатор по диапазону веса рыбы (топовые модели)
}

/// Каталожная характеристика предмета (определение в магазине).
/// Это НЕ владеемый экземпляр — runtime‑состояние (прочность, остаток, кол‑во)
/// живёт в [InventoryEntry].
sealed class GearItem {
  const GearItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.requiredLevel,
    this.rarity = GearRarity.common,
    this.iconAsset,
  });

  final String id;
  final String name;
  final String description;
  final GearCategory category;
  final Money price;
  final int requiredLevel;
  final GearRarity rarity;
  final String? iconAsset;

  /// Общие поля + дискриминатор [type] для восстановления подкласса.
  Map<String, dynamic> baseJson(String type) => {
        'type': type,
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'price': price.toJson(),
        'requiredLevel': requiredLevel,
        'rarity': rarity.name,
        'iconAsset': iconAsset,
      };

  Map<String, dynamic> toJson();

  static GearItem fromJson(Map<String, dynamic> j) {
    final cat = GearCategory.values.asNameMap()[j['category']] ??
        GearCategory.rod;
    final price = Money.fromJson(
        Map<String, Object?>.from((j['price'] as Map?) ?? const {}));
    final rarity =
        GearRarity.values.asNameMap()[j['rarity']] ?? GearRarity.common;
    final id = (j['id'] ?? '') as String;
    final name = (j['name'] ?? '') as String;
    final desc = (j['description'] ?? '') as String;
    final level = (j['requiredLevel'] as num?)?.toInt() ?? 1;
    final icon = j['iconAsset'] as String?;
    int grams(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    double dbl(String k, double d) => (j[k] as num?)?.toDouble() ?? d;

    switch (j['type']) {
      case 'reel':
        return ReelItem(
            id: id, name: name, description: desc, category: cat,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            maxWeight: Weight.grams(grams('maxWeight', 3000)),
            smoothness: dbl('smoothness', 0.5));
      case 'line':
        return LineItem(
            id: id, name: name, description: desc, category: cat,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            lengthMeters: grams('lengthMeters', 100),
            maxWeight: Weight.grams(grams('maxWeight', 3000)));
      case 'hook':
        return HookItem(
            id: id, name: name, description: desc,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            escapeChance: dbl('escapeChance', 0.15));
      case 'lure':
        return LureItem(
            id: id, name: name, description: desc, category: cat,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            lureType: LureType.fromCode((j['lureType'] ?? 'worm') as String),
            size: LureSize.values.asNameMap()[j['size']] ?? LureSize.medium,
            color:
                LureColor.values.asNameMap()[j['color']] ?? LureColor.natural,
            targetGroups: [
              for (final g in (j['targetGroups'] as List? ?? const []))
                g as String,
            ],
            chumSeconds: grams('chumSeconds', 45));
      case 'echo':
        return EchoSounderItem(
            id: id, name: name, description: desc,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            capabilities: {
              for (final c in (j['capabilities'] as List? ?? const []))
                if (SounderCapability.values.asNameMap()[c] != null)
                  SounderCapability.values.asNameMap()[c]!,
            },
            rangeMeters: grams('rangeMeters', 10));
      case 'premium':
        return PremiumItem(
            id: id, name: name, description: desc,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            days: grams('days', 7),
            tier: grams('tier', 1));
      default: // 'rod' и всё нераспознанное
        return RodItem(
            id: id, name: name, description: desc, category: cat,
            price: price, requiredLevel: level, rarity: rarity,
            iconAsset: icon,
            maxWeight: Weight.grams(grams('maxWeight', 3000)));
    }
  }
}

/// Удилище (поплавочное) или спиннинг — различаются [GearCategory].
class RodItem extends GearItem {
  const RodItem({
    required super.id,
    required super.name,
    required super.description,
    required super.category,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.maxWeight,
  });

  /// Комфортная масса рыбы; сверх неё прочность падает быстрее (порог 80%).
  final Weight maxWeight;

  @override
  Map<String, dynamic> toJson() =>
      baseJson('rod')..['maxWeight'] = maxWeight.grams;
}

/// Катушка (для удочки или спиннинга).
class ReelItem extends GearItem {
  const ReelItem({
    required super.id,
    required super.name,
    required super.description,
    required super.category,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.maxWeight,
    required this.smoothness,
  });

  final Weight maxWeight;

  /// 0..1 — мягкость хода полосы вываживания (лучше катушка → плавнее QTE).
  final double smoothness;

  @override
  Map<String, dynamic> toJson() => baseJson('reel')
    ..['maxWeight'] = maxWeight.grams
    ..['smoothness'] = smoothness;
}

/// Леска или плетёный шнур — различаются [GearCategory].
class LineItem extends GearItem {
  const LineItem({
    required super.id,
    required super.name,
    required super.description,
    required super.category,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.lengthMeters,
    required this.maxWeight,
  });

  final int lengthMeters;
  final Weight maxWeight;

  @override
  Map<String, dynamic> toJson() => baseJson('line')
    ..['lengthMeters'] = lengthMeters
    ..['maxWeight'] = maxWeight.grams;
}

/// Крючок — только для поплавочной снасти.
class HookItem extends GearItem {
  const HookItem({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.escapeChance,
  }) : super(category: GearCategory.hook);

  /// 0..1 — шанс схода рыбы (без обрыва/потери приманки).
  final double escapeChance;

  @override
  Map<String, dynamic> toJson() =>
      baseJson('hook')..['escapeChance'] = escapeChance;
}

/// Наживка или приманка — расходник. Тип/размер/цвет идут в алгоритм поклёвки.
class LureItem extends GearItem {
  const LureItem({
    required super.id,
    required super.name,
    required super.description,
    required super.category,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.lureType,
    required this.size,
    required this.color,
    this.targetGroups = const [],
    this.chumSeconds = 45,
  });

  final LureType lureType;
  final LureSize size;
  final LureColor color;

  /// Для прикормки: какие биологические семейства приваживает (пусто —
  /// универсальная, для всех). На воде сильно повышает шанс вылова видов
  /// этих семейств — см. «Подходит для:» в карточке.
  final List<String> targetGroups;

  /// Длительность действия прикормки в секундах.
  final int chumSeconds;

  @override
  Map<String, dynamic> toJson() => baseJson('lure')
    ..['lureType'] = lureType.code
    ..['size'] = size.name
    ..['color'] = color.name
    ..['targetGroups'] = targetGroups
    ..['chumSeconds'] = chumSeconds;
}

/// Эхолот — отдельная ветка снаряжения (ключевая фича осознанной ловли).
class EchoSounderItem extends GearItem {
  const EchoSounderItem({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.capabilities,
    required this.rangeMeters,
  }) : super(category: GearCategory.echoSounder);

  final Set<SounderCapability> capabilities;

  /// Глубина прокачки/дальность луча (м) — насколько глубоко «видит».
  final int rangeMeters;

  bool can(SounderCapability c) => capabilities.contains(c);

  @override
  Map<String, dynamic> toJson() => baseJson('echo')
    ..['capabilities'] = [for (final c in capabilities) c.name]
    ..['rangeMeters'] = rangeMeters;
}

/// Премиум-подписка. Не кладётся в инвентарь: покупка сразу активирует
/// бонусы на [days] дней. Чем выше [tier], тем больше эффектов:
/// 1 — ×2 серебро/опыт; 2 — + клёв активнее (+15% к шансу);
/// 3 — + наживка расходуется вдвое реже.
class PremiumItem extends GearItem {
  const PremiumItem({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.requiredLevel,
    super.rarity,
    super.iconAsset,
    required this.days,
    required this.tier,
  }) : super(category: GearCategory.premium);

  final int days;
  final int tier;

  @override
  Map<String, dynamic> toJson() => baseJson('premium')
    ..['days'] = days
    ..['tier'] = tier;
}
