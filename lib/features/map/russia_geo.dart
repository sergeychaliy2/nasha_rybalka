import 'dart:math' as math;
import 'dart:ui';

/// Реальная география для карты России.
///
/// Контур — упрощённая ломаная по реальным координатам границы/побережья
/// (порядка сотни точек: узнаваемая форма без лишней детализации).
/// Проекция — коническая равноплощадная Альберса (стандарт для карт РФ),
/// поэтому страна выглядит привычно «дугой», а не растянутой полосой.

// --- Проекция Альберса -----------------------------------------------------

const _deg = math.pi / 180;
const _phi1 = 52.0 * _deg; // стандартные параллели
const _phi2 = 64.0 * _deg;
const _lambda0 = 96.0 * _deg; // центральный меридиан

final double _n = (math.sin(_phi1) + math.sin(_phi2)) / 2;
final double _c = math.cos(_phi1) * math.cos(_phi1) + 2 * _n * math.sin(_phi1);
final double _rho0 = math.sqrt(_c - 2 * _n * math.sin(60.0 * _deg)) / _n;

/// Сырая проекция (x вправо, y вниз; масштаб условный).
Offset albersRaw(double lonDeg, double latDeg) {
  final lambda = lonDeg * _deg;
  final phi = latDeg * _deg;
  final rho = math.sqrt(_c - 2 * _n * math.sin(phi)) / _n;
  final theta = _n * (lambda - _lambda0);
  final x = rho * math.sin(theta);
  final y = _rho0 - rho * math.cos(theta);
  return Offset(x, -y);
}

/// Преобразование «географические координаты → пиксели холста»:
/// вписывает спроецированный контур в данный размер с отступом и центрирует.
class RussiaMapTransform {
  RussiaMapTransform._(this._scale, this._offset);

  factory RussiaMapTransform.fitInto(Size size, {double paddingFrac = 0.07}) =>
      RussiaMapTransform.fitRaw(_projectedBounds, size,
          paddingFrac: paddingFrac);

  /// Вписывает произвольные спроецированные границы (например, по реальным
  /// контурам регионов, включая Калининград) в заданный размер.
  factory RussiaMapTransform.fitRaw(Rect b, Size size,
      {double paddingFrac = 0.07}) {
    final padW = size.width * paddingFrac;
    final padH = size.height * paddingFrac;
    final scale = math.min(
      (size.width - padW * 2) / b.width,
      (size.height - padH * 2) / b.height,
    );
    final offset = Offset(
      (size.width - b.width * scale) / 2 - b.left * scale,
      (size.height - b.height * scale) / 2 - b.top * scale,
    );
    return RussiaMapTransform._(scale, offset);
  }

