/// Типы игровых валют.
///
/// Сейчас активны три. Премиальная «особая» валюта намеренно НЕ добавлена —
/// архитектурный хук: новый тип добавляется сюда, и кошелёк/магазин подхватят
/// его без переписывания (см. docs/GAME_DESIGN.md §15).
enum CurrencyType {
  /// Серебро — мягкая валюта (улов → расходники/снасти/вход).
  silver,

  /// Золото — премиум‑валюта (редкая награда; в локальной сборке без платежей).
  gold,

  /// Опыт — прогрессия, не тратится.
  xp;

  String get code => switch (this) {
        CurrencyType.silver => 'silver',
        CurrencyType.gold => 'gold',
        CurrencyType.xp => 'xp',
      };

  String get label => switch (this) {
        CurrencyType.silver => 'Серебро',
        CurrencyType.gold => 'Золото',
        CurrencyType.xp => 'Опыт',
      };

  static CurrencyType fromCode(String code) => values.firstWhere(
        (c) => c.code == code,
        orElse: () => CurrencyType.silver,
      );
}

/// Денежная сумма: тип валюты + неотрицательное количество.
///
/// Immutable value object. Арифметика возвращает новый экземпляр.
class Money {
  const Money(this.type, this.amount) : assert(amount >= 0);

  const Money.silver(int amount) : this(CurrencyType.silver, amount);
  const Money.gold(int amount) : this(CurrencyType.gold, amount);
  const Money.xp(int amount) : this(CurrencyType.xp, amount);

  final CurrencyType type;
  final int amount;

  Money operator +(int v) => Money(type, amount + v);

  /// Вычитание с нижней отсечкой по нулю.
  Money operator -(int v) => Money(type, (amount - v).clamp(0, amount));

  bool covers(int cost) => amount >= cost;

  Money copyWith({int? amount}) => Money(type, amount ?? this.amount);

  Map<String, Object?> toJson() => {'type': type.code, 'amount': amount};

  factory Money.fromJson(Map<String, Object?> json) => Money(
        CurrencyType.fromCode(json['type'] as String? ?? 'silver'),
        (json['amount'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is Money && other.type == type && other.amount == amount;

  @override
  int get hashCode => Object.hash(type, amount);

  @override
  String toString() => '$amount ${type.label}';
}
