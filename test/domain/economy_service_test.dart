import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/fish_species.dart';
import 'package:nasha_rybalka/domain/services/economy_service.dart';
import 'package:nasha_rybalka/domain/value_objects/weight.dart';

void main() {
  const economy = EconomyService();

  FishSpecies species() => FishSpecies(
        id: 'x',
        name: 'X',
        description: '',
        family: 'хищник',
        habitat: Habitat.fresh,
        rarity: Rarity.common,
        weightMin: Weight.grams(0),
        weightMax: Weight.grams(1000),
        baseSilver: 10,
        baseXp: 8,
        biteProfile: BiteProfile.uniform(),
      );

  test('тяжёлая рыба даёт больше серебра, чем лёгкая', () {
    final light = economy.silverFor(species(), Weight.grams(100));
    final heavy = economy.silverFor(species(), Weight.grams(1000));
    expect(heavy, greaterThan(light));
  });

  test('премиум удваивает награду', () {
    final base = economy.silverFor(species(), Weight.grams(500));
    final prem = economy.silverFor(species(), Weight.grams(500), premium: true);
    expect(prem, base * 2);
  });

  test('утилизация возвращает ~10%', () {
    expect(economy.salvageValue(1000), 100);
  });
}
