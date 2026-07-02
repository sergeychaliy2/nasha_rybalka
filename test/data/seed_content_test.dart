import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/data/seed/seed_content.dart';
import 'package:nasha_rybalka/domain/entities/player.dart';

void main() {
  final species = SeedContent.species();
  final speciesIds = species.map((s) => s.id).toSet();
  final locationIds = SeedContent.locations.map((l) => l.id).toSet();
  final countryIds = SeedContent.countries.map((c) => c.id).toSet();
  final continentIds = SeedContent.continents.map((c) => c.id).toSet();
  final gearIds = SeedContent.gear.map((g) => g.id).toSet();

  test('у каждого зарыбления есть существующий вид', () {
    for (final loc in SeedContent.locations) {
      for (final sp in loc.species) {
        expect(speciesIds.contains(sp.speciesId), isTrue,
            reason: '${loc.id}: нет вида ${sp.speciesId}');
      }
    }
  });

  test('страны ссылаются на существующие локации', () {
    for (final c in SeedContent.countries) {
      for (final id in c.locationIds) {
        expect(locationIds.contains(id), isTrue,
            reason: '${c.id}: нет локации $id');
      }
    }
  });

  test('каждая локация принадлежит существующей стране', () {
    for (final loc in SeedContent.locations) {
      expect(countryIds.contains(loc.countryId), isTrue,
          reason: '${loc.id}: нет страны ${loc.countryId}');
    }
  });

  test('континенты и страны связаны корректно', () {
    for (final cont in SeedContent.continents) {
      for (final id in cont.countryIds) {
        expect(countryIds.contains(id), isTrue,
            reason: '${cont.id}: нет страны $id');
      }
    }
    for (final c in SeedContent.countries) {
      expect(continentIds.contains(c.continentId), isTrue,
          reason: '${c.id}: нет континента ${c.continentId}');
    }
  });

  test('идентификаторы уникальны', () {
    expect(speciesIds.length, species.length);
    expect(locationIds.length, SeedContent.locations.length);
    expect(countryIds.length, SeedContent.countries.length);
    expect(gearIds.length, SeedContent.gear.length);
  });

  test('стартовый лоадаут и инвентарь ссылаются на существующие предметы', () {
    final p = Player.newGame('Тест');
    for (final e in p.inventory) {
      expect(gearIds.contains(e.gearId), isTrue, reason: 'нет ${e.gearId}');
    }
    final l = p.loadout;
    for (final id in [l.rodId, l.floatReelId, l.lineId, l.hookId, l.baitId]) {
      expect(id == null || gearIds.contains(id), isTrue, reason: 'нет $id');
    }
  });
}
