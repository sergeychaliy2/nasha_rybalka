import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_store.dart';
import '../data/repositories/local_player_repository.dart';
import '../data/repositories/seed_content_repository.dart';
import '../domain/entities/account.dart';
import '../domain/entities/fish_species.dart';
import '../domain/entities/fishing_location.dart';
import '../domain/entities/gear.dart';
import '../domain/entities/player.dart';
import '../domain/entities/skill.dart';
import '../domain/entities/world.dart';
import '../domain/repositories/content_repository.dart';
import '../domain/repositories/player_repository.dart';
import '../domain/services/bite_calculator.dart';
import '../domain/services/economy_service.dart';
import '../domain/services/leveling_service.dart';
import '../domain/services/loadout_check.dart';
import '../domain/services/tuning.dart';
import '../domain/value_objects/currency.dart';
import '../domain/value_objects/fishing_enums.dart';
import '../domain/value_objects/weight.dart';

/// Инфраструктура: подставляется в [ProviderScope] из `main()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main() after init'),
);

// --- Репозитории (границы абстракции) ------------------------------------

final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => SeedContentRepository());

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  // Прогресс — свой у каждого аккаунта: ключ сейва зависит от активного входа.
  final account = ref.watch(currentAccountProvider);
  return LocalPlayerRepository(ref.watch(sharedPreferencesProvider),
      accountId: account?.id);
});

/// Локальное хранилище аккаунтов (вход/регистрация/реферал).
final accountStoreProvider =
    Provider<AccountStore>((ref) => AccountStore(ref.watch(sharedPreferencesProvider)));

/// Текущий вошедший аккаунт (обновляется при входе/выходе/реферале).
class CurrentAccount extends Notifier<Account?> {
  @override
  Account? build() => ref.read(accountStoreProvider).current;

  /// Установить активный аккаунт (вход/реферал) или null (выход).
  void set(Account? account) => state = account;
}

final currentAccountProvider =
    NotifierProvider<CurrentAccount, Account?>(CurrentAccount.new);

// --- Доменные сервисы (чистая логика) ------------------------------------

final levelingServiceProvider = Provider<LevelingService>((ref) =>
    LevelingService(base: Tuning.levelBase, exponent: Tuning.levelExponent));
final economyServiceProvider =
    Provider<EconomyService>((ref) => const EconomyService());
final biteCalculatorProvider =
    Provider<BiteCalculator>((ref) => const BiteCalculator());
final loadoutCheckProvider =
    Provider<LoadoutCheck>((ref) => const LoadoutCheck());

/// Суммарные эффекты прокачанных навыков игрока (живо обновляются).
final skillEffectsProvider = Provider<SkillEffects>((ref) {
  final skills = ref.watch(playerControllerProvider).value?.skills ?? const {};
  return SkillEffects.from(skills);
});

// --- Контент (асинхронная загрузка) --------------------------------------

final continentsProvider =
    FutureProvider((ref) => ref.watch(contentRepositoryProvider).continents());
final countriesProvider =
    FutureProvider((ref) => ref.watch(contentRepositoryProvider).countries());
final locationsProvider =
    FutureProvider((ref) => ref.watch(contentRepositoryProvider).locations());
final speciesProvider =
    FutureProvider((ref) => ref.watch(contentRepositoryProvider).species());
final gearCatalogProvider =
    FutureProvider((ref) => ref.watch(contentRepositoryProvider).gearCatalog());

/// Итог записи улова — для UI (что начислено).
class CatchOutcome {
  const CatchOutcome({
    required this.silver,
    required this.xp,
    required this.newLevel,
    required this.leveledUp,
    required this.firstOfSpecies,
  });

  final int silver;
  final int xp;
  final int newLevel;
  final bool leveledUp;
  final bool firstOfSpecies;
}

/// Итог попытки покупки в магазине — для понятного фидбэка в UI.
enum PurchaseResult { ok, notEnoughMoney, levelTooLow, alreadyOwned, error }

/// Итог попытки открыть страну/водоём (и вход в турнир).
enum UnlockResult { ok, levelTooLow, notEnoughMoney, error }

