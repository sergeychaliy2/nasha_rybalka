import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/skill.dart';

void main() {
  test('эффекты пустые без прокачки', () {
    const e = SkillEffects(); // дефолт
    expect(e.silverPct, 0);
    expect(SkillEffects.from(const {}).silverPct, 0);
  });

  test('эффекты суммируются по уровням узлов', () {
    final e = SkillEffects.from({'e_silver': 3, 'm_bite': 2});
    // Торговец +6%/ур × 3 = 18%.
    expect(e.silverPct, closeTo(0.18, 1e-9));
    // Острый глаз +5%/ур × 2 = 10%.
    expect(e.biteBonus, closeTo(0.10, 1e-9));
  });

  test('у каждого узла валидный предшественник (или его нет)', () {
    final ids = SeedSkills.nodes.map((n) => n.id).toSet();
    for (final n in SeedSkills.nodes) {
      if (n.prereq != null) {
        expect(ids.contains(n.prereq), isTrue,
            reason: '${n.id}: неизвестный prereq ${n.prereq}');
      }
      expect(n.maxLevel, greaterThan(0));
    }
  });

  test('baitSave ограничен сверху', () {
    final e = SkillEffects.from({'t_bait': 99});
    expect(e.baitSave, lessThanOrEqualTo(0.9));
  });
}
