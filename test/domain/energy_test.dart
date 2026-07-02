import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/player.dart';

void main() {
  test('новая игра — полная энергия', () {
    expect(Player.newGame('Т').currentEnergy, Player.maxEnergy);
  });

  test('энергия не восстанавливается мгновенно', () {
    final p = Player.newGame('Т')
        .copyWith(energy: 50, lastEnergyAt: DateTime.now());
    expect(p.currentEnergy, 50);
  });

  test('восстановление со временем: 1 ед. за energyRegenSeconds', () {
    // 5 интервалов регена → +5 единиц, независимо от значения константы.
    final ago = DateTime.now()
        .subtract(Duration(seconds: Player.energyRegenSeconds * 5));
    final p = Player.newGame('Т').copyWith(energy: 50, lastEnergyAt: ago);
    expect(p.currentEnergy, 55);
  });

  test('энергия не превышает потолок', () {
    final longAgo = DateTime.now().subtract(const Duration(hours: 5));
    final p =
        Player.newGame('Т').copyWith(energy: 90, lastEnergyAt: longAgo);
    expect(p.currentEnergy, Player.maxEnergy);
  });
}
