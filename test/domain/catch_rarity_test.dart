import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/fish_species.dart';
import 'package:nasha_rybalka/domain/services/bite_calculator.dart';
import 'package:nasha_rybalka/domain/value_objects/weight.dart';

FishSpecies _sp(Rarity r, int lo, int hi) => FishSpecies(
      id: 'x',
      name: 'X',
      description: '',
      family: 'мирная',
      habitat: Habitat.fresh,
      rarity: r,
      weightMin: Weight.grams(lo),
      weightMax: Weight.grams(hi),
      baseSilver: 10,
      baseXp: 10,
      biteProfile: BiteProfile.uniform(),
    );

void main() {
  test('мелкий экземпляр обычного вида — обычный', () {
    final common = _sp(Rarity.common, 100, 10000);
    expect(catchRarity(common, Weight.grams(200)), Rarity.common);
  });

  test('у максимума веса обычный вид становится трофеем/легендой', () {
    final common = _sp(Rarity.common, 100, 10000);
    expect(
      catchRarity(common, Weight.grams(9999)).index >= Rarity.trophy.index,
      isTrue,
    );
  });

  test('редкий вид не ниже своей базы даже мелким', () {
    final rare = _sp(Rarity.rare, 100, 10000);
    expect(
      catchRarity(rare, Weight.grams(150)).index >= Rarity.rare.index,
      isTrue,
    );
  });

  test('эффективная редкость монотонна по весу', () {
    final sp = _sp(Rarity.common, 0, 10000);
    var prev = -1;
    for (var g = 0; g <= 10000; g += 500) {
      final idx = catchRarity(sp, Weight.grams(g)).index;
      expect(idx >= prev, isTrue);
      prev = idx;
    }
  });

  test('фактор шанса: легендарные виды клюют реже обычных', () {
    expect(
      BiteCalculator.rarityCatchFactor(Rarity.legendary) <
          BiteCalculator.rarityCatchFactor(Rarity.common),
      isTrue,
    );
  });
}
