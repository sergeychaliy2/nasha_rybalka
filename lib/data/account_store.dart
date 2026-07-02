import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/account.dart';
import '../shared/password_hash.dart';

/// Результат операции с аккаунтом: либо аккаунт, либо текст ошибки.
class AuthResult {
  const AuthResult.ok(this.account) : error = null;
  const AuthResult.fail(this.error) : account = null;
  final Account? account;
  final String? error;
  bool get success => account != null;
}

/// Локальное хранилище аккаунтов (SharedPreferences, общий бандл с игрой и
/// админкой). Пока без сети — модель и API готовы к переносу на бэкенд:
/// заменить чтение/запись prefs на вызовы сервера, оставив сигнатуры.
///
/// БЕЗОПАСНОСТЬ: пароли только соль+хеш ([PasswordHash]); сессия — id текущего
/// аккаунта; заблокированный аккаунт (`banned`) войти не может.
class AccountStore {
  AccountStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kAccounts = 'accounts_v1';
  static const _kSession = 'session_account_id';
  static const _kPolicy = 'accepted_policy_version';

  final _rng = Random();

  List<Account> all() {
    final s = _prefs.getString(_kAccounts);
    if (s == null) return [];
    try {
      final list = jsonDecode(s);
      if (list is List) {
        return [
          for (final e in list)
            if (e is Map) Account.fromJson(Map<String, dynamic>.from(e)),
        ];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveAll(List<Account> list) =>
      _prefs.setString(_kAccounts, jsonEncode([for (final a in list) a.toJson()]));

  Account? byId(String id) => all().where((a) => a.id == id).firstOrNull;

  Account? byLogin(String login) {
    final q = login.trim().toLowerCase();
    return all()
        .where((a) =>
            a.username.toLowerCase() == q || a.email.toLowerCase() == q)
        .firstOrNull;
  }

  Account? byReferral(String code) {
    final q = code.trim().toUpperCase();
    if (q.isEmpty) return null;
    return all().where((a) => a.referralCode == q).firstOrNull;
  }

  // --- Сессия ------------------------------------------------------------------

  String? get currentId => _prefs.getString(_kSession);
  Account? get current {
    final id = currentId;
    return id == null ? null : byId(id);
  }

  bool get isSignedIn => current != null;
  Future<void> _setSession(String? id) async {
    if (id == null) {
      await _prefs.remove(_kSession);
    } else {
      await _prefs.setString(_kSession, id);
    }
  }

  Future<void> signOut() => _setSession(null);

  // --- Политика/соглашение -----------------------------------------------------

  int get acceptedPolicyVersion => _prefs.getInt(_kPolicy) ?? 0;
  bool get policyAccepted => acceptedPolicyVersion >= kPolicyVersion;
  Future<void> acceptPolicy() => _prefs.setInt(_kPolicy, kPolicyVersion);

  // --- Регистрация / вход ------------------------------------------------------

  static final _userRe = RegExp(r'^[A-Za-zА-Яа-я0-9_ .-]{3,24}$');
  static final _emailRe = RegExp(
      r'^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  /// Известные почтовые сервисы — принимаем только их (защита от опечаток и
  /// «мусорных» доменов). Список легко расширить.
  static const knownEmailDomains = {
    'gmail.com',
    'googlemail.com',
    'yandex.ru',
    'yandex.com',
    'ya.ru',
    'mail.ru',
    'bk.ru',
    'list.ru',
    'inbox.ru',
    'internet.ru',
    'rambler.ru',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'icloud.com',
    'me.com',
    'yahoo.com',
    'proton.me',
    'protonmail.com',
    'gmx.com',
  };

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String referral = '',
    String country = 'RU',
    AccountRole role = AccountRole.player,
  }) async {
    final u = username.trim();
    final e = email.trim().toLowerCase();
    if (!_userRe.hasMatch(u)) {
      return const AuthResult.fail('Имя: 3–24 символа (буквы, цифры, _ . -)');
    }
    if (!_emailRe.hasMatch(e)) {
      return const AuthResult.fail('Некорректный e-mail (пример: name@yandex.ru)');
    }
    final domain = e.split('@').last;
    if (!knownEmailDomains.contains(domain)) {
      return const AuthResult.fail(
          'Домен не поддерживается. Используйте gmail.com, yandex.ru, '
          'mail.ru, outlook.com и подобные.');
    }
    if (password.length < 6) {
      return const AuthResult.fail('Пароль не короче 6 символов');
    }
    final list = all();
    if (list.any((a) => a.username.toLowerCase() == u.toLowerCase())) {
      return const AuthResult.fail('Такое имя уже занято');
    }
    if (list.any((a) => a.email.toLowerCase() == e.toLowerCase())) {
      return const AuthResult.fail('На этот e-mail уже есть аккаунт');
    }
    String? referredBy;
    if (referral.trim().isNotEmpty) {
      final ref = byReferral(referral);
      if (ref == null) {
        return const AuthResult.fail('Реферальный код не найден');
      }
      referredBy = ref.id;
    }
    final salt = PasswordHash.newSalt();
    final acc = Account(
      id: 'acc_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}',
      username: u,
      email: e,
      salt: salt,
      passwordHash: PasswordHash.hash(password, salt),
      createdAt: DateTime.now(),
      referralCode: _newReferralCode(list),
      country: country,
      role: role,
      referredBy: referredBy,
      lastLogin: DateTime.now(),
    );
    list.add(acc);
    await _saveAll(list);
    await _setSession(acc.id);
    return AuthResult.ok(acc);
  }

  Future<AuthResult> login(String login, String password) async {
    final acc = byLogin(login);
    if (acc == null) return const AuthResult.fail('Аккаунт не найден');
    if (acc.banned) return const AuthResult.fail('Аккаунт заблокирован');
    if (!acc.verifyPassword(password)) {
      return const AuthResult.fail('Неверный пароль');
    }
    await update(acc.copyWith(lastLogin: DateTime.now()));
    await _setSession(acc.id);
    return AuthResult.ok(acc);
  }

  // --- Управление (админка) ----------------------------------------------------

  Future<void> update(Account acc) async {
    final list = all();
    final i = list.indexWhere((a) => a.id == acc.id);
    if (i >= 0) {
      list[i] = acc;
    } else {
      list.add(acc);
    }
    await _saveAll(list);
  }

  Future<void> delete(String id) async {
    final list = all()..removeWhere((a) => a.id == id);
    await _saveAll(list);
    if (currentId == id) await signOut();
  }

  Future<void> setPassword(String id, String password) async {
    final acc = byId(id);
    if (acc == null) return;
    final salt = PasswordHash.newSalt();
    await update(acc.copyWith(
        salt: salt, passwordHash: PasswordHash.hash(password, salt)));
  }

  /// Смена реферального кода аккаунта. Возвращает ошибку валидации/занятости
  /// или null при успехе.
  Future<String?> changeReferral(String id, String code) async {
    final acc = byId(id);
    if (acc == null) return 'Аккаунт не найден';
    final c = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(c)) {
      return 'Код: 4–12 символов (латиница/цифры)';
    }
    if (all().any((a) => a.id != id && a.referralCode == c)) {
      return 'Такой код уже занят';
    }
    await update(acc.copyWith(referralCode: c));
    return null;
  }

  /// JSON сейва прогресса аккаунта (для просмотра в админке). Null — не играл.
  Map<String, Object?>? playerSave(String accountId) {
    final raw = _prefs.getString('player_save_v1__$accountId');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map ? Map<String, Object?>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  /// Создание аккаунта админом (без входа под ним). Возвращает ошибку валидации.
  Future<AuthResult> adminCreate({
    required String username,
    required String email,
    required String password,
    String country = 'RU',
    AccountRole role = AccountRole.player,
  }) async {
    final saved = currentId;
    final res = await register(
        username: username,
        email: email,
        password: password,
        country: country,
        role: role);
    // Не переключаем сессию администратора на новый аккаунт.
    await _setSession(saved);
    return res;
  }

  String _newReferralCode(List<Account> existing) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final taken = existing.map((a) => a.referralCode).toSet();
    for (var attempt = 0; attempt < 999; attempt++) {
      final code = List.generate(6, (_) => chars[_rng.nextInt(chars.length)])
          .join();
      if (!taken.contains(code)) return code;
    }
    return 'REF${_rng.nextInt(99999)}';
  }
}

/// Версия «Политики и условий». Повышение → игроку снова показывается экран
/// принятия при следующем запуске.
const int kPolicyVersion = 1;
