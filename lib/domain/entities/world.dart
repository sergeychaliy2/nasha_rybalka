import '../value_objects/currency.dart';

/// Континент — верхний уровень мира. Группирует страны.
class Continent {
  const Continent({
    required this.id,
    required this.name,
    required this.unlockLevel,
    required this.unlockCost,
    required this.countryIds,
    this.mapAsset,
  });

  final String id;
  final String name;
  final int unlockLevel;
  final Money unlockCost;
  final List<String> countryIds;
  final String? mapAsset;
}

/// Страна — «биом» со своим набором локаций и видовым составом.
class Country {
  const Country({
    required this.id,
    required this.name,
    required this.continentId,
    required this.unlockLevel,
    required this.unlockCost,
    required this.travelMinutes,
    required this.locationIds,
    this.flagAsset,
    this.mapAsset,
  });

  final String id;
  final String name;
  final String continentId;
  final int unlockLevel;

  /// Базовая стоимость «экспедиции» (к ней применяется множитель уровня).
  final Money unlockCost;

  /// Реальное время в пути до открытия (можно ускорить золотом).
  final int travelMinutes;

  final List<String> locationIds;
  final String? flagAsset;
  final String? mapAsset;
}
