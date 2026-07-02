import 'dart:math' as math;

/// Прогрессия уровней от суммарного веса всей пойманной рыбы.
///
/// Кривая мягко‑экспоненциальная: `требуется(level) = base * (level-1)^p`.
/// Числа берутся из конфига экономики, здесь — формула и дефолты.
class LevelingService {
  const LevelingService({this.base = 3000, this.exponent = 1.25});

  /// Граммы, нужные для перехода с 1‑го на 2‑й уровень (базовый шаг).
  final double base;
  final double exponent;

  /// Суммарные граммы, требуемые, чтобы НАХОДИТЬСЯ на [level].
  int requiredTotalFor(int level) {
    if (level <= 1) return 0;
    return (base * math.pow(level - 1, exponent)).round();
  }

  /// Текущий уровень по накопленному весу.
  int levelForTotal(int totalGrams) {
    var level = 1;
    while (requiredTotalFor(level + 1) <= totalGrams) {
      level++;
      if (level > 999) break; // страховка
    }
    return level;
  }

  /// Прогресс 0..1 до следующего уровня.
  double progressToNext(int totalGrams) {
    final level = levelForTotal(totalGrams);
    final lo = requiredTotalFor(level);
    final hi = requiredTotalFor(level + 1);
    if (hi <= lo) return 0;
    return ((totalGrams - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  int gramsToNext(int totalGrams) {
    final level = levelForTotal(totalGrams);
    return (requiredTotalFor(level + 1) - totalGrams).clamp(0, 1 << 31);
  }
}
