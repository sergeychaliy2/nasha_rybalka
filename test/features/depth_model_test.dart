import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/fishing_location.dart';
import 'package:nasha_rybalka/domain/value_objects/fishing_enums.dart';
import 'package:nasha_rybalka/features/fishing/depth_model.dart';

void main() {
  const model = DepthModel();
  const top = DepthModel.waterTopN; // далеко (горизонт)
  const bottom = DepthModel.waterBottomN; // близко (берег)

  DepthProfile profile(String shape, int max) =>
      DepthProfile(seed: 1, maxDepthMeters: max, shape: shape);

  test('глубина всегда в пределах [0, maxDepth]', () {
    for (final shape in ['flat', 'dropOff', 'pit', 'ridge']) {
      final p = profile(shape, 10);
      for (var i = 0; i <= 10; i++) {
        final yN = top + (bottom - top) * i / 10;
        final s = model.sampleAt(yN, p);
        expect(s.meters, inInclusiveRange(0, 10), reason: '$shape @$yN');
      }
    }
  });

  test('пологий уклон: у берега мельче, чем вдали', () {
    final p = profile('flat', 12);
    final shore = model.sampleAt(bottom, p);
    final far = model.sampleAt(top, p);
    expect(shore.meters, lessThan(far.meters));
    expect(shore.zone, DepthZone.shallow);
  });

  test('свал (dropOff): у берега мель, дальше — глубоко', () {
    final p = profile('dropOff', 20);
    expect(model.sampleAt(bottom, p).zone, DepthZone.shallow);
    expect(model.sampleAt(top, p).meters,
        greaterThan(model.sampleAt(bottom, p).meters));
  });

  test('яма (pit): максимум глубины в середине акватории', () {
    final p = profile('pit', 18);
    final mid = model.sampleAt((top + bottom) / 2, p);
    final edge = model.sampleAt(bottom, p);
    expect(mid.meters, greaterThan(edge.meters));
    expect(mid.zone, DepthZone.pit);
  });

  test('точка заброса за пределами воды зажимается в полосу', () {
    final p = profile('flat', 10);
    // y=1.0 (ниже берега) → как на берегу; y=0 (выше горизонта) → как вдали.
    expect(model.sampleAt(1.0, p).meters, model.sampleAt(bottom, p).meters);
    expect(model.sampleAt(0.0, p).meters, model.sampleAt(top, p).meters);
  });
}