/// Лесенка ежедневных наград: серебро по дням 1..7; на 7-й — ещё золото.
const kDailySilverLadder = <int>[100, 150, 200, 300, 400, 500, 800];
const kDailyGoldDay7 = 10;

/// Итог ежедневного входа — для окна награды.
class DailyClaim {
  const DailyClaim(
      {required this.streak, required this.silver, required this.gold});
  final int streak;
  final int silver;
  final int gold;
}

/// Состояние игрока: загрузка из сейва, мутации, авто‑персист.
class PlayerController extends AsyncNotifier<Player> {
  @override
  Future<Player> build() async {
    final repo = ref.watch(playerRepositoryProvider);
    final loaded = (await repo.load()) ?? Player.newGame('Рыбак');
    // Отдых между сессиями: при запуске игры рыбак «выспался» — энергия
    // восстанавливается до полной. Внутри сессии она копится по времени
    // (см. Player.currentEnergy) и тратится на забросы.
    return loaded.copyWith(energy: Player.maxEnergy, lastEnergyAt: DateTime.now());
  }

  Future<void> _persist(Player next) async {
    state = AsyncData(next);
    await ref.read(playerRepositoryProvider).save(next);
  }

  /// Тестовый чит: ставит 22-й уровень (нужный суммарный улов) и подкидывает
  /// валюту — для отладки контента. Вызывается долгим тапом по кольцу уровня.
  Future<void> grantTestProgress() async {
    final p = state.value;
    if (p == null) return;
    final total = ref.read(levelingServiceProvider).requiredTotalFor(22);
    final wallet = p.wallet
        .credit(CurrencyType.gold, 200)
        .credit(CurrencyType.silver, 50000);
    // Флагманский эхолот в рюкзак и в экипировку — чтобы сразу тестить устройство.
    final inv = [...p.inventory];
    if (!inv.any((e) => e.gearId == 'echo_orlan')) {
      inv.add(const InventoryEntry(
          gearId: 'echo_orlan', category: GearCategory.echoSounder));
    }
    await _persist(p.copyWith(
      level: 22,
      totalCaughtGrams: total,
      wallet: wallet,
      inventory: inv,
      loadout: p.loadout.copyWith(echoSounderId: 'echo_orlan'),
    ));
  }

