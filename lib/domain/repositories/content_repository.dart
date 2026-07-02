import '../entities/fish_species.dart';
import '../entities/fishing_location.dart';
import '../entities/gear.dart';
import '../entities/world.dart';

/// Источник игрового контента (мир, рыбы, снасти, локации).
///
/// Граница абстракции: presentation/domain зависят только от этого интерфейса.
/// Сейчас реализуется встроенным сидом (Dart), позже без изменений UI можно
/// подменить на загрузку из JSON‑ассетов или с сервера.
abstract interface class ContentRepository {
  Future<List<Continent>> continents();
  Future<List<Country>> countries();
  Future<List<FishingLocation>> locations();
  Future<List<FishSpecies>> species();
  Future<List<GearItem>> gearCatalog();

  Future<FishingLocation?> locationById(String id);
  Future<FishSpecies?> speciesById(String id);
  Future<GearItem?> gearById(String id);
}
