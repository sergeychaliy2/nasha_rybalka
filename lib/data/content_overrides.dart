import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/fish_species.dart';
import '../domain/entities/fishing_location.dart';
import '../domain/entities/gear.dart';
import '../domain/services/tuning.dart';
import '../features/fishing/water_masks.dart';
import '../features/map/russia_geo.dart';
import '../features/tournaments/tournament.dart';
import '../shared/sound_service.dart';
import 'seed/content_state.dart';

/// Слой правок контента из админки поверх сид-дефолтов. Хранится в
/// SharedPreferences — один и тот же стор у игры и админки (общий бандл),
/// поэтому правки из админки видит игра после перезапуска.
///
/// Расширяемо: сейчас — маски зон заброса; далее — рыбы, снасти, коэффициенты
/// (каждый раздел кладёт свой ключ в [_data]).
class ContentOverrides {
  ContentOverrides(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'content_overrides_v1';
  Map<String, dynamic> _data = {};

  void load() {
    final s = _prefs.getString(_key);
    if (s != null) {
      try {
        final d = jsonDecode(s);
        if (d is Map<String, dynamic>) _data = d;
      } catch (_) {}
    }
  }

  Future<void> save() async => _prefs.setString(_key, jsonEncode(_data));

  /// Все правки одним читаемым JSON — для бэкапа/переноса на другую машину.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(_data);

  /// Импорт бэкапа: заменяет ВСЕ правки. false — файл не является объектом.
  bool importJson(String text) {
    try {
      final d = jsonDecode(text);
      if (d is! Map<String, dynamic>) return false;
      _data = d;
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Маски воды / зон заброса ------------------------------------------------

  Map<String, String> waterMasks() {
    final m = _data['waterMasks'];
    if (m is Map) {
      return {
        for (final e in m.entries) e.key.toString(): e.value.toString(),
      };
    }
    return {};
  }

  void setWaterMask(String stem, String mask) {
    _data['waterMasks'] = {...waterMasks(), stem: mask};
  }

  void clearWaterMask(String stem) {
    final m = waterMasks()..remove(stem);
    _data['waterMasks'] = m;
  }

  // --- Турниры (полный список заменяет сид) -----------------------------------

  List<Tournament>? tournaments() {
    final t = _data['tournaments'];
    if (t is List) {
      return [
        for (final e in t)
          if (e is Map) Tournament.fromJson(Map<String, dynamic>.from(e)),
      ];
    }
    return null;
  }

  void setTournaments(List<Tournament> list) =>
      _data['tournaments'] = [for (final t in list) t.toJson()];

  void clearTournaments() => _data.remove('tournaments');

  // --- Локации (полный список) + координаты на карте --------------------------

  List<FishingLocation>? locations() {
    final l = _data['locations'];
    if (l is List) {
      return [
        for (final e in l)
          if (e is Map) FishingLocation.fromJson(Map<String, dynamic>.from(e)),
      ];
    }
    return null;
  }

  void setLocations(List<FishingLocation> list) =>
      _data['locations'] = [for (final l in list) l.toJson()];

  void clearLocations() {
    _data.remove('locations');
    _data.remove('waterGeo');
  }

  Map<String, (double, double)> waterGeo() {
    final g = _data['waterGeo'];
    if (g is Map) {
      final out = <String, (double, double)>{};
      for (final e in g.entries) {
        final v = e.value;
        if (v is List && v.length >= 2) {
          out[e.key.toString()] =
              ((v[0] as num).toDouble(), (v[1] as num).toDouble());
        }
      }
      return out;
    }
    return {};
  }

  void setWaterGeo(String id, double lon, double lat) {
    final g = Map<String, dynamic>.from(
        (_data['waterGeo'] as Map?) ?? const {});
    g[id] = [lon, lat];
    _data['waterGeo'] = g;
  }

  // --- Рыбы (полный каталог видов) ---------------------------------------------

  List<FishSpecies>? species() {
    final s = _data['species'];
    if (s is List) {
      return [
        for (final e in s)
          if (e is Map) FishSpecies.fromJson(Map<String, dynamic>.from(e)),
      ];
    }
    return null;
  }

  void setSpecies(List<FishSpecies> list) =>
      _data['species'] = [for (final s in list) s.toJson()];

  void clearSpecies() => _data.remove('species');

  // --- Снаряжение/магазин (полный каталог) --------------------------------------

  List<GearItem>? gear() {
    final g = _data['gear'];
    if (g is List) {
      return [
        for (final e in g)
          if (e is Map) GearItem.fromJson(Map<String, dynamic>.from(e)),
      ];
    }
    return null;
  }

  void setGear(List<GearItem> list) =>
      _data['gear'] = [for (final g in list) g.toJson()];

  void clearGear() => _data.remove('gear');

  // --- Глобальные коэффициенты ---------------------------------------------------

  Map<String, dynamic> tuning() =>
      Map<String, dynamic>.from((_data['tuning'] as Map?) ?? const {});

  void setTuning(Map<String, dynamic> j) => _data['tuning'] = j;

  void clearTuning() => _data.remove('tuning');

  // --- Звук по умолчанию (админ задаёт дефолты для новых игроков) ---------------

  Map<String, dynamic> audio() =>
      Map<String, dynamic>.from((_data['audio'] as Map?) ?? const {});

  void setAudio(Map<String, dynamic> j) => _data['audio'] = j;

  void clearAudio() => _data.remove('audio');

  /// Применить оверрайды к глобальному состоянию игры.
  void applyToGame() {
    setWaterMaskOverrides(waterMasks());
    setTournamentsOverride(tournaments());
    setLocationsOverride(locations());
    setWaterGeoOverride(waterGeo());
    setSpeciesOverride(species());
    setGearOverride(gear());
    Tuning.applyJson(tuning());
    final a = audio();
    if (a.isNotEmpty) {
      SoundService.applyAdminDefaults(
        enabled: a['enabled'] as bool?,
        volume: (a['volume'] as num?)?.toDouble(),
        effects: (a['effects'] is Map)
            ? {
                for (final e in (a['effects'] as Map).entries)
                  e.key.toString(): e.value == true,
              }
            : null,
      );
    }
  }
}
