import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';

/// Локальный сейв игрока в [SharedPreferences] (JSON‑снимок профиля).
///
/// Достаточно для одиночной локальной игры; при появлении сервера заменяется
/// на сетевую реализацию [PlayerRepository] без изменений в UI.
class LocalPlayerRepository implements PlayerRepository {
  LocalPlayerRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'player_save_v1';

  @override
  Future<Player?> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return Player.fromJson(json);
    } catch (_) {
      return null; // повреждённый сейв → как новая игра
    }
  }

  @override
  Future<void> save(Player player) async {
    await _prefs.setString(_key, jsonEncode(player.toJson()));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
