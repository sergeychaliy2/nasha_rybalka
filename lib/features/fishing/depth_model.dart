import '../../domain/entities/fishing_location.dart';
import '../../domain/value_objects/fishing_enums.dart';

/// Замер глубины в точке заброса: метры (для эхолота) + зона (для поклёвки).
class DepthSample {
  const DepthSample({required this.meters, required this.zone});
  final double meters;
  final DepthZone zone;
}

/// Чистая модель рельефа: по нормированной точке заброса и профилю локации
/// считает глубину. Детерминирована (зависит только от входа) → тестируется.
///
/// [yN] — нормированная вертикаль точки заброса (0 — горизонт/далеко, 1 — низ/
/// у берега). Близко к берегу мельче, дальше — по форме дна [DepthProfile.shape].
class DepthModel {
  const DepthModel();

  /// Полоса воды на сцене по вертикали (совпадает с зоной заброса).
  static const double waterTopN = 0.42;
  static const double waterBottomN = 0.78;

  DepthSample sampleAt(double yN, DepthProfile profile) {
    // d: 0 у берега (близко) → 1 у горизонта (далеко).
    final clamped = yN.clamp(waterTopN, waterBottomN);
    final d = ((waterBottomN - clamped) / (waterBottomN - waterTopN))
        .clamp(0.0, 1.0);

    final factor = _shapeFactor(d, profile.shape).clamp(0.0, 1.0);
    final meters = profile.maxDepthMeters * factor;
    return DepthSample(meters: meters, zone: _zoneFor(factor));
  }

  /// Доля от максимальной глубины (0..1) в зависимости от формы дна.
  double _shapeFactor(double d, String shape) {
    switch (shape) {
      case 'dropOff': // мель у берега, резкий свал дальше
        return d < 0.5 ? d * 0.4 : 0.2 + (d - 0.5) * 1.6;
      case 'pit': // яма в середине акватории
        return 4 * d * (1 - d);
      case 'ridge': // подводная гряда: мелко в середине, глубже по краям
        return (1 - 4 * d * (1 - d)).clamp(0.0, 1.0);
      case 'flat':
      default: // пологий уклон
        return 0.2 + d * 0.6;
    }
  }

  DepthZone _zoneFor(double factor) {
    if (factor < 0.25) return DepthZone.shallow;
    if (factor < 0.55) return DepthZone.mid;
    if (factor < 0.8) return DepthZone.dropOff;
    return DepthZone.pit;
  }
}
