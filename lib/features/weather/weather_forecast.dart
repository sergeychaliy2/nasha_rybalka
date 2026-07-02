import 'dart:math' as math;

import '../../domain/services/tuning.dart';

/// Тип осадков/неба в прогнозе.
enum WxKind { clear, partly, cloudy, rain, snow }

/// Слой карты погоды (как в Яндекс.Погоде).
enum WxLayer { precip, temp, wind, pressure, snow }

/// Точка прогноза для водоёма на конкретный момент.
class WxPoint {
  const WxPoint({
    required this.kind,
    required this.tempC,
    required this.windKmh,
    required this.pressure,
    required this.snowCm,
  });
  final WxKind kind;
  final int tempC;
  final int windKmh;
  final int pressure; // мм рт. ст.
  final int snowCm;
}

/// Процедурный детерминированный прогноз погоды (как цикл день/ночь в игре):
/// зависит от водоёма (id, широта), часа вперёд и «семени дня». Без сети.
class WeatherForecast {
  /// Часы вперёд для слотов таймлайна.
  static const slotsHours = [0, 3, 6, 9, 12, 18, 24, 36, 48, 72];

  static String slotLabel(int h) {
    if (h == 0) return 'Сейчас';
    if (h < 24) return '+$h ч';
    return '+${h ~/ 24} дн';
  }

  static WxPoint at({
    required String locId,
    required double lat,
    required int hourAhead,
    required int daySeed,
  }) {
    final seed =
        (locId.hashCode * 31 + hourAhead * 131 + daySeed * 977) & 0x7fffffff;
    final r = math.Random(seed);
    // База температуры по широте (севернее — холоднее) + суточный ход + шум.
    final latFactor = ((75 - lat) / 40).clamp(0.0, 1.4);
    final baseT = -4 + latFactor * 26; // ≈ -4 (север) … +30 (юг)
    final hourOfDay = (12 + hourAhead) % 24;
    final diurnal = math.cos((hourOfDay - 15) / 24 * 2 * math.pi) * 5;
    final noise = (r.nextDouble() - 0.5) * 6;
    final tempC = (baseT + diurnal + noise).round();
    // Осадки: вероятностно; при минусе — снег. Порог осадков сдвигается
    // глобальным коэффициентом (админка): >0 — дожди чаще.
    final pr = r.nextDouble();
    final precipThr = (0.79 - Tuning.precipBias).clamp(0.58, 0.99);
    final WxKind kind;
    if (pr < 0.32) {
      kind = WxKind.clear;
    } else if (pr < 0.57) {
      kind = WxKind.partly;
    } else if (pr < precipThr) {
      kind = WxKind.cloudy;
    } else {
      kind = tempC <= 0 ? WxKind.snow : WxKind.rain;
    }
    final windKmh = 2 + r.nextInt(23);
    final pressure = 735 + r.nextInt(26); // 735…760 мм рт. ст.
    final snowCm = kind == WxKind.snow
        ? 1 + r.nextInt(12)
        : (tempC < 0 ? r.nextInt(6) : 0);
    return WxPoint(
        kind: kind,
        tempC: tempC,
        windKmh: windKmh,
        pressure: pressure,
        snowCm: snowCm);
  }
}

/// Облачная «ячейка» осадков на карте-радаре: рождается, дрейфует на восток,
/// усиливается и затухает. Форма — мягкая клякса (не по контуру региона).
class WxCell {
  const WxCell({
    required this.lon0,
    required this.lat0,
    required this.radiusDeg,
    required this.vLon,
    required this.vLat,
    required this.birth,
    required this.life,
    required this.kind,
    required this.seed,
  });
  final double lon0; // старт (долгота/широта)
  final double lat0;
  final double radiusDeg; // размер в градусах
  final double vLon; // дрейф (градусов/час)
  final double vLat;
  final double birth; // час появления (может быть отрицательным)
  final double life; // длительность жизни в часах
  final WxKind kind; // rain или snow
  final int seed;

  /// Интенсивность 0..1 на час [h]: плавный рост → плато → затухание.
  double intensityAt(double h) {
    final a = (h - birth) / life;
    if (a <= 0 || a >= 1) return 0;
    if (a < 0.3) return a / 0.3;
    if (a > 0.7) return (1 - a) / 0.3;
    return 1;
  }

  double lonAt(double h) => lon0 + vLon * (h - birth);
  double latAt(double h) => lat0 + vLat * (h - birth);
}

/// Детерминированный набор облачных ячеек на день (для карты осадков).
List<WxCell> weatherCells(int daySeed) {
  final r = math.Random(daySeed ^ 0x51ed3a);
  final n = 11 + r.nextInt(6);
  final out = <WxCell>[];
  for (var i = 0; i < n; i++) {
    final lat = 44 + r.nextDouble() * 28; // 44…72
    final lon = 24 + r.nextDouble() * 156; // 24…180
    final snow = lat > 60 ? r.nextDouble() < 0.7 : r.nextDouble() < 0.15;
    out.add(WxCell(
      lon0: lon,
      lat0: lat,
      radiusDeg: 5 + r.nextDouble() * 9,
      vLon: 0.4 + r.nextDouble() * 1.5,
      vLat: (r.nextDouble() - 0.5) * 0.3,
      birth: -16 + r.nextDouble() * 54,
      life: 14 + r.nextDouble() * 22,
      kind: snow ? WxKind.snow : WxKind.rain,
      seed: r.nextInt(1 << 30),
    ));
  }
  return out;
}
