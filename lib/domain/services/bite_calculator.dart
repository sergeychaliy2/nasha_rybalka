import 'dart:math' as math;

import '../entities/fish_species.dart';
import '../entities/fishing_location.dart';
import '../value_objects/fishing_enums.dart';
import '../value_objects/weight.dart';
import 'tuning.dart';

/// Текущие условия заброса — вход алгоритма поклёвки.
class BiteConditions {
  const BiteConditions({
    required this.mode,
    required this.lureTypeCode,
    required this.lureSize,
    required this.lureColor,
    required this.time,
    required this.weather,
    required this.depthZone,
    this.locationBonus = 1.0,
    this.chumGroups = const {},
  });

  final FishingMode mode;
  final String lureTypeCode;
  final LureSize lureSize;
  final LureColor lureColor;
  final TimeOfDay time;
  final Weather weather;
  final DepthZone depthZone;

  /// Множитель особого окна локации (1.0 — без бонуса).
  final double locationBonus;

  /// Активная прикормка: биологические семейства, чей шанс вылова повышен
  /// (пусто — нет прикормки по семействам).
  final Set<String> chumGroups;
}

/// Результат расчёта: какой вид клюнул и какого веса (либо «нет поклёвки»).
class BiteResult {
  const BiteResult({required this.speciesId, required this.weight});
  final String speciesId;
  final Weight weight;
}

/// Чистый расчёт поклёвки. Тестируется без Flutter; RNG инъектируется.
class BiteCalculator {
  const BiteCalculator();

  /// Эффективный шанс конкретного вида при текущих условиях.
  ///
  /// Произведение независимых факторов: базовый шанс зарыбления × тип приманки
  /// × размер × цвет × время × погода × глубина × бонус локации.
  double speciesChance(
    SpeciesSpawn spawn,
    FishSpecies species,
    BiteConditions c,
  ) {
    final base =
        c.mode == FishingMode.spinning ? spawn.spinningChance : spawn.floatChance;
    final p = species.biteProfile;
    // Прикормка по биологическому семейству: его виды клюют заметно охотнее.
    final chumBoost =
        c.chumGroups.contains(species.group) ? Tuning.chumBoost : 1.0;
    final chance = base *
        p.lure(c.lureTypeCode) *
        (p.size(c.lureSize) * 3) * // нормировка: распределение ~1/3 → ~1
        (p.colorFor(c.lureColor) * 2) *
        (p.time(c.time) * 4) *
        (p.weather(c.weather) * 3) *
        (p.depth(c.depthZone) * 4) *
        c.locationBonus *
        chumBoost *
        rarityCatchFactor(species.rarity); // чем легендарнее вид — тем реже клёв
    return chance.clamp(0.0, 0.95);
  }

  /// Множитель шанса по редкости вида: легендарные виды клюют значительно реже.
  /// Значения — глобальные коэффициенты (правятся в админке).
  static double rarityCatchFactor(Rarity r) => switch (r) {
        Rarity.common => Tuning.rarityCommon,
        Rarity.uncommon => Tuning.rarityUncommon,
        Rarity.rare => Tuning.rarityRare,
        Rarity.trophy => Tuning.rarityTrophy,
        Rarity.legendary => Tuning.rarityLegendary,
      };

  /// Один «тик» ловли: пробуем поклёвку среди видов локации.
  ///
  /// Каждый вид — независимая проба; среди клюнувших выбираем по весу шанса.
  /// Особые виды (special) сейчас отфильтрованы (ветка выключена).
  BiteResult? roll(
    List<(SpeciesSpawn, FishSpecies)> pool,
    BiteConditions c,
    math.Random rng,
  ) {
    final candidates = <(double score, SpeciesSpawn spawn, FishSpecies sp)>[];
    for (final (spawn, sp) in pool) {
      if (sp.special && c.mode != FishingMode.special) continue;
      final chance = speciesChance(spawn, sp, c);
      if (chance <= 0) continue;
      if (rng.nextDouble() < chance) {
        candidates.add((chance, spawn, sp));
      }
    }
    if (candidates.isEmpty) return null;

    // Взвешенный выбор среди клюнувших.
    final total = candidates.fold<double>(0, (s, e) => s + e.$1);
    var pick = rng.nextDouble() * total;
    var chosen = candidates.first;
    for (final e in candidates) {
      pick -= e.$1;
      if (pick <= 0) {
        chosen = e;
        break;
      }
    }

    final (_, spawn, _) = chosen;
    // Вес смещён к мелкому (степенная кривая): крупные экземпляры — редкость,
    // поэтому трофейные/легендарные по весу попадаются нечасто.
    final lo = spawn.weightMin.grams;
    final hi = spawn.weightMax.grams;
    final t = math.pow(rng.nextDouble(), 2.6).toDouble();
    final grams = (lo + (hi - lo) * t).round();
    return BiteResult(speciesId: chosen.$3.id, weight: Weight.grams(grams));
  }
}
