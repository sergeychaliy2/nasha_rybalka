import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/player.dart';
import '../../domain/value_objects/fishing_enums.dart';

/// Одна характеристика предмета: подпись, сырое значение (для дельты),
/// заполнение шкалы 0..1 (нормировано по лучшему в своей категории),
/// текст и направление «больше = лучше».
class GearStat {
  const GearStat(
    this.key,
    this.label,
    this.raw,
    this.value01,
    this.display, {
    this.higherBetter = true,
    this.neutral = false,
    this.unit = '',
  });

  final String key;
  final String label;
  final double raw;
  final double value01;
  final String display;
  final bool higherBetter;
  final bool neutral; // не красить дельту (нейтральная характеристика)
  final String unit;
}

/// Считает характеристики предметов и нормирует шкалы по максимуму в своей
/// категории (чтобы шкала «топового» предмета была почти полной).
class GearStatsModel {
  GearStatsModel(this._max);

  final Map<String, double> _max; // "$category|$metric" → максимум

  factory GearStatsModel.fromCatalog(List<GearItem> catalog) {
    final max = <String, double>{};
    void bump(GearItem g, String metric, double v) {
      final k = '${g.category.name}|$metric';
      if (v > (max[k] ?? 0)) max[k] = v;
    }

    for (final g in catalog) {
      switch (g) {
        case RodItem():
          bump(g, 'load', g.maxWeight.kilograms);
        case ReelItem():
          bump(g, 'load', g.maxWeight.kilograms);
          bump(g, 'smooth', g.smoothness);
        case LineItem():
          bump(g, 'load', g.maxWeight.kilograms);
          bump(g, 'length', g.lengthMeters.toDouble());
        case HookItem():
          bump(g, 'hold', 1 - g.escapeChance);
        case LureItem():
          bump(g, 'size', _sizeVal(g.size));
        case EchoSounderItem():
          bump(g, 'range', g.rangeMeters.toDouble());
          bump(g, 'vision', g.capabilities.length.toDouble());
        case PremiumItem():
          bump(g, 'days', g.days.toDouble());
          bump(g, 'tier', g.tier.toDouble());
      }
    }
    return GearStatsModel(max);
  }

  double _normMax(GearItem g, String metric) {
    final m = _max['${g.category.name}|$metric'] ?? 1;
    return m <= 0 ? 1 : m;
  }

  List<GearStat> statsFor(GearItem g) {
    GearStat bar(String key, String label, double raw, String display,
            {bool higherBetter = true, bool neutral = false, String unit = ''}) =>
        GearStat(key, label, raw, (raw / _normMax(g, key)).clamp(0.04, 1.0),
            display,
            higherBetter: higherBetter, neutral: neutral, unit: unit);

    switch (g) {
      case RodItem():
        return [
          bar('load', 'Тест (нагрузка)', g.maxWeight.kilograms,
              '${g.maxWeight.kilograms.toStringAsFixed(0)} кг',
              unit: 'кг'),
        ];
      case ReelItem():
        return [
          bar('load', 'Тяга', g.maxWeight.kilograms,
              '${g.maxWeight.kilograms.toStringAsFixed(0)} кг',
              unit: 'кг'),
          bar('smooth', 'Плавность фрикциона', g.smoothness,
              '${(g.smoothness * 100).round()} %', unit: '%'),
        ];
      case LineItem():
        return [
          bar('load', 'Разрывная нагрузка', g.maxWeight.kilograms,
              '${g.maxWeight.kilograms.toStringAsFixed(0)} кг',
              unit: 'кг'),
          bar('length', 'Метраж', g.lengthMeters.toDouble(),
              '${g.lengthMeters} м', unit: 'м'),
        ];
      case HookItem():
        return [
          bar('hold', 'Надёжность (от схода)', 1 - g.escapeChance,
              'сход ${(g.escapeChance * 100).round()} %'),
        ];
      case LureItem():
        return [
          bar('size', 'Размер', _sizeVal(g.size), _sizeLabel(g.size),
              neutral: true),
        ];
      case EchoSounderItem():
        return [
          bar('range', 'Дальность луча', g.rangeMeters.toDouble(),
              '${g.rangeMeters} м', unit: 'м'),
          bar('vision', 'Возможности', g.capabilities.length.toDouble(),
              '${g.capabilities.length}/6'),
        ];
      case PremiumItem():
        return [
          bar('days', 'Срок действия', g.days.toDouble(), '${g.days} дн.',
              unit: 'дн.'),
          bar('tier', 'Уровень бонусов', g.tier.toDouble(), 'ур. ${g.tier}'),
        ];
    }
  }

  static double _sizeVal(LureSize s) => switch (s) {
        LureSize.small => 1,
        LureSize.medium => 2,
        LureSize.large => 3,
      };
  static String _sizeLabel(LureSize s) => switch (s) {
        LureSize.small => 'малый',
        LureSize.medium => 'средний',
        LureSize.large => 'крупный',
      };
}

/// id предмета, экипированного в слоте данной категории (для сравнения).
String? equippedIdForCategory(Loadout l, GearCategory c) => switch (c) {
      GearCategory.rod => l.rodId,
      GearCategory.spinningRod => l.spinningRodId,
      GearCategory.floatReel => l.floatReelId,
      GearCategory.spinningReel => l.spinningReelId,
      GearCategory.line => l.lineId,
      GearCategory.braid => l.braidId,
      GearCategory.hook => l.hookId,
      GearCategory.bait => l.baitId,
      GearCategory.lure => l.lureId,
      GearCategory.echoSounder => l.echoSounderId,
      _ => null,
    };

/// Модель характеристик, построенная на текущем каталоге.
final gearStatsProvider = Provider<GearStatsModel?>((ref) {
  final catalog = ref.watch(gearCatalogProvider).value;
  return catalog == null ? null : GearStatsModel.fromCatalog(catalog);
});
