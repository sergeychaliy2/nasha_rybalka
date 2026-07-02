/// Вес рыбы/снасти. Хранится в граммах (целое) — без ошибок плавающей точки
/// при суммировании счётчика уровня.
class Weight implements Comparable<Weight> {
  const Weight.grams(this.grams) : assert(grams >= 0);

  Weight.kilograms(double kg) : grams = (kg * 1000).round();

  final int grams;

  double get kilograms => grams / 1000.0;

  Weight operator +(Weight other) => Weight.grams(grams + other.grams);

  /// Доля от другого веса (например, вес рыбы относительно предела снасти).
  double ratioTo(Weight max) => max.grams == 0 ? 0 : grams / max.grams;

  /// Человекочитаемо: «850 г» или «3.20 кг».
  String get formatted =>
      grams < 1000 ? '$grams г' : '${kilograms.toStringAsFixed(2)} кг';

  @override
  int compareTo(Weight other) => grams.compareTo(other.grams);

  @override
  bool operator ==(Object other) => other is Weight && other.grams == grams;

  @override
  int get hashCode => grams.hashCode;

  @override
  String toString() => formatted;
}