  /// Записывает пойманный экземпляр: начисляет награду, растит уровень,
  /// открывает вид в бестиарии. Возвращает сводку для UI.
  Future<CatchOutcome> recordCatch(
    FishSpecies sp,
    Weight weight, {
    required bool keep,
  }) async {
    final p = state.value;
    if (p == null) {
      return const CatchOutcome(
          silver: 0, xp: 0, newLevel: 1, leveledUp: false, firstOfSpecies: false);
    }
    final economy = ref.read(economyServiceProvider);
    final leveling = ref.read(levelingServiceProvider);
    final premium = p.isPremium;
    final fx = SkillEffects.from(p.skills);

    var wallet = p.wallet;
    var silver = 0;
    var xp = 0;
    if (keep) {
      silver = (economy.silverFor(sp, weight, premium: premium) *
              (1 + fx.silverPct))
          .round();
      wallet = wallet.credit(CurrencyType.silver, silver);
      // Навык «Полевые заметки»: немного опыта капает и за «Забрать».
      if (fx.xpKeepPct > 0) {
        xp = (economy.xpFor(sp, weight, premium: premium) * fx.xpKeepPct)
            .round();
        if (xp > 0) wallet = wallet.credit(CurrencyType.xp, xp);
      }
    } else {
      xp = (economy.xpFor(sp, weight, premium: premium) * (1 + fx.xpPct))
          .round();
      wallet = wallet.credit(CurrencyType.xp, xp);
    }

    final totalGrams = p.totalCaughtGrams + weight.grams;
    final newLevel = leveling.levelForTotal(totalGrams);
    final firstOfSpecies = !p.discoveredSpeciesIds.contains(sp.id);
    final leveledUp = newLevel > p.level;

    // Золото — редкая награда: за новый уровень, за трофейную рыбу и по шансу
    // от навыка «Золотая жила».
    var goldGain = 0;
    if (leveledUp) goldGain += 5 * (newLevel - p.level);
    // Эффективная редкость улова: крупный экземпляр любого вида = трофей.
    final eff = catchRarity(sp, weight);
    if (eff == Rarity.trophy || eff == Rarity.legendary) {
      // Базовая награда за трофей + навык «Призовой фонд».
      goldGain += 2 + fx.goldTrophyBonus;
    }
    if (fx.goldChance > 0 &&
        (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0 <
            fx.goldChance) {
      goldGain += 1;
    }
    if (goldGain > 0) wallet = wallet.credit(CurrencyType.gold, goldGain);

    // Опыт мастерства — валюта древа навыков. Зарабатывается «не легко»:
    // солидный кусок за каждый новый уровень рыбака + бонус за трофеи.
    var masteryGain = 0;
    if (leveledUp) masteryGain += _masteryPerLevel * (newLevel - p.level);
    if (sp.rarity == Rarity.trophy || sp.rarity == Rarity.legendary) {
      masteryGain += _masteryPerTrophy;
    }

    // Счётчик вида + рекорд веса по виду + трофеи (топ-10 по весу).
    final counts = {...p.speciesCounts};
    counts[sp.id] = (counts[sp.id] ?? 0) + 1;
    final best = {...p.speciesBestGrams};
    if (weight.grams > (best[sp.id] ?? 0)) best[sp.id] = weight.grams;
    final trophies = [
      ...p.trophies,
      Catch(
        speciesId: sp.id,
        speciesName: sp.name,
        weight: weight,
        caughtAt: DateTime.now(),
        photoAsset: sp.photoAsset,
      ),
    ]..sort((a, b) => b.weight.grams.compareTo(a.weight.grams));

    // Прогресс ежедневных поручений (сбрасывается на новый календарный день).
    final today = _dayKey(DateTime.now());
    final dayReset = p.dailyTaskDate != today;
    final prog = dayReset ? <String, int>{} : {...p.dailyProgress};
    void bump(String k, int v) => prog[k] = (prog[k] ?? 0) + v;
    bump('catch', 1);
    bump('weight', weight.grams);
    bump(keep ? 'keep' : 'release', 1);
    if (weight.grams >= 1000) bump('big', 1);
    if (eff == Rarity.trophy || eff == Rarity.legendary) bump('trophy', 1);

    await _persist(p.copyWith(
      wallet: wallet,
      totalCaughtGrams: totalGrams,
      level: newLevel,
      skillPoints: p.skillPoints + masteryGain,
      discoveredSpeciesIds: {...p.discoveredSpeciesIds, sp.id},
      trophies: trophies.take(10).toList(),
      speciesCounts: counts,
      speciesBestGrams: best,
      dailyTaskDate: today,
      dailyProgress: prog,
      dailyClaimed: dayReset ? <String>{} : p.dailyClaimed,
    ));

    return CatchOutcome(
      silver: silver,
      xp: xp,
      newLevel: newLevel,
      leveledUp: leveledUp,
      firstOfSpecies: firstOfSpecies,
    );
  }

  /// Универсальное пополнение валюты (награды/промокоды/ежедневки).
  Future<void> credit(CurrencyType type, int amount) async {
    final p = state.value;
    if (p == null) return;
    await _persist(p.copyWith(wallet: p.wallet.credit(type, amount)));
  }

  static bool _isConsumable(GearCategory c) =>
      c == GearCategory.bait ||
      c == GearCategory.groundbait ||
      c == GearCategory.spray ||
      c == GearCategory.energy;

  /// Покупка предмета: проверка уровня/средств/владения, списание и зачисление
  /// в инвентарь (расходники складываются количеством).
  /// Премиум-подписка не попадает в инвентарь — активируется сразу.
  Future<PurchaseResult> purchase(GearItem item) async {
    final p = state.value;
    if (p == null) return PurchaseResult.error;
    if (p.level < item.requiredLevel) return PurchaseResult.levelTooLow;

    if (item is PremiumItem) {
      final wallet = p.wallet.tryDebit(item.price);
      if (wallet == null) return PurchaseResult.notEnoughMoney;
      final now = DateTime.now();
      final base = (p.premiumUntil != null && p.premiumUntil!.isAfter(now))
          ? p.premiumUntil!
          : now;
      await _persist(p.copyWith(
        wallet: wallet,
        premiumUntil: base.add(Duration(days: item.days)),
        premiumTier: item.tier,
      ));
      return PurchaseResult.ok;
    }

    final consumable = _isConsumable(item.category);
    final idx = p.inventory.indexWhere((e) => e.gearId == item.id);
    if (idx >= 0 && !consumable) return PurchaseResult.alreadyOwned;

    final fx = SkillEffects.from(p.skills);
    // Навык «Скидка в лавке» удешевляет серебряные товары.
    final price = (item.price.type == CurrencyType.silver && fx.shopDiscount > 0)
        ? Money.silver((item.price.amount * (1 - fx.shopDiscount)).round())
        : item.price;
    final wallet = p.wallet.tryDebit(price);
    if (wallet == null) return PurchaseResult.notEnoughMoney;

    // Навык «Запасливый»: расходники приходят пачкой больше единицы.
    final addQty = consumable ? 1 + fx.extraBait : 1;
    final inv = [...p.inventory];
    if (idx >= 0) {
      inv[idx] = inv[idx].copyWith(quantity: inv[idx].quantity + addQty);
    } else {
      inv.add(InventoryEntry(
        gearId: item.id,
        category: item.category,
        quantity: addQty,
        remainingLength: item is LineItem ? item.lengthMeters : null,
      ));
    }
    await _persist(p.copyWith(wallet: wallet, inventory: inv));
    if (price.type == CurrencyType.silver) {
      await bumpDaily({'spend': price.amount});
    }
    return PurchaseResult.ok;
  }

  // Сколько опыта мастерства капает за один новый уровень и за трофей.
  static const _masteryPerLevel = 15;
  static const _masteryPerTrophy = 5;

  /// Сброс навыков за золото: древо обнуляется, и весь накопленный опыт
  /// мастерства сгорает (без возврата) — сброс должен быть болезненным.
  Future<UnlockResult> resetSkills(Money cost) async {
    final p = state.value;
    if (p == null) return UnlockResult.error;
    if (p.skills.isEmpty && p.skillPoints == 0) return UnlockResult.ok;
    final wallet = p.wallet.tryDebit(cost);
    if (wallet == null) return UnlockResult.notEnoughMoney;
    await _persist(p.copyWith(wallet: wallet, skills: {}, skillPoints: 0));
    return UnlockResult.ok;
  }

  /// Прокачать узел навыка за ОПЫТ МАСТЕРСТВА. Только по нарастающей от корня:
  /// предшественник должен быть уже открыт (перескакивать нельзя).
  Future<bool> spendSkill(SkillNode node) async {
    final p = state.value;
    if (p == null) return false;
    final cur = p.skills[node.id] ?? 0;
    if (cur >= node.maxLevel) return false;
    if (node.prereq != null && (p.skills[node.prereq] ?? 0) <= 0) return false;
    final cost = node.xpCostFor(cur);
    if (p.skillPoints < cost) return false; // не хватает опыта мастерства
    await _persist(p.copyWith(
        skillPoints: p.skillPoints - cost,
        skills: {...p.skills, node.id: cur + 1}));
    return true;
  }

  /// Установка предмета в соответствующий слот лоадаута по его категории.
  /// Экипировка удилища переключает и режим ловли: взял удочку — поплавок,
  /// взял спиннинг — спиннинговая ловля (отдельного тумблера нет).
  Future<void> equip(GearItem item) async {
    final p = state.value;
    if (p == null) return;
    final l = p.loadout;
    final next = switch (item.category) {
      GearCategory.rod =>
        l.copyWith(rodId: item.id, mode: FishingMode.float),
      GearCategory.spinningRod =>
        l.copyWith(spinningRodId: item.id, mode: FishingMode.spinning),
      GearCategory.floatReel => l.copyWith(floatReelId: item.id),
      GearCategory.spinningReel => l.copyWith(spinningReelId: item.id),
      GearCategory.line => l.copyWith(lineId: item.id),
      GearCategory.braid => l.copyWith(braidId: item.id),
      GearCategory.hook => l.copyWith(hookId: item.id),
      GearCategory.bait => l.copyWith(baitId: item.id),
      GearCategory.lure => l.copyWith(lureId: item.id),
      GearCategory.echoSounder => l.copyWith(echoSounderId: item.id),
      _ => l,
    };
    await _persist(p.copyWith(loadout: next));
  }

  /// Снять необязательный эхолот (оставляет слот пустым).
  Future<void> unequipEcho() async {
    final p = state.value;
    if (p == null) return;
    await _persist(p.copyWith(loadout: p.loadout.removeEcho()));
  }

  /// Переключение режима ловли (поплавок/спиннинг).
  Future<void> setMode(FishingMode mode) async {
    final p = state.value;
    if (p == null) return;
    await _persist(p.copyWith(loadout: p.loadout.copyWith(mode: mode)));
  }

  /// Открыть страну (регион): проверка уровня и оплата экспедиции серебром.
  /// Континент открывается вместе с первой страной в нём.
  Future<UnlockResult> unlockCountry(Country c) async {
    final p = state.value;
    if (p == null) return UnlockResult.error;
    if (p.unlockedCountryIds.contains(c.id)) return UnlockResult.ok;
    if (p.level < c.unlockLevel) return UnlockResult.levelTooLow;
    final wallet = p.wallet.tryDebit(_discounted(c.unlockCost, p));
    if (wallet == null) return UnlockResult.notEnoughMoney;
    await _persist(p.copyWith(
      wallet: wallet,
      unlockedCountryIds: {...p.unlockedCountryIds, c.id},
      unlockedContinentIds: {...p.unlockedContinentIds, c.continentId},
    ));
    return UnlockResult.ok;
  }

  /// Открыть водоём: оплата входа (с учётом валюты стоимости).
  Future<UnlockResult> unlockLocation(FishingLocation loc) async {
    final p = state.value;
    if (p == null) return UnlockResult.error;
    if (p.unlockedLocationIds.contains(loc.id)) return UnlockResult.ok;
    final wallet = p.wallet.tryDebit(_discounted(loc.entryCost, p));
    if (wallet == null) return UnlockResult.notEnoughMoney;
    await _persist(p.copyWith(
      wallet: wallet,
      unlockedLocationIds: {...p.unlockedLocationIds, loc.id},
    ));
    return UnlockResult.ok;
  }

  /// Цена со скидкой навыка «Связи» (только для серебряной стоимости).
  Money _discounted(Money price, Player p) {
    if (price.type != CurrencyType.silver) return price;
    final d = SkillEffects.from(p.skills).unlockDiscount;
    if (d <= 0) return price;
    return Money.silver((price.amount * (1 - d)).round());
  }

  /// Тратит одну единицу расходника (наживка/приманка) по id предмета.
  /// На 3-м уровне премиума наживка с шансом 50% не расходуется.
  /// Возвращает остаток (0 — закончилась; -1 — предмета не было).
  Future<int> consumeBait(String gearId) async {
    final p = state.value;
    if (p == null) return -1;
    // Шанс не потратить: навык «Бережливость» + премиум 3-го уровня.
    var saveChance = SkillEffects.from(p.skills).baitSave;
    if (p.activePremiumTier >= 3) saveChance += 0.5;
    if (saveChance > 0 &&
        (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0 < saveChance) {
      return p.inventory
          .where((e) => e.gearId == gearId)
          .fold<int>(0, (s, e) => s + e.quantity);
    }
    final idx = p.inventory.indexWhere((e) => e.gearId == gearId);
    if (idx < 0) return -1;
    final inv = [...p.inventory];
    final entry = inv[idx];
    final left = entry.quantity - 1;
    if (left > 0) {
      inv[idx] = entry.copyWith(quantity: left);
    } else {
      inv.removeAt(idx);
    }
    await _persist(p.copyWith(inventory: inv));
    return left.clamp(0, 1 << 31);
  }

  /// Утилизация предмета: ~10% стоимости серебром, списание из инвентаря.
  Future<int> salvage(GearItem item) async {
    final p = state.value;
    if (p == null) return 0;
    final idx = p.inventory.indexWhere((e) => e.gearId == item.id);
    if (idx < 0) return 0;
    // Навык «Старьёвщик» поднимает базовые 10% возврата серебром.
    final fx = SkillEffects.from(p.skills);
    final refund = item.price.type == CurrencyType.silver
        ? (item.price.amount * (0.10 + fx.salvagePct)).round()
        : 0;
    final inv = [...p.inventory];
    final entry = inv[idx];
    if (entry.quantity > 1) {
      inv[idx] = entry.copyWith(quantity: entry.quantity - 1);
    } else {
      inv.removeAt(idx);
    }
    var wallet = p.wallet;
    if (refund > 0) wallet = wallet.credit(CurrencyType.silver, refund);
    await _persist(p.copyWith(wallet: wallet, inventory: inv));
    return refund;
  }

  // --- Турниры -------------------------------------------------------------

  /// Вход в турнир: проверка уровня, оплата взноса, старт зачётной сессии.
  Future<UnlockResult> enterTournament(
    String id, {
    required int requiredLevel,
    required Money entry,
    required int durationSec,
  }) async {
    final p = state.value;
    if (p == null) return UnlockResult.error;
    if (p.level < requiredLevel) return UnlockResult.levelTooLow;
    final wallet = p.wallet.tryDebit(entry);
    if (wallet == null) return UnlockResult.notEnoughMoney;
    await _persist(p.copyWith(
      wallet: wallet,
      activeTournamentId: id,
      tournamentScore: 0,
      tournamentEndsAt: DateTime.now().add(Duration(seconds: durationSec)),
    ));
    return UnlockResult.ok;
  }

  /// Прибавляет вес пойманной рыбы к зачёту активного турнира.
  Future<void> addTournamentWeight(int grams) async {
    final p = state.value;
    if (p == null || !p.inTournament) return;
    await _persist(p.copyWith(tournamentScore: p.tournamentScore + grams));
  }

  /// Завершает турнир: начисляет призовые, считает победу, очищает сессию.
  Future<void> awardTournament({
    required int silver,
    required int gold,
    required bool won,
  }) async {
    final p = state.value;
    if (p == null) return;
    var wallet = p.wallet;
    if (silver > 0) wallet = wallet.credit(CurrencyType.silver, silver);
    if (gold > 0) wallet = wallet.credit(CurrencyType.gold, gold);
    await _persist(p.copyWith(
      wallet: wallet,
      activeTournamentId: '',
      tournamentScore: 0,
      tournamentWins: p.tournamentWins + (won ? 1 : 0),
    ));
  }

  /// Прервать турнир без зачёта (выход со сцены) — очистить сессию.
  Future<void> abandonTournament() async {
    final p = state.value;
    if (p == null || !p.inTournament) return;
    await _persist(p.copyWith(activeTournamentId: '', tournamentScore: 0));
  }

  // --- Ежедневная награда --------------------------------------------------

  /// Забрать ежедневную награду (если доступна). Возвращает сводку или null.
  Future<DailyClaim?> claimDaily() async {
    final p = state.value;
    if (p == null || !p.dailyAvailable) return null;
    final now = DateTime.now();
    final last = p.lastDailyClaim;
    // Серия продолжается, если прошлый заход был «вчера»; иначе сброс на 1.
    final continues = last != null && _isYesterday(last, now);
    final streak = continues ? p.dailyStreak + 1 : 1;
    final reward = _dailyReward(streak);
    var wallet = p.wallet.credit(CurrencyType.silver, reward.$1);
    if (reward.$2 > 0) wallet = wallet.credit(CurrencyType.gold, reward.$2);
    await _persist(p.copyWith(
      wallet: wallet,
      lastDailyClaim: now,
      dailyStreak: streak,
      // Ежедневный заход бодрит — энергия восстанавливается полностью.
      energy: Player.maxEnergy,
      lastEnergyAt: now,
    ));
    return DailyClaim(streak: streak, silver: reward.$1, gold: reward.$2);
  }

  static bool _isYesterday(DateTime last, DateTime now) {
    final y =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    return last.year == y.year && last.month == y.month && last.day == y.day;
  }

  /// Награда дня по серии (день = ((streak-1) % 7)): серебро + золото на 7-й.
  static (int, int) _dailyReward(int streak) {
    final day = (streak - 1) % 7; // 0..6
    final gold = day == 6 ? kDailyGoldDay7 : 0;
    return (kDailySilverLadder[day], gold);
  }

  // --- Ежедневные поручения и советы --------------------------------------

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Прибавить к дневному прогрессу поручений (со сбросом на новый день).
  Future<void> bumpDaily(Map<String, int> deltas) async {
    final p = state.value;
    if (p == null) return;
    final today = _dayKey(DateTime.now());
    final reset = p.dailyTaskDate != today;
    final prog = reset ? <String, int>{} : {...p.dailyProgress};
    deltas.forEach((k, v) => prog[k] = (prog[k] ?? 0) + v);
    await _persist(p.copyWith(
      dailyTaskDate: today,
      dailyProgress: prog,
      dailyClaimed: reset ? <String>{} : p.dailyClaimed,
    ));
  }

  /// Забрать награду за выполненное поручение (по метрике и цели). Раз в день.
  Future<bool> claimDailyTask(
    String id,
    String metric,
    int target,
    int silver,
    int gold,
  ) async {
    final p = state.value;
    if (p == null) return false;
    final today = _dayKey(DateTime.now());
    if (p.dailyTaskDate != today) return false; // прогресс ещё не за сегодня
    if (p.dailyClaimed.contains(id)) return false;
    if ((p.dailyProgress[metric] ?? 0) < target) return false;
    var wallet = p.wallet.credit(CurrencyType.silver, silver);
    if (gold > 0) wallet = wallet.credit(CurrencyType.gold, gold);
    await _persist(p.copyWith(
      wallet: wallet,
      dailyClaimed: {...p.dailyClaimed, id},
    ));
    return true;
  }

  /// Купить полезный совет по водоёму за серебро (разово). false — мало средств.
  Future<bool> buyTip(String id, int cost) async {
    final p = state.value;
    if (p == null) return false;
    if (p.purchasedTips.contains(id)) return true;
    final wallet = p.wallet.tryDebit(Money.silver(cost));
    if (wallet == null) return false;
    await _persist(
        p.copyWith(wallet: wallet, purchasedTips: {...p.purchasedTips, id}));
    return true;
  }

  // --- Энергия -------------------------------------------------------------

  /// Тратит энергию (с учётом восстановления). Премиум не расходует энергию.
  /// Возвращает false, если сил не хватает.
  Future<bool> spendEnergy(int cost) async {
    final p = state.value;
    if (p == null) return true;
    if (p.activePremiumTier > 0) return true; // премиум — без расхода
    final cur = p.currentEnergy;
    if (cur < cost) return false;
    await _persist(
        p.copyWith(energy: cur - cost, lastEnergyAt: DateTime.now()));
    return true;
  }

  /// Использовать перекус: восстановить энергию, списать 1 из инвентаря.
  /// Объём восстановления = цена предмета (20..max). Возвращает прибавку.
  Future<int> useEnergyItem(GearItem item) async {
    final p = state.value;
    if (p == null) return 0;
    final idx = p.inventory.indexWhere((e) => e.gearId == item.id);
    if (idx < 0) return 0;
    final cur = p.currentEnergy;
    final restore = item.price.amount.clamp(20, Player.maxEnergy).toInt();
    final next = (cur + restore).clamp(0, Player.maxEnergy).toInt();
    final inv = [...p.inventory];
    final e = inv[idx];
    if (e.quantity > 1) {
      inv[idx] = e.copyWith(quantity: e.quantity - 1);
    } else {
      inv.removeAt(idx);
    }
    await _persist(p.copyWith(
        inventory: inv, energy: next, lastEnergyAt: DateTime.now()));
    return next - cur;
  }
}

final playerControllerProvider =
    AsyncNotifierProvider<PlayerController, Player>(PlayerController.new);
