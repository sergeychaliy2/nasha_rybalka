import '../entities/gear.dart';
import '../entities/player.dart';
import '../value_objects/fishing_enums.dart';

/// Проверка готовности снасти к выходу на воду.
///
/// Обязательный комплект:
///  • поплавок: удочка, катушка, леска, крючок, наживка (и наживки > 0 шт.);
///  • спиннинг: спиннинг, катушка, шнур, приманка (и приманки > 0 шт.).
/// Эхолот — опционален.
class LoadoutCheck {
  const LoadoutCheck();

  /// Возвращает список недостающего (по-русски) — пустой, если готовы.
  List<String> missingFor(Player p, Map<String, GearItem> byId) {
    final l = p.loadout;
    final spin = l.mode == FishingMode.spinning;
    final missing = <String>[];

    bool ok(String? id) => id != null && byId.containsKey(id);
    int qty(String? id) => id == null
        ? 0
        : p.inventory
            .where((e) => e.gearId == id)
            .fold<int>(0, (s, e) => s + e.quantity);

    if (spin) {
      if (!ok(l.spinningRodId)) missing.add('Спиннинг');
      if (!ok(l.spinningReelId)) missing.add('Катушка');
      if (!ok(l.braidId)) missing.add('Шнур');
      if (!ok(l.lureId)) {
        missing.add('Приманка');
      } else if (qty(l.lureId) <= 0) {
        missing.add('Приманка (закончилась)');
      }
    } else {
      if (!ok(l.rodId)) missing.add('Удочка');
      if (!ok(l.floatReelId)) missing.add('Катушка');
      if (!ok(l.lineId)) missing.add('Леска');
      if (!ok(l.hookId)) missing.add('Крючок');
      if (!ok(l.baitId)) {
        missing.add('Наживка');
      } else if (qty(l.baitId) <= 0) {
        missing.add('Наживка (закончилась)');
      }
    }
    return missing;
  }
}