  /// Спроецированный bbox произвольного набора точек (x=долгота, y=широта).
  static Rect projectedBoundsOf(Iterable<Offset> lonLat) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in lonLat) {
      final q = albersRaw(p.dx, p.dy);
      minX = math.min(minX, q.dx);
      minY = math.min(minY, q.dy);
      maxX = math.max(maxX, q.dx);
      maxY = math.max(maxY, q.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  final double _scale;
  final Offset _offset;

  Offset map(double lon, double lat) {
    final p = albersRaw(lon, lat);
    return Offset(p.dx * _scale + _offset.dx, p.dy * _scale + _offset.dy);
  }

  /// Обратное: экранная точка → (долгота, широта). Аналитическая инверсия
  /// проекции Альберса (для «поставить точку на карте» в админке).
  (double, double) unmap(Offset screen) {
    final xx = (screen.dx - _offset.dx) / _scale;
    final yy = (screen.dy - _offset.dy) / _scale;
    final rhoCos = yy + _rho0; // yy = rho*cos(theta) - rho0
    final rho = math.sqrt(xx * xx + rhoCos * rhoCos) * (_n < 0 ? -1 : 1);
    final theta = math.atan2(xx, rhoCos);
    final lambda = _lambda0 + theta / _n;
    final rn = rho * _n;
    final s = ((_c - rn * rn) / (2 * _n)).clamp(-1.0, 1.0);
    final phi = math.asin(s);
    return (lambda / _deg, phi / _deg);
  }

  static final Rect _projectedBounds = () {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final (lon, lat) in kRussiaOutline) {
      final p = albersRaw(lon, lat);
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }();
}

// --- Контур России (долгота, широта) ---------------------------------------

const kRussiaOutline = <(double, double)>[
  // Финский залив → Карелия → Кольский
  (28.0, 59.7), (31.0, 62.0), (29.5, 64.8), (29.0, 66.6), (28.5, 68.9),
  (31.0, 69.6), (33.5, 69.4), (37.0, 68.6), (40.3, 67.8), (41.0, 66.8),
  // Белое море → Архангельск → Канин
  (38.5, 66.0), (40.0, 64.8), (44.0, 65.8), (44.3, 68.0), (47.0, 68.2),
  // Арктическое побережье → Ямал → Таймыр
  (53.0, 68.5), (58.0, 69.0), (63.0, 69.5), (66.5, 70.5), (68.5, 73.0),
  (72.5, 71.5), (75.0, 72.5), (80.0, 73.5), (86.0, 75.0), (95.0, 76.2),
  (102.0, 77.6), (106.0, 77.4), (110.0, 76.0), (114.0, 75.0), (120.0, 73.5),
  // Восточная Сибирь → Чукотка
  (127.0, 73.0), (130.0, 72.2), (136.0, 72.5), (142.0, 72.3), (150.0, 71.0),
  (158.0, 70.2), (166.0, 69.7), (172.0, 69.2), (178.0, 68.3), (183.0, 67.0),
  (188.0, 66.3), (190.2, 65.8),
  // Берингово море → Анадырь → Корякия
  (187.5, 64.6), (183.5, 64.7), (181.0, 63.0), (176.0, 62.3), (171.0, 60.5),
  (165.0, 60.0), (162.5, 58.5),
  // Камчатка
  (162.5, 56.2), (161.5, 54.5), (160.8, 52.5), (156.8, 50.9), (155.6, 53.0),
  (156.2, 56.5), (158.5, 59.0),
  // Охотское море → Магадан → Приамурье
  (155.0, 59.8), (150.5, 59.5), (144.0, 59.4), (138.0, 56.5), (140.5, 53.5),
  (140.0, 51.5), (137.5, 49.5), (135.5, 47.0), (133.0, 43.5), (131.5, 42.6),
  // Южная граница: Приморье → Амур → Забайкалье → Монголия → Алтай
  (131.0, 45.0), (134.5, 48.4), (130.5, 48.0), (126.0, 51.5), (121.0, 53.3),
  (116.0, 50.0), (110.0, 49.8), (102.5, 50.4), (98.0, 50.0), (92.0, 50.8),
  (89.0, 49.5),
  // Казахстан → Прикаспий
  (85.0, 49.8), (80.0, 50.8), (76.0, 54.2), (70.0, 55.3), (65.0, 54.6),
  (61.0, 53.9), (60.0, 51.0), (55.5, 50.6), (51.5, 51.5), (48.5, 49.8),
  (47.0, 48.2), (48.7, 46.8),
  // Каспий → Кавказ → Чёрное море
  (47.7, 44.8), (48.0, 41.9), (46.5, 41.8), (43.8, 42.7), (41.5, 43.4),
  (40.0, 43.4), (38.0, 44.3), (36.6, 45.2),
  // Азов → западная граница → Псков
  (39.3, 47.3), (38.0, 49.7), (35.5, 50.4), (34.0, 51.3), (31.6, 52.2),
  (31.0, 53.9), (28.2, 56.0), (27.8, 57.3), (27.5, 58.8),
];

/// Калининградская область (отдельный контур-эллипс).
const kKaliningrad = (20.8, 54.8);

/// Крупные озёра (рисуются поверх суши).
const kLakeLadoga = (31.3, 60.9);
const kLakeOnega = (35.4, 61.8);

/// Байкал — вытянутая дуга (рисуется толстой линией).
const kBaikalLine = <(double, double)>[
  (103.7, 51.5), (105.0, 52.0), (106.5, 52.5), (108.0, 53.3), (109.5, 54.5),
  (110.0, 55.4),
];

/// Главные реки (тонкие линии для узнаваемости).
const kRivers = <List<(double, double)>>[
  // Волга
  [(33.3, 57.0), (36.0, 56.9), (39.9, 57.6), (44.0, 56.3), (49.1, 55.8),
   (50.1, 53.2), (46.0, 50.8), (44.5, 48.7), (48.0, 46.3)],
  // Обь
  [(85.0, 52.5), (82.0, 55.0), (73.0, 61.0), (66.0, 66.0), (69.0, 67.5)],
  // Енисей
  [(92.0, 52.0), (89.0, 56.0), (87.5, 61.5), (88.0, 66.0), (86.0, 70.0),
   (82.5, 71.5)],
  // Лена
  [(108.0, 54.0), (113.0, 57.0), (122.0, 60.0), (127.0, 63.5), (126.0, 67.0),
   (127.0, 72.0)],
  // Амур
  [(121.0, 53.3), (127.0, 50.0), (131.0, 48.3), (135.0, 48.4), (138.0, 51.0),
   (140.5, 53.0)],
];

/// Горные хребты (ломаные по гребню) — рисуются с тенью/подсветкой (рельеф).
const kRanges = <List<(double, double)>>[
  // Урал (С→Ю)
  [(66.0, 67.5), (61.0, 65.5), (59.2, 61.0), (58.6, 57.0), (58.2, 54.0),
   (59.6, 51.6)],
  // Кавказ
  [(39.6, 43.6), (42.0, 43.2), (44.5, 42.8), (46.4, 42.2), (47.6, 41.9)],
  // Алтай — Саяны
  [(84.0, 49.8), (88.0, 50.8), (92.0, 52.0), (96.0, 52.6), (100.5, 52.2),
   (104.0, 51.4)],
  // Верхоянский — хребет Черского
  [(127.0, 67.0), (131.0, 65.0), (135.0, 63.5), (139.0, 64.5), (142.5, 66.5),
   (145.0, 68.5)],
  // Сихотэ-Алинь
  [(134.0, 48.5), (135.5, 46.5), (137.0, 44.5), (138.0, 43.0)],
  // Камчатка (вулканический пояс)
  [(158.4, 57.5), (159.5, 55.5), (160.3, 53.5), (160.8, 52.0)],
  // Плато Путорана — Среднесибирское плоскогорье
  [(90.0, 68.5), (95.0, 69.0), (100.0, 68.7), (105.0, 68.0)],
];

/// Москва (звёздочка на карте).
const kMoscow = (37.6, 55.75);

/// Реальные координаты игровых водоёмов: id локации → (долгота, широта).
const kWaterGeo = <String, (double, double)>{
  'ru_ladoga': (31.3, 60.9), // Ладожское озеро
  'ru_seliger': (33.1, 57.2), // Озеро Селигер
  'ru_rybinsk': (38.4, 58.4), // Рыбинское водохранилище
  'ru_don': (40.1, 49.0), // Река Дон
  'ru_akhtuba': (46.7, 48.2), // Нижняя Волга, Ахтуба
  'ru_yenisei': (92.9, 58.1), // Река Енисей
  'ru_baikal': (107.6, 53.4), // Озеро Байкал
  'ru_amur': (135.1, 48.6), // Река Амур
  'ru_kamchatka': (156.3, 52.9), // Река Большая, Камчатка
};

/// Оверрайд координат водоёмов из админки (новые/перемещённые локации).
Map<String, (double, double)> _waterGeoOverride = const {};
void setWaterGeoOverride(Map<String, (double, double)> m) =>
    _waterGeoOverride = m;

/// Актуальные координаты водоёмов: сид + правки админки.
Map<String, (double, double)> activeWaterGeo() =>
    _waterGeoOverride.isEmpty ? kWaterGeo : {...kWaterGeo, ..._waterGeoOverride};
