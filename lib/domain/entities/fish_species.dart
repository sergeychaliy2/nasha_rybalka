import '../value_objects/fishing_enums.dart';
import '../value_objects/weight.dart';

enum Rarity { common, uncommon, rare, trophy, legendary }

enum Habitat { fresh, salt, brackish }

/// Эффективная редкость КОНКРЕТНОГО улова: базовая редкость вида + насколько
/// экземпляр крупный для своего вида. Крупная рыба обычного вида может стать
/// эпической/легендарной; редкий вид всегда не ниже своей базы.
///
/// Пороги размера высокие (0.42/0.68/0.86/0.96 от диапазона веса вида), поэтому
/// верхние тиры по весу редки. Базовая редкость задаёт «пол» и подталкивает вверх.
Rarity catchRarity(FishSpecies sp, Weight w) {
  final lo = sp.weightMin.grams;
  final hi = sp.weightMax.grams;
  final t = hi > lo ? ((w.grams - lo) / (hi - lo)).clamp(0.0, 1.0) : 0.0;
  final sizeTier = t >= 0.96
      ? 4
      : t >= 0.86
          ? 3
          : t >= 0.68
              ? 2
              : t >= 0.42
                  ? 1
                  : 0;
  final base = sp.rarity.index;
  final combined = (sizeTier + base * 0.5).round();
  final raw = base > combined ? base : combined;
  return Rarity.values[raw > 4 ? 4 : raw];
}

/// Профиль вероятностей поклёвки вида — настраивается данными (assets/data).
///
/// Группы `size/color/time/weather/depth` нормированы внутри себя (сумма ≈ 1).
/// `lureType` — независимые веса 0..1 на каждый тип (можно «всеядный» вид).
class BiteProfile {
  const BiteProfile({
    required this.sizeWeights,
    required this.colorWeights,
    required this.timeWeights,
    required this.weatherWeights,
    required this.depthWeights,
    required this.lureTypeWeights,
  });

  final Map<LureSize, double> sizeWeights;
  final Map<LureColor, double> colorWeights;
  final Map<TimeOfDay, double> timeWeights;
  final Map<Weather, double> weatherWeights;
  final Map<DepthZone, double> depthWeights;
  final Map<String, double> lureTypeWeights; // ключ — LureType.code

  double size(LureSize s) => sizeWeights[s] ?? 0;
  double colorFor(LureColor c) => colorWeights[c] ?? 0;
  double time(TimeOfDay t) => timeWeights[t] ?? 0;
  double weather(Weather w) => weatherWeights[w] ?? 0;
  double depth(DepthZone d) => depthWeights[d] ?? 0;
  double lure(String typeCode) => lureTypeWeights[typeCode] ?? 0;

  /// Равномерный «нейтральный» профиль — удобный дефолт при нехватке данных.
  factory BiteProfile.uniform() => BiteProfile(
        sizeWeights: {for (final s in LureSize.values) s: 1 / 3},
        colorWeights: {for (final c in LureColor.values) c: 1 / 2},
        timeWeights: {for (final t in TimeOfDay.values) t: 1 / 4},
        weatherWeights: {for (final w in Weather.values) w: 1 / 3},
        depthWeights: {for (final d in DepthZone.values) d: 1 / 4},
        lureTypeWeights: {for (final l in LureType.all) l.code: 0.3},
      );

  Map<String, dynamic> toJson() => {
        'size': {for (final e in sizeWeights.entries) e.key.name: e.value},
        'color': {for (final e in colorWeights.entries) e.key.name: e.value},
        'time': {for (final e in timeWeights.entries) e.key.name: e.value},
        'weather': {
          for (final e in weatherWeights.entries) e.key.name: e.value
        },
        'depth': {for (final e in depthWeights.entries) e.key.name: e.value},
        'lure': lureTypeWeights,
      };

