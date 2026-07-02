import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/data/seed/seed_content.dart';
import 'package:nasha_rybalka/domain/entities/fish_species.dart';
import 'package:nasha_rybalka/domain/entities/fishing_location.dart';
import 'package:nasha_rybalka/domain/entities/gear.dart';
import 'package:nasha_rybalka/domain/services/tuning.dart';
import 'package:nasha_rybalka/domain/value_objects/fishing_enums.dart';
import 'package:nasha_rybalka/features/tournaments/tournament.dart';

/// Round-trip сериализации контента: правки из админки не должны терять данные
/// при сохранении/загрузке (toJson → fromJson эквивалентно исходному).
void main() {
  group('FishSpecies JSON', () {
    test('round-trip сохраняет все поля и профиль клёва', () {
      for (final s in SeedContent.species()) {
        final r = FishSpecies.fromJson(s.toJson());
        expect(r.id, s.id);
        expect(r.name, s.name);
        expect(r.group, s.group);
        expect(r.family, s.family);
        expect(r.habitat, s.habitat);
        expect(r.rarity, s.rarity);
        expect(r.weightMin.grams, s.weightMin.grams);
        expect(r.weightMax.grams, s.weightMax.grams);
        expect(r.baseSilver, s.baseSilver);
        expect(r.baseXp, s.baseXp);
        for (final l in LureType.all) {
          expect(r.biteProfile.lure(l.code),
              closeTo(s.biteProfile.lure(l.code), 1e-9));
        }
        for (final t in TimeOfDay.values) {
          expect(
              r.biteProfile.time(t), closeTo(s.biteProfile.time(t), 1e-9));
        }
        for (final d in DepthZone.values) {
          expect(
              r.biteProfile.depth(d), closeTo(s.biteProfile.depth(d), 1e-9));
        }
      }
    });
  });

  group('GearItem JSON', () {
    test('round-trip сохраняет тип и характеристики каждого подкласса', () {
      for (final g in SeedContent.gear) {
        final r = GearItem.fromJson(g.toJson());
        expect(r.runtimeType, g.runtimeType, reason: g.id);
        expect(r.id, g.id);
        expect(r.name, g.name);
        expect(r.category, g.category);
        expect(r.price.type, g.price.type);
        expect(r.price.amount, g.price.amount);
        expect(r.requiredLevel, g.requiredLevel);
        expect(r.rarity, g.rarity);
        switch (g) {
          case RodItem():
            expect((r as RodItem).maxWeight.grams, g.maxWeight.grams);
          case ReelItem():
            r as ReelItem;
            expect(r.maxWeight.grams, g.maxWeight.grams);
            expect(r.smoothness, closeTo(g.smoothness, 1e-9));
          case LineItem():
            r as LineItem;
            expect(r.lengthMeters, g.lengthMeters);
            expect(r.maxWeight.grams, g.maxWeight.grams);
          case HookItem():
            expect((r as HookItem).escapeChance,
                closeTo(g.escapeChance, 1e-9));
          case LureItem():
            r as LureItem;
            expect(r.lureType, g.lureType);
            expect(r.size, g.size);
            expect(r.color, g.color);
            expect(r.targetGroups, g.targetGroups);
            expect(r.chumSeconds, g.chumSeconds);
          case EchoSounderItem():
            r as EchoSounderItem;
            expect(r.capabilities, g.capabilities);
            expect(r.rangeMeters, g.rangeMeters);
          case PremiumItem():
            r as PremiumItem;
            expect(r.days, g.days);
            expect(r.tier, g.tier);
        }
      }
    });
  });

  group('FishingLocation JSON', () {
    test('round-trip сохраняет зарыбление и профиль дна', () {
      for (final l in SeedContent.locations) {
        final r = FishingLocation.fromJson(l.toJson());
        expect(r.id, l.id);
        expect(r.name, l.name);
        expect(r.description, l.description);
        expect(r.countryId, l.countryId);
        expect(r.entryCost.amount, l.entryCost.amount);
        expect(r.depthProfile.maxDepthMeters, l.depthProfile.maxDepthMeters);
        expect(r.depthProfile.shape, l.depthProfile.shape);
        expect(r.species.length, l.species.length);
        for (var i = 0; i < l.species.length; i++) {
          expect(r.species[i].speciesId, l.species[i].speciesId);
          expect(r.species[i].floatChance,
              closeTo(l.species[i].floatChance, 1e-9));
          expect(r.species[i].weightMax.grams, l.species[i].weightMax.grams);
        }
        expect(r.backdropAssets, l.backdropAssets);
        expect(r.morningBonusMinutes, l.morningBonusMinutes);
      }
    });
  });

  group('Tournament JSON', () {
    test('round-trip сохраняет призы, взносы и водоём', () {
      for (final t in kSeedTournaments) {
        final r = Tournament.fromJson(t.toJson());
        expect(r.id, t.id);
        expect(r.title, t.title);
        expect(r.locationId, t.locationId);
        expect(r.requiredLevel, t.requiredLevel);
        expect(r.entrySilver, t.entrySilver);
        expect(r.entryGold, t.entryGold);
        expect(r.durationSec, t.durationSec);
        expect(r.parGrams, t.parGrams);
        expect(r.reward1, t.reward1);
        expect(r.goldReward, t.goldReward);
        expect(r.backdrop, t.backdrop);
      }
    });
  });

  group('Tuning JSON', () {
    test('applyJson(toJson) идемпотентен, reset возвращает дефолты', () {
      Tuning.applyJson({'levelBase': 5000.0, 'chumBoost': 3.1});
      expect(Tuning.levelBase, 5000);
      expect(Tuning.chumBoost, 3.1);
      final snapshot = Tuning.toJson();
      Tuning.applyJson(snapshot);
      expect(Tuning.toJson(), snapshot);
      Tuning.reset();
      expect(Tuning.levelBase, 3000);
      expect(Tuning.chumBoost, 2.6);
      expect(Tuning.preRainBiteBonus, 1.25);
      expect(Tuning.energyRegenSeconds, 300);
    });
  });
}
