import '../../shared/password_hash.dart';

/// Роль аккаунта: игрок или админ (админ-приложение может помечать доступ).
enum AccountRole { player, admin }

/// Локальный аккаунт игрока (профиль + вход). Пока хранится на устройстве
/// (см. `AccountStore`); модель уже готова к переносу на бэкенд — пароль
/// лежит только как соль+хеш, есть роль/бан/реферальный код и таймстемпы.
class Account {
  const Account({
    required this.id,
    required this.username,
    required this.email,
    required this.salt,
    required this.passwordHash,
    required this.createdAt,
    required this.referralCode,
    this.country = 'RU',
    this.role = AccountRole.player,
    this.banned = false,
    this.referredBy,
    this.redeemedReferral = false,
    this.lastLogin,
    this.note = '',
  });

  final String id;
  final String username;
  final String email;
  final String salt;
  final String passwordHash;
  final DateTime createdAt;

  /// Персональный реферальный код (делится с друзьями).
  final String referralCode;

  /// Страна проживания (код из `countries.dart`, напр. 'RU').
  final String country;
  final AccountRole role;
  final bool banned;

  /// Чей код ввёл этот игрок при регистрации/активации (одноразово).
  final String? referredBy;

  /// Реферальный бонус уже получен (одноразовость).
  final bool redeemedReferral;
  final DateTime? lastLogin;

  /// Заметка администратора (для мониторинга).
  final String note;

  bool verifyPassword(String password) =>
      PasswordHash.verify(password, salt, passwordHash);

  Account copyWith({
    String? username,
    String? email,
    String? salt,
    String? passwordHash,
    String? referralCode,
    String? country,
    AccountRole? role,
    bool? banned,
    String? referredBy,
    bool? redeemedReferral,
    DateTime? lastLogin,
    String? note,
  }) =>
      Account(
        id: id,
        username: username ?? this.username,
        email: email ?? this.email,
        salt: salt ?? this.salt,
        passwordHash: passwordHash ?? this.passwordHash,
        createdAt: createdAt,
        referralCode: referralCode ?? this.referralCode,
        country: country ?? this.country,
        role: role ?? this.role,
        banned: banned ?? this.banned,
        referredBy: referredBy ?? this.referredBy,
        redeemedReferral: redeemedReferral ?? this.redeemedReferral,
        lastLogin: lastLogin ?? this.lastLogin,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'salt': salt,
        'passwordHash': passwordHash,
        'createdAt': createdAt.toIso8601String(),
        'referralCode': referralCode,
        'country': country,
        'role': role.name,
        'banned': banned,
        'referredBy': referredBy,
        'redeemedReferral': redeemedReferral,
        'lastLogin': lastLogin?.toIso8601String(),
        'note': note,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: (j['id'] ?? '') as String,
        username: (j['username'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        salt: (j['salt'] ?? '') as String,
        passwordHash: (j['passwordHash'] ?? '') as String,
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '') as String) ?? DateTime(2020),
        referralCode: (j['referralCode'] ?? '') as String,
        country: (j['country'] ?? 'RU') as String,
        role: AccountRole.values.asNameMap()[j['role']] ?? AccountRole.player,
        banned: (j['banned'] as bool?) ?? false,
        referredBy: j['referredBy'] as String?,
        redeemedReferral: (j['redeemedReferral'] as bool?) ?? false,
        lastLogin: j['lastLogin'] == null
            ? null
            : DateTime.tryParse(j['lastLogin'] as String),
        note: (j['note'] ?? '') as String,
      );
}
