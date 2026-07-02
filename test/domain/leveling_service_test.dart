import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/services/leveling_service.dart';

void main() {
  const svc = LevelingService(base: 3000, exponent: 1.25);

  test('1‑й уровень доступен с нуля', () {
    expect(svc.levelForTotal(0), 1);
    expect(svc.requiredTotalFor(1), 0);
  });

  test('уровень растёт монотонно с накоплением веса', () {
    final l1 = svc.levelForTotal(0);
    final l2 = svc.levelForTotal(3000);
    final l3 = svc.levelForTotal(100000);
    expect(l2, greaterThan(l1));
    expect(l3, greaterThan(l2));
  });

  test('прогресс до следующего уровня в диапазоне 0..1', () {
    final p = svc.progressToNext(1500);
    expect(p, inInclusiveRange(0.0, 1.0));
  });

  test('порог следующего уровня строго больше текущего', () {
    for (var lvl = 1; lvl < 20; lvl++) {
      expect(svc.requiredTotalFor(lvl + 1),
          greaterThan(svc.requiredTotalFor(lvl)));
    }
  });
}