  factory BiteProfile.fromJson(Map<String, dynamic> j) {
    Map<T, double> byName<T extends Enum>(
        List<T> values, String key, double def) {
      final m = j[key];
      return {
        for (final v in values)
          v: m is Map ? ((m[v.name] as num?)?.toDouble() ?? def) : def,
      };
    }

    final lure = j['lure'];
    return BiteProfile(
      sizeWeights: byName(LureSize.values, 'size', 1 / 3),
      colorWeights: byName(LureColor.values, 'color', 1 / 2),
      timeWeights: byName(TimeOfDay.values, 'time', 1 / 4),
      weatherWeights: byName(Weather.values, 'weather', 1 / 3),
      depthWeights: byName(DepthZone.values, 'depth', 1 / 4),
      lureTypeWeights: lure is Map
          ? {
              for (final e in lure.entries)
                e.key.toString(): (e.value as num?)?.toDouble() ?? 0,
            }
          : {for (final l in LureType.all) l.code: 0.3},
    );
  }
}

/// Вид рыбы (каталог). Конкретный пойманный экземпляр — это [Catch].
class FishSpecies {
  const FishSpecies({
    required this.id,
    required this.name,
    required this.description,
    required this.family,
    required this.habitat,
    required this.rarity,
    required this.weightMin,
    required this.weightMax,
    required this.baseSilver,
    required this.baseXp,
    required this.biteProfile,
    this.group = '',
    this.photoAsset,
    this.special = false,
  });

  final String id;
  final String name;
  final String description;
  final String family; // «хищник» / «мирная» / «донная» / «морская» (роль)
  final String group; // биологическое семейство: «Карповые», «Осетровые»…
  final Habitat habitat;
  final Rarity rarity;
  final Weight weightMin;
  final Weight weightMax;

  /// Базовая ставка серебра/опыта за 1 экземпляр (масштабируется весом).
  final int baseSilver;
  final int baseXp;

  final BiteProfile biteProfile;
  final String? photoAsset;

  /// Особый вид (резерв под выключенную ветку). Сейчас всегда false.
  final bool special;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'family': family,
        'group': group,
        'habitat': habitat.name,
        'rarity': rarity.name,
        'weightMin': weightMin.grams,
        'weightMax': weightMax.grams,
        'baseSilver': baseSilver,
        'baseXp': baseXp,
        'biteProfile': biteProfile.toJson(),
        'photoAsset': photoAsset,
        'special': special,
      };

  factory FishSpecies.fromJson(Map<String, dynamic> j) => FishSpecies(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        family: (j['family'] ?? 'мирная') as String,
        group: (j['group'] ?? '') as String,
        habitat: Habitat.values.asNameMap()[j['habitat']] ?? Habitat.fresh,
        rarity: Rarity.values.asNameMap()[j['rarity']] ?? Rarity.common,
        weightMin: Weight.grams((j['weightMin'] as num?)?.toInt() ?? 100),
        weightMax: Weight.grams((j['weightMax'] as num?)?.toInt() ?? 1000),
        baseSilver: (j['baseSilver'] as num?)?.toInt() ?? 10,
        baseXp: (j['baseXp'] as num?)?.toInt() ?? 5,
        biteProfile: j['biteProfile'] is Map
            ? BiteProfile.fromJson(
                Map<String, dynamic>.from(j['biteProfile'] as Map))
            : BiteProfile.uniform(),
        photoAsset: j['photoAsset'] as String?,
        special: (j['special'] as bool?) ?? false,
      );
}

/// Пойманный экземпляр — снимок факта вылова.
class Catch {
  const Catch({
    required this.speciesId,
    required this.speciesName,
    required this.weight,
    required this.caughtAt,
    this.photoAsset,
  });

  final String speciesId;
  final String speciesName;
  final Weight weight;
  final DateTime caughtAt;
  final String? photoAsset;

  Map<String, Object?> toJson() => {
        'speciesId': speciesId,
        'speciesName': speciesName,
        'grams': weight.grams,
        'caughtAt': caughtAt.toIso8601String(),
        'photoAsset': photoAsset,
      };

  factory Catch.fromJson(Map<String, Object?> j) => Catch(
        speciesId: j['speciesId'] as String? ?? '',
        speciesName: j['speciesName'] as String? ?? '',
        weight: Weight.grams((j['grams'] as num?)?.toInt() ?? 0),
        caughtAt:
            DateTime.tryParse(j['caughtAt'] as String? ?? '') ?? DateTime(2020),
        photoAsset: j['photoAsset'] as String?,
      );
}
