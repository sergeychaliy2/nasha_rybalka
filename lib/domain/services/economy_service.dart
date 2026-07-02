import '../entities/fish_species.dart';
import '../value_objects/weight.dart';

/// Награды за улов. Масштабируются весом конкретного экземпляра и премиумом.
class EconomyService {
  const EconomyService({this.weightBonusK = 2.0, this.premiumMultiplier = 2});

  /// Насколько сильно вес влияет на награду (фактор = 1 + ratio*K).
  final double weightBonusK;
  final int premiumMultiplier;

  double _weightFactor(Weight weight, Weight speciesMax) =>
      1 + weight.ratioTo(speciesMax).clamp(0.0, 1.0) * weightBonusK;

  /// Серебро за «Забрать».
  int silverFor(FishSpecies species, Weight weight, {bool premium = false}) {
    final base = species.baseSilver * _weightFactor(weight, species.weightMax);
    return (base * (premium ? premiumMultiplier : 1)).round();
  }

  /// Опыт за «Отпустить».
  int xpFor(FishSpecies species, Weight weight, {bool premium = false}) {
    final base = species.baseXp * _weightFactor(weight, species.weightMax);
    return (base * (premium ? premiumMultiplier : 1)).round();
  }

  /// Возврат серебра при утилизации предмета (≈10% стоимости).
  int salvageValue(int itemSilverPrice) => (itemSilverPrice * 0.10).round();
}
