import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';

/// Локальный сейв игрока в [SharedPreferences] (JSON‑снимок профиля).
///
/// Достаточно для одиночной локальной игры; при появлении сервера заменяется
/// на сетевую реализацию [PlayerRepository] без изменений в UI.
class LocalPlayerRepository implements PlayerRepository {
  LocalPlayerRepository(this._prefs, {this.accountId});

  final SharedPreferences _prefs;

  /// Аккаунт, чей прогресс загружаем. У каждого аккаунта — свой сейв. Null —
  /// старый общий сейв (совместимость/тесты).
  final String? accountId;

  static const _legacyKey = 'player_save_v1';
  static const playerKeyPrefix = 'player_save_v1__';

  String get _key =>
      accountId == null ? _legacyKey : '$playerKeyPrefix$accountId';

  @override
  Future<Player?> load() async {
    // Миграция: первый вход аккаунта наследует прежний общий сейв (один раз),
    // затем общий ключ удаляется — новые аккаунты начинают с чистой игры.
    if (accountId != null && !_prefs.containsKey(_key)) {
      final legacy = _prefs.getString(_legacyKey);
      if (legacy != null) {
        await _prefs.setString(_key, legacy);
        await _prefs.remove(_legacyKey);
      }
    }
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
