/// Режим ловли на локации. `special` зарезервирован под особую ветку (выключен).
enum FishingMode { float, spinning, special }

/// Размер приманки/наживки — множитель в алгоритме поклёвки.
enum LureSize { small, medium, large }

/// Цвет приманки.
enum LureColor { bright, natural }

/// Время суток — стадии 20‑минутного цикла.
enum TimeOfDay { morning, day, evening, night }

/// Погода на локации.
enum Weather { clear, cloudy, rain }

/// Зона глубины в точке заброса (из рельефа дна + эхолота).
enum DepthZone { shallow, mid, dropOff, pit }

/// Категория предмета в магазине/инвентаре.
enum GearCategory {
  rod, // удилище
  spinningRod, // спиннинг
  floatReel, // катушка для удочки
  spinningReel, // катушка для спиннинга
  line, // леска
  braid, // шнур
  hook, // крючок
  bait, // наживка
  lure, // приманка
  echoSounder, // эхолот
  groundbait, // прикормка
  spray, // спрей
  energy, // энергия
  premium; // премиум‑подписка

  String get code => name;
}

/// Тип приманки/наживки — ключ в таблице шансов вида рыбы.
/// Расширяемо: новый тип = строка в данных, без правок кода.
class LureType {
  const LureType(this.code, this.label);
  final String code;
  final String label;

  static const worm = LureType('worm', 'Червь');
  static const maggot = LureType('maggot', 'Опарыш');
  static const corn = LureType('corn', 'Кукуруза');
  static const wobbler = LureType('wobbler', 'Воблер');
  static const spinner = LureType('spinner', 'Вертушка');
  static const spoon = LureType('spoon', 'Колебалка');
  static const softBait = LureType('soft_bait', 'Силикон');

  static const all = [worm, maggot, corn, wobbler, spinner, spoon, softBait];

  static LureType fromCode(String code) =>
      all.firstWhere((t) => t.code == code, orElse: () => worm);

  @override
  bool operator ==(Object other) => other is LureType && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
