import '../value_objects/currency.dart';
import '../value_objects/weight.dart';

/// Зарыбление: какой вид водится на локации и с какими параметрами.
/// Локация может переопределять вес и шансы вида относительно его каталога.
class SpeciesSpawn {
  const SpeciesSpawn({
    required this.speciesId,
    required this.weightMin,
    required this.weightMax,
    required this.floatChance,
    required this.spinningChance,
  });

  final String speciesId;
  final Weight weightMin;
  final Weight weightMax;

  /// Базовый шанс вылова на удочку/спиннинг (по умолчанию 0.30/0.30).
  final double floatChance;
  final double spinningChance;

  Map<String, dynamic> toJson() => {
        'speciesId': speciesId,
        'weightMin': weightMin.grams,
        'weightMax': weightMax.grams,
        'floatChance': floatChance,
        'spinningChance': spinningChance,
      };

  factory SpeciesSpawn.fromJson(Map<String, dynamic> j) => SpeciesSpawn(
        speciesId: (j['speciesId'] ?? '') as String,
        weightMin: Weight.grams((j['weightMin'] as num?)?.toInt() ?? 0),
        weightMax: Weight.grams((j['weightMax'] as num?)?.toInt() ?? 1000),
        floatChance: (j['floatChance'] as num?)?.toDouble() ?? 0.3,
        spinningChance: (j['spinningChance'] as num?)?.toDouble() ?? 0.3,
      );

  SpeciesSpawn copyWith({
    String? speciesId,
    Weight? weightMin,
    Weight? weightMax,
    double? floatChance,
    double? spinningChance,
  }) =>
      SpeciesSpawn(
        speciesId: speciesId ?? this.speciesId,
        weightMin: weightMin ?? this.weightMin,
        weightMax: weightMax ?? this.weightMax,
        floatChance: floatChance ?? this.floatChance,
        spinningChance: spinningChance ?? this.spinningChance,
      );
}

/// «Мусорный» объект локации (коряга/топляк/сеть). Награда — серебро/золото.
class TrashSpawn {
  const TrashSpawn({
    required this.id,
    required this.name,
    required this.chance,
    required this.reward,
    required this.rewardMin,
    required this.rewardMax,
    this.iconAsset,
  });

  final String id;
  final String name;
  final double chance; // вероятность появления на этой локации
  final CurrencyType reward;
  final int rewardMin;
  final int rewardMax;
  final String? iconAsset;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chance': chance,
        'reward': reward.code,
        'rewardMin': rewardMin,
        'rewardMax': rewardMax,
        'iconAsset': iconAsset,
      };

  factory TrashSpawn.fromJson(Map<String, dynamic> j) => TrashSpawn(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        chance: (j['chance'] as num?)?.toDouble() ?? 0,
        reward: CurrencyType.fromCode((j['reward'] ?? 'silver') as String),
        rewardMin: (j['rewardMin'] as num?)?.toInt() ?? 0,
        rewardMax: (j['rewardMax'] as num?)?.toInt() ?? 0,
        iconAsset: j['iconAsset'] as String?,
      );
}

/// Профиль глубин локации — основа процедурного, но детерминированного рельефа.
class DepthProfile {
  const DepthProfile({
    required this.seed,
    required this.maxDepthMeters,
    required this.shape,
  });

  /// Фикс. seed → дно всегда одинаковое на этой локации, уникальное на других.
  final int seed;
  final int maxDepthMeters;

  /// Профиль: 'flat' | 'dropOff' | 'pit' | 'ridge' — задаёт форму дна.
  final String shape;

  Map<String, dynamic> toJson() =>
      {'seed': seed, 'maxDepthMeters': maxDepthMeters, 'shape': shape};

  factory DepthProfile.fromJson(Map<String, dynamic> j) => DepthProfile(
        seed: (j['seed'] as num?)?.toInt() ?? 1,
        maxDepthMeters: (j['maxDepthMeters'] as num?)?.toInt() ?? 10,
        shape: (j['shape'] ?? 'flat') as String,
      );
}

/// Игровая локация (водоём) — место ловли с фотофоном.
class FishingLocation {
  const FishingLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.countryId,
    required this.entryCost,
    required this.depthProfile,
    required this.species,
    required this.trash,
    required this.backdropAssets,
    this.requiredVehicleTier = 0,
    this.morningBonusMinutes = 0,
  });

  final String id;
  final String name;
  final String description;
  final String countryId;

  /// Стоимость входа (к ней применяется множитель уровня).
  final Money entryCost;

  final DepthProfile depthProfile;
  final List<SpeciesSpawn> species;
  final List<TrashSpawn> trash;

  /// Фотофоны: 3 ракурса (лево/центр/право).
  final List<String> backdropAssets;

  /// Резерв под транспорт (0 — без требования).
  final int requiredVehicleTier;

  /// Особое окно локации: первые N минут суток — бонус к шансу (0 — выключено).
  final int morningBonusMinutes;

  String get primaryBackdrop =>
      backdropAssets.isNotEmpty ? backdropAssets.first : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'countryId': countryId,
        'entryCost': entryCost.toJson(),
        'depthProfile': depthProfile.toJson(),
        'species': [for (final s in species) s.toJson()],
        'trash': [for (final t in trash) t.toJson()],
        'backdropAssets': backdropAssets,
        'requiredVehicleTier': requiredVehicleTier,
        'morningBonusMinutes': morningBonusMinutes,
      };

  factory FishingLocation.fromJson(Map<String, dynamic> j) => FishingLocation(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        countryId: (j['countryId'] ?? 'ru') as String,
        entryCost: Money.fromJson(
            Map<String, Object?>.from((j['entryCost'] as Map?) ?? const {})),
        depthProfile: DepthProfile.fromJson(
            Map<String, dynamic>.from((j['depthProfile'] as Map?) ?? const {})),
        species: [
          for (final e in (j['species'] as List? ?? const []))
            SpeciesSpawn.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        trash: [
          for (final e in (j['trash'] as List? ?? const []))
            TrashSpawn.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        backdropAssets: [
          for (final e in (j['backdropAssets'] as List? ?? const []))
            e as String,
        ],
        requiredVehicleTier: (j['requiredVehicleTier'] as num?)?.toInt() ?? 0,
        morningBonusMinutes: (j['morningBonusMinutes'] as num?)?.toInt() ?? 0,
      );
}
