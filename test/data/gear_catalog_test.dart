import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/data/seed/seed_content.dart';
import 'package:nasha_rybalka/domain/entities/gear.dart';
import 'package:nasha_rybalka/domain/services/loadout_check.dart';
import 'package:nasha_rybalka/domain/entities/player.dart';
import 'package:nasha_rybalka/domain/value_objects/currency.dart';
import 'package:nasha_rybalka/domain/value_objects/fishing_enums.dart';

void main() {
  final gear = SeedContent.gear;

  test('каталог большой и id уникальны', () {
    expect(gear.length, greaterThanOrEqualTo(100));
    expect(gear.map((g) => g.id).toSet().length, gear.length);
  });

  test('линейка удочек монотонна: выше тир — сильнее и дороже', () {
    final rods = gear
        .whereType<RodItem>()
        .where((g) => g.category == GearCategory.rod)
        .toList();
    expect(rods.length, 10);
    for (var i = 1; i < rods.length; i++) {
      expect(rods[i].maxWeight.grams,
          greaterThan(rods[i - 1].maxWeight.grams));
      expect(rods[i].requiredLevel,
          greaterThanOrEqualTo(rods[i - 1].requiredLevel));
    }
    // Верх линейки — легендарный и за золото.
    expect(rods.last.rarity, GearRarity.legendary);
    expect(rods.last.price.type, CurrencyType.gold);
  });

  test('премиумы: день/неделя/месяц с растущими тиром и ценой', () {
    final prem = gear.whereType<PremiumItem>().toList()
      ..sort((a, b) => a.days.compareTo(b.days));
    expect(prem.map((p) => p.days).toList(), [1, 7, 30]);
    expect(prem.map((p) => p.tier).toList(), [1, 2, 3]);
    for (final p in prem) {
      expect(p.price.type, CurrencyType.gold);
    }
    expect(prem[2].price.amount, greaterThan(prem[1].price.amount));
    expect(prem[1].price.amount, greaterThan(prem[0].price.amount));
  });

  test('новый игрок проходит проверку снасти (комплект собран)', () {
    final p = Player.newGame('Тест');
    final byId = {for (final g in gear) g.id: g};
    expect(const LoadoutCheck().missingFor(p, byId), isEmpty);
  });

  test('без наживки проверка не пропускает', () {
    final p = Player.newGame('Тест');
    final inv =
        p.inventory.where((e) => e.gearId != 'bait_worm').toList();
    final byId = {for (final g in gear) g.id: g};
    final missing = const LoadoutCheck().missingFor(
        p.copyWith(inventory: inv), byId);
    expect(missing, isNotEmpty);
  });
}
