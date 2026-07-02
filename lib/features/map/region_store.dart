import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Субъект РФ: имя (NE, англ.), русское имя и кольца границ (долгота/широта).
/// Источник данных — Natural Earth 50m admin-1 (public domain), упрощено
/// генератором `tool/extract_russia_regions.dart` в `assets/data/`.
class RuRegion {
  const RuRegion({required this.nameEn, required this.nameRu, required this.rings});

  final String nameEn;
  final String nameRu;

  /// Кольца контура: списки точек (x = долгота, y = широта).
  final List<List<Offset>> rings;

  /// Точка внутри региона? (чёт-нечет по всем кольцам)
  bool contains(double lon, double lat) {
    var inside = false;
    for (final ring in rings) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final a = ring[i], b = ring[j];
        if ((a.dy > lat) != (b.dy > lat) &&
            lon < (b.dx - a.dx) * (lat - a.dy) / (b.dy - a.dy) + a.dx) {
          inside = !inside;
        }
      }
    }
    return inside;
  }
}

/// Загрузка границ субъектов из ассета (переиспользуется игрой и админкой).
Future<List<RuRegion>> loadRuRegions() async {
  final raw = await rootBundle.loadString('assets/data/russia_regions.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final list = (json['regions'] as List).cast<Map<String, dynamic>>();
  return [
    for (final r in list)
      RuRegion(
        nameEn: r['n'] as String,
        nameRu: ruRegionName(r['n'] as String),
        rings: [
          for (final ring in (r['r'] as List))
            [
              for (final p in (ring as List))
                Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
        ],
      ),
  ];
}

/// Границы субъектов (один раз на сессию).
final russiaRegionsProvider =
    FutureProvider<List<RuRegion>>((ref) => loadRuRegions());

/// Русские названия субъектов по именам Natural Earth.
String ruRegionName(String en) => _ruNames[en] ?? en;

const _ruNames = <String, String>{
  'Adygey': 'Адыгея',
  'Altay': 'Алтайский край',
  'Amur': 'Амурская область',
  'Arkhangel\'sk': 'Архангельская область',
  'Astrakhan\'': 'Астраханская область',
  'Bashkortostan': 'Башкортостан',
  'Belgorod': 'Белгородская область',
  'Bryansk': 'Брянская область',
  'Buryat': 'Бурятия',
  'Chechnya': 'Чечня',
  'Chelyabinsk': 'Челябинская область',
  'Chita': 'Забайкальский край',
  'Chukchi Autonomous Okrug': 'Чукотский АО',
  'Chuvash': 'Чувашия',
  'City of St. Petersburg': 'Санкт-Петербург',
  'Crimea': 'Крым',
  'Dagestan': 'Дагестан',
  'Gorno-Altay': 'Республика Алтай',
  'Ingush': 'Ингушетия',
  'Irkutsk': 'Иркутская область',
  'Ivanovo': 'Ивановская область',
  'Kabardin-Balkar': 'Кабардино-Балкария',
  'Kaliningrad': 'Калининградская область',
  'Kalmyk': 'Калмыкия',
  'Kaluga': 'Калужская область',
  'Kamchatka': 'Камчатский край',
  'Karachay-Cherkess': 'Карачаево-Черкесия',
  'Karelia': 'Карелия',
  'Kemerovo': 'Кемеровская область',
  'Khabarovsk': 'Хабаровский край',
  'Khakass': 'Хакасия',
  'Khanty-Mansiy': 'Ханты-Мансийский АО',
  'Kirov': 'Кировская область',
  'Komi': 'Коми',
  'Kostroma': 'Костромская область',
  'Krasnodar': 'Краснодарский край',
  'Krasnoyarsk': 'Красноярский край',
  'Kurgan': 'Курганская область',
  'Kursk': 'Курская область',
  'Leningrad': 'Ленинградская область',
  'Lipetsk': 'Липецкая область',
  'Maga Buryatdan': 'Магаданская область',
  'Mariy-El': 'Марий Эл',
  'Mordovia': 'Мордовия',
  'Moskovskaya': 'Московская область',
  'Moskva': 'Москва',
  'Murmansk': 'Мурманская область',
  'Nenets': 'Ненецкий АО',
  'Nizhegorod': 'Нижегородская область',
  'North Ossetia': 'Северная Осетия',
  'Novgorod': 'Новгородская область',
  'Novosibirsk': 'Новосибирская область',
  'Omsk': 'Омская область',
  'Orel': 'Орловская область',
  'Orenburg': 'Оренбургская область',
  'Penza': 'Пензенская область',
  'Perm\'': 'Пермский край',
  'Primor\'ye': 'Приморский край',
  'Pskov': 'Псковская область',
  'Rostov': 'Ростовская область',
  'Ryazan\'': 'Рязанская область',
  'Sakha (Yakutia)': 'Якутия',
  'Sakhalin': 'Сахалинская область',
  'Samara': 'Самарская область',
  'Saratov': 'Саратовская область',
  'Sevastopol': 'Севастополь',
  'Smolensk': 'Смоленская область',
  'Stavropol\'': 'Ставропольский край',
  'Sverdlovsk': 'Свердловская область',
  'Tambov': 'Тамбовская область',
  'Tatarstan': 'Татарстан',
  'Tomsk': 'Томская область',
  'Tula': 'Тульская область',
  'Tuva': 'Тыва',
  'Tver\'': 'Тверская область',
  'Tyumen\'': 'Тюменская область',
  'Udmurt': 'Удмуртия',
  'Ul\'yanovsk': 'Ульяновская область',
  'Vladimir': 'Владимирская область',
  'Volgograd': 'Волгоградская область',
  'Vologda': 'Вологодская область',
  'Voronezh': 'Воронежская область',
  'Yamal-Nenets': 'Ямало-Ненецкий АО',
  'Yaroslavl\'': 'Ярославская область',
  'Yevrey': 'Еврейская АО',
};
