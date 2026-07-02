// Одноразовый генератор ассета границ субъектов РФ.
//
// Вход:  %TEMP%\ne_admin1.geojson (Natural Earth 50m admin-1, public domain)
// Выход: assets/data/russia_regions.json — компактный список регионов:
//        {"regions":[{"n":"Tver'","r":[[[lon,lat],...], ...]}]}
//
// Запуск: dart run tool/extract_russia_regions.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main() {
  final temp = Platform.environment['TEMP'] ?? '/tmp';
  final src = File('$temp/ne_admin1.geojson');
  final raw = jsonDecode(src.readAsStringSync()) as Map<String, dynamic>;
  final features = (raw['features'] as List).cast<Map<String, dynamic>>();

  final regions = <Map<String, dynamic>>[];
  var totalPts = 0;

  for (final f in features) {
    final props = f['properties'] as Map<String, dynamic>;
    final adm0 = (props['adm0_a3'] ?? props['sov_a3'] ?? '') as String;
    if (adm0 != 'RUS') continue;
    final name = (props['name'] ?? props['name_en'] ?? '?') as String;

    final geom = f['geometry'] as Map<String, dynamic>;
    final type = geom['type'] as String;
    final rings = <List<List<double>>>[];

    void addPolygon(List poly) {
      // Берём только внешнее кольцо (дырки на карте такого масштаба не нужны).
      final outer = (poly[0] as List)
          .map((p) => [
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ])
          .toList();
      // Чукотка пересекает 180-й меридиан: западные куски переносим вправо.
      for (final p in outer) {
        if (p[0] < -60) p[0] += 360;
      }
      final simplified = _rdp(outer, 0.04);
      // Отбрасываем мелкие острова, чтобы не раздувать ассет.
      if (_bboxArea(simplified) < 0.15 && regionsHasMainland(rings)) return;
      if (simplified.length < 4) return;
      rings.add(simplified
          .map((p) => [_round(p[0]), _round(p[1])])
          .toList());
    }

    if (type == 'Polygon') {
      addPolygon(geom['coordinates'] as List);
    } else if (type == 'MultiPolygon') {
      final polys = (geom['coordinates'] as List).toList()
        ..sort((a, b) => _polyBboxArea(b as List)
            .compareTo(_polyBboxArea(a as List)));
      for (final poly in polys) {
        addPolygon(poly as List);
      }
    }

    if (rings.isEmpty) continue;
    for (final r in rings) {
      totalPts += r.length;
    }
    regions.add({'n': name, 'r': rings});
  }

  final out = File('assets/data/russia_regions.json');
  out.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode({'regions': regions}));
  stdout.writeln('regions: ${regions.length}, points: $totalPts, '
      'size: ${(out.lengthSync() / 1024).toStringAsFixed(0)} KB');
}

bool regionsHasMainland(List rings) => rings.isNotEmpty;

double _round(double v) => (v * 1000).roundToDouble() / 1000;

double _bboxArea(List<List<double>> ring) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in ring) {
    minX = math.min(minX, p[0]);
    maxX = math.max(maxX, p[0]);
    minY = math.min(minY, p[1]);
    maxY = math.max(maxY, p[1]);
  }
  return (maxX - minX) * (maxY - minY);
}

double _polyBboxArea(List poly) {
  final outer = (poly[0] as List);
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in outer) {
    final x = (p[0] as num).toDouble(), y = (p[1] as num).toDouble();
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  return (maxX - minX) * (maxY - minY);
}

/// Дуглас–Пекер: упрощение ломаной с допуском в градусах.
List<List<double>> _rdp(List<List<double>> pts, double eps) {
  if (pts.length < 3) return pts;
  var maxD = 0.0;
  var idx = 0;
  final a = pts.first, b = pts.last;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = _perpDist(pts[i], a, b);
    if (d > maxD) {
      maxD = d;
      idx = i;
    }
  }
  if (maxD <= eps) return [a, b];
  final left = _rdp(pts.sublist(0, idx + 1), eps);
  final right = _rdp(pts.sublist(idx), eps);
  return [...left.sublist(0, left.length - 1), ...right];
}

double _perpDist(List<double> p, List<double> a, List<double> b) {
  final dx = b[0] - a[0], dy = b[1] - a[1];
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) {
    final ex = p[0] - a[0], ey = p[1] - a[1];
    return math.sqrt(ex * ex + ey * ey);
  }
  final t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / len2;
  final px = a[0] + t * dx, py = a[1] + t * dy;
  final ex = p[0] - px, ey = p[1] - py;
  return math.sqrt(ex * ex + ey * ey);
}
