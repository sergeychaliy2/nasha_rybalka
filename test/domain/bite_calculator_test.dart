import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/fish_species.dart';
import 'package:nasha_rybalka/domain/entities/fishing_location.dart';
import 'package:nasha_rybalka/domain/services/bite_calculator.dart';
import 'package:nasha_rybalka/domain/value_objects/fishing_enums.dart';
import 'package:nasha_rybalka/domain/value_objects/weight.dart';

void main() {
  const calc = BiteCalculator();

  FishSpecies pike() => FishSpecies(
        id: 'pike',
        name: 'Щука',
        description: '',
        family: 'хищник',
        habitat: Habitat.fresh,
        rarity: Rarity.uncommon,
        weightMin: Weight.grams(700),
        weightMax: Weight.grams(8000),
        baseSilver: 20,
        baseXp: 16,
        biteProfile: BiteProfile(
          sizeWeights: const {
            LureSize.small: 0.1,
            LureSize.medium: 0.3,
            LureSize.large: 0.6
          },
          colorWeights: const {LureColor.bright: 0.6, LureColor.natural: 0.4},
          timeWeights: const {
            TimeOfDay.morning: 0.4,
            TimeOfDay.day: 0.2,
            TimeOfDay.evening: 0.35,
            TimeOfDay.night: 0.05
          },
          weatherWeights: const {
            Weather.clear: 0.34,
            Weather.cloudy: 0.33,
            Weather.rain: 0.33
          },
          depthWeights: const {
            DepthZone.shallow: 0.4,
            DepthZone.mid: 0.4,
            DepthZone.dropOff: 0.15,
            DepthZone.pit: 0.05
          },
          lureTypeWeights: const {'wobbler': 0.9, 'worm': 0.05},
        ),
      );

  const spawn = SpeciesSpawn(
    speciesId: 'pike',
    weightMin: Weight.grams(700),
    weightMax: Weight.grams(8000),
    floatChance: 0.12,
    spinningChance: 0.45,
  );

  BiteConditions cond(String lure) => BiteConditions(
        mode: FishingMode.spinning,
        lureTypeCode: lure,
        lureSize: LureSize.large,
        lureColor: LureColor.bright,
        time: TimeOfDay.morning,
        weather: Weather.clear,
        depthZone: DepthZone.shallow,
      );

  test('правильная приманка повышает шанс относительно неправильной', () {
    final good = calc.speciesChance(spawn, pike(), cond('wobbler'));
    final bad = calc.speciesChance(spawn, pike(), cond('worm'));
    expect(good, greaterThan(bad));
  });

  test('шанс ограничен сверху (0..0.95)', () {
    final c = calc.speciesChance(spawn, pike(), cond('wobbler'));
    expect(c, inInclusiveRange(0.0, 0.95));
  });

  test('roll иногда возвращает поклёвку нужного вида', () {
    final rng = math.Random(42);
    var bites = 0;
    for (var i = 0; i < 200; i++) {
      final r = calc.roll([(spawn, pike())], cond('wobbler'), rng);
      if (r != null) {
        bites++;
        expect(r.speciesId, 'pike');
        expect(r.weight.grams, inInclusiveRange(700, 8000));
      }
    }
    expect(bites, greaterThan(0));
  });
}
