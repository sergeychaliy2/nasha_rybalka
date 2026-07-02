import '../../domain/entities/fish_species.dart';
import '../../domain/entities/fishing_location.dart';
import '../../domain/entities/gear.dart';
import 'seed_content.dart';

/// Оверрайд списка локаций из админки (полный список заменяет сид).
List<FishingLocation>? _locationsOverride;
void setLocationsOverride(List<FishingLocation>? l) => _locationsOverride = l;

/// Актуальные локации: правки админки приоритетнее сида.
List<FishingLocation> activeLocations() =>
    _locationsOverride ?? SeedContent.locations;

/// Оверрайд каталога видов рыб (полный список заменяет сид).
List<FishSpecies>? _speciesOverride;
List<FishSpecies>? _seedSpeciesCache;
void setSpeciesOverride(List<FishSpecies>? l) => _speciesOverride = l;

/// Актуальные виды: правки админки приоритетнее сида (сид кэшируется).
List<FishSpecies> activeSpecies() =>
    _speciesOverride ?? (_seedSpeciesCache ??= SeedContent.species());

/// Оверрайд каталога снаряжения/магазина (полный список заменяет сид).
List<GearItem>? _gearOverride;
void setGearOverride(List<GearItem>? l) => _gearOverride = l;

/// Актуальный каталог предметов: правки админки приоритетнее сида.
List<GearItem> activeGear() => _gearOverride ?? SeedContent.gear;
