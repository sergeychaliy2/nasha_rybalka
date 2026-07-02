import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Хеширование паролей для локальных аккаунтов.
///
/// БЕЗОПАСНОСТЬ: пароль НИКОГДА не хранится в открытом виде — только соль +
/// многократный SHA-256 (упрощённый PBKDF2). Это защищает сохранённые данные
/// на устройстве. Полноценная защита (серверная проверка, TLS, токены, лимиты
/// попыток) появится вместе с бэкендом — тогда этот класс заменит вызов API.
class PasswordHash {
  PasswordHash._();

  static const _iterations = 20000;
  static final _rng = Random.secure();

  /// Случайная соль (base64, 16 байт).
  static String newSalt() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Хеш пароля с солью: `sha256^N(salt + password)` в hex.
  static String hash(String password, String salt) {
    List<int> bytes = utf8.encode('$salt::$password');
    for (var i = 0; i < _iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return _hex(bytes);
  }

  /// Проверка пароля против сохранённых соли и хеша (без утечки по времени
  /// сравнения — фиксированная свёртка).
  static bool verify(String password, String salt, String expectedHash) {
    final got = hash(password, salt);
    if (got.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < got.length; i++) {
      diff |= got.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
