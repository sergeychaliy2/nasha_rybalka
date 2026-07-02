import '../../domain/entities/fish_species.dart';
import '../../domain/entities/fishing_location.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/world.dart';
import '../../domain/repositories/content_repository.dart';
import '../seed/content_state.dart';
import '../seed/seed_content.dart';

/// Контент из встроенного Dart‑сида. Кэширует списки в памяти.
///
/// Чтобы перейти на JSON/сервер — достаточно сделать другую реализацию
/// [ContentRepository]; presentation/domain менять не нужно.
class SeedContentRepository implements ContentRepository {
  @override
  Future<List<Continent>> continents() async => SeedContent.continents;

  @override
  Future<List<Country>> countries() async => SeedContent.countries;

  @override
  Future<List<FishingLocation>> locations() async => activeLocations();

  @override
  Future<List<FishSpecies>> species() async => activeSpecies();

  @override
  Future<List<GearItem>> gearCatalog() async => activeGear();

  @override
  Future<FishingLocation?> locationById(String id) async =>
      activeLocations().where((l) => l.id == id).firstOrNull;

  @override
  Future<FishSpecies?> speciesById(String id) async =>
      activeSpecies().where((s) => s.id == id).firstOrNull;

  @override
  Future<GearItem?> gearById(String id) async =>
      activeGear().where((g) => g.id == id).firstOrNull;
}
