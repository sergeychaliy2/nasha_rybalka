import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/features/map/region_store.dart';
import 'package:nasha_rybalka/features/map/russia_geo.dart';

void main() {
  // Читаем ассет напрямую с диска (без Flutter-биндингов).
  final raw = File('assets/data/russia_regions.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final regions = [
    for (final r in (json['regions'] as List).cast<Map<String, dynamic>>())
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

  test('в ассете все 85 субъектов и без англ. имён без перевода', () {
    expect(regions.length, 85);
    for (final r in regions) {
      expect(r.nameRu, isNot(equals(r.nameEn)),
          reason: 'нет перевода для ${r.nameEn}');
    }
  });

  test('каждый игровой водоём попадает в какой-то регион', () {
    for (final e in kWaterGeo.entries) {
      final hit = regions.any((r) => r.contains(e.value.$1, e.value.$2));
      expect(hit, isTrue, reason: '${e.key} вне всех регионов');
    }
  });

  test('точечная привязка корректна для знаковых водоёмов', () {
    RuRegion? regionOf(String id) {
      final g = kWaterGeo[id]!;
      for (final r in regions) {
        if (r.contains(g.$1, g.$2)) return r;
      }
      return null;
    }

    expect(regionOf('ru_baikal')?.nameRu, 'Иркутская область');
    expect(regionOf('ru_kamchatka')?.nameRu, 'Камчатский край');
    expect(regionOf('ru_yenisei')?.nameRu, 'Красноярский край');
  });
}
