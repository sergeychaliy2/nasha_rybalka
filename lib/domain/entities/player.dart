import '../services/tuning.dart';
import '../value_objects/currency.dart';
import '../value_objects/fishing_enums.dart';
import 'fish_species.dart';

/// Кошелёк игрока — балансы по валютам. Immutable; операции дают новый кошелёк.
class Wallet {
  const Wallet(this._balances);

  factory Wallet.initial() => const Wallet({
        CurrencyType.silver: 500,
        CurrencyType.gold: 0,
        CurrencyType.xp: 0,
      });

  final Map<CurrencyType, int> _balances;

  int balanceOf(CurrencyType type) => _balances[type] ?? 0;
  bool canAfford(Money price) => balanceOf(price.type) >= price.amount;

  Wallet credit(CurrencyType type, int amount) {
    final next = Map<CurrencyType, int>.from(_balances);
    next[type] = (next[type] ?? 0) + amount;
    return Wallet(next);
  }

  /// Списание; вернёт null, если средств недостаточно (политика — на вызывающем).
  Wallet? tryDebit(Money price) {
    if (!canAfford(price)) return null;
    final next = Map<CurrencyType, int>.from(_balances);
    next[price.type] = (next[price.type] ?? 0) - price.amount;
    return Wallet(next);
  }

  Map<String, Object?> toJson() =>
      {for (final e in _balances.entries) e.key.code: e.value};

  factory Wallet.fromJson(Map<String, Object?> json) => Wallet({
        for (final t in CurrencyType.values)
          t: (json[t.code] as num?)?.toInt() ?? 0,
      });
}

/// Владеемый экземпляр снаряжения: ссылка на каталог + runtime‑состояние.
class InventoryEntry {
  const InventoryEntry({
    required this.gearId,
    required this.category,
    this.quantity = 1,
    this.durability = 1.0,
    this.remainingLength,
  });

  final String gearId;
  final GearCategory category;

  /// Кол‑во (для расходников: наживки, прикормка, спреи, энергия).
  final int quantity;

  /// Прочность 0..1 (для снастей).
  final double durability;

  /// Остаток метража (для лески/шнура), иначе null.
  final int? remainingLength;

  InventoryEntry copyWith({
    int? quantity,
    double? durability,
    int? remainingLength,
  }) =>
      InventoryEntry(
        gearId: gearId,
        category: category,
        quantity: quantity ?? this.quantity,
        durability: durability ?? this.durability,
        remainingLength: remainingLength ?? this.remainingLength,
      );

  Map<String, Object?> toJson() => {
        'gearId': gearId,
        'category': category.code,
        'quantity': quantity,
        'durability': durability,
        'remainingLength': remainingLength,
      };

  factory InventoryEntry.fromJson(Map<String, Object?> j) => InventoryEntry(
        gearId: j['gearId'] as String,
        category: GearCategory.values
            .firstWhere((c) => c.code == j['category'], orElse: () => GearCategory.bait),
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        durability: (j['durability'] as num?)?.toDouble() ?? 1.0,
        remainingLength: (j['remainingLength'] as num?)?.toInt(),
      );
}

/// Собранный комплект для ловли (слоты экипировки).
class Loadout {
  const Loadout({
    this.rodId,
    this.spinningRodId,
    this.floatReelId,
    this.spinningReelId,
    this.lineId,
    this.braidId,
    this.hookId,
    this.baitId,
    this.lureId,
    this.echoSounderId,
    this.mode = FishingMode.float,
  });

  final String? rodId;
  final String? spinningRodId;
  final String? floatReelId;
  final String? spinningReelId;
  final String? lineId;
  final String? braidId;
  final String? hookId;
  final String? baitId;
  final String? lureId;
  final String? echoSounderId;
  final FishingMode mode;

  Loadout copyWith({
    String? rodId,
    String? spinningRodId,
    String? floatReelId,
    String? spinningReelId,
    String? lineId,
    String? braidId,
    String? hookId,
    String? baitId,
    String? lureId,
    String? echoSounderId,
    FishingMode? mode,
  }) =>
      Loadout(
        rodId: rodId ?? this.rodId,
        spinningRodId: spinningRodId ?? this.spinningRodId,
        floatReelId: floatReelId ?? this.floatReelId,
        spinningReelId: spinningReelId ?? this.spinningReelId,
        lineId: lineId ?? this.lineId,
        braidId: braidId ?? this.braidId,
        hookId: hookId ?? this.hookId,
        baitId: baitId ?? this.baitId,
        lureId: lureId ?? this.lureId,
        echoSounderId: echoSounderId ?? this.echoSounderId,
        mode: mode ?? this.mode,
      );

  /// Снять необязательный эхолот (copyWith не умеет ставить поле в null).
  Loadout removeEcho() => Loadout(
        rodId: rodId,
        spinningRodId: spinningRodId,
        floatReelId: floatReelId,
        spinningReelId: spinningReelId,
        lineId: lineId,
        braidId: braidId,
        hookId: hookId,
        baitId: baitId,
        lureId: lureId,
        echoSounderId: null,
        mode: mode,
      );

  Map<String, Object?> toJson() => {
        'rodId': rodId,
        'spinningRodId': spinningRodId,
        'floatReelId': floatReelId,
        'spinningReelId': spinningReelId,
        'lineId': lineId,
        'braidId': braidId,
        'hookId': hookId,
        'baitId': baitId,
        'lureId': lureId,
        'echoSounderId': echoSounderId,
        'mode': mode.name,
      };

  factory Loadout.fromJson(Map<String, Object?> j) => Loadout(
        rodId: j['rodId'] as String?,
        spinningRodId: j['spinningRodId'] as String?,
        floatReelId: j['floatReelId'] as String?,
        spinningReelId: j['spinningReelId'] as String?,
        lineId: j['lineId'] as String?,
        braidId: j['braidId'] as String?,
        hookId: j['hookId'] as String?,
        baitId: j['baitId'] as String?,
        lureId: j['lureId'] as String?,
        echoSounderId: j['echoSounderId'] as String?,
        mode: FishingMode.values
            .firstWhere((m) => m.name == j['mode'], orElse: () => FishingMode.float),
      );
}

/// Совокупный профиль игрока — единый сериализуемый снимок прогресса.
class Player {
  const Player({
    required this.nickname,
    required this.level,
    required this.totalCaughtGrams,
    required this.energy,
    required this.wallet,
    required this.inventory,
    required this.loadout,
    required this.unlockedContinentIds,
    required this.unlockedCountryIds,
    required this.unlockedLocationIds,
    required this.discoveredSpeciesIds,
    this.trophies = const [],
    this.speciesCounts = const {},
    this.speciesBestGrams = const {},
    this.skillPoints = 0,
    this.skills = const {},
    this.premiumUntil,
    this.premiumTier = 0,
    this.activeTournamentId = '',
    this.tournamentScore = 0,
    this.tournamentEndsAt,
    this.tournamentWins = 0,
    this.lastDailyClaim,
    this.dailyStreak = 0,
    this.lastEnergyAt,
    this.dailyTaskDate = '',
    this.dailyProgress = const {},
    this.dailyClaimed = const {},
    this.purchasedTips = const {},
  });

  /// Потолок энергии и скорость восстановления (1 ед. за столько секунд).
  /// Копится в реальном времени даже при закрытой игре (см. [currentEnergy]).
  /// Реген намеренно медленный (1 ед./5 мин) — не «стена» только потому, что
  /// при каждом запуске игры бак полный (см. PlayerController.build).
  /// Лимит и скорость восстановления энергии — глобальные коэффициенты,
  /// правятся в админке (см. [Tuning]).
  static int get maxEnergy => Tuning.maxEnergy;
  static int get energyRegenSeconds => Tuning.energyRegenSeconds;

  factory Player.newGame(String nickname) => Player(
        nickname: nickname,
        level: 1,
        totalCaughtGrams: 0,
        energy: 100,
        wallet: Wallet.initial(),
        // Стартовый набор: рабочая поплавочная снасть + запас спиннинговой.
        inventory: const [
          InventoryEntry(gearId: 'rod_a', category: GearCategory.rod),
          InventoryEntry(gearId: 'spin_a', category: GearCategory.spinningRod),
          InventoryEntry(
              gearId: 'reel_float_a', category: GearCategory.floatReel),
          InventoryEntry(
              gearId: 'reel_spin_a', category: GearCategory.spinningReel),
          InventoryEntry(
              gearId: 'line_a',
              category: GearCategory.line,
              remainingLength: 100),
          InventoryEntry(gearId: 'hook_a', category: GearCategory.hook),
          InventoryEntry(
              gearId: 'bait_worm', category: GearCategory.bait, quantity: 20),
          InventoryEntry(
              gearId: 'bait_corn', category: GearCategory.bait, quantity: 10),
          // Пара перекусов на старт — чтобы энергия не застала врасплох.
          InventoryEntry(
              gearId: 'food_tea', category: GearCategory.energy, quantity: 3),
        ],
        // Собранная поплавочная оснастка по умолчанию (готова к ловле).
        loadout: const Loadout(
          rodId: 'rod_a',
          spinningRodId: 'spin_a',
          floatReelId: 'reel_float_a',
          spinningReelId: 'reel_spin_a',
          lineId: 'line_a',
          hookId: 'hook_a',
          baitId: 'bait_worm',
          mode: FishingMode.float,
        ),
        unlockedContinentIds: const {'europe'},
        unlockedCountryIds: const {'ru'},
        unlockedLocationIds: const {'ru_ladoga'},
        discoveredSpeciesIds: const {},
        // Опыт мастерства зарабатывается ловлей — на старте дерево закрыто.
        skillPoints: 0,
      );

  final String nickname;
  final int level;
  final int totalCaughtGrams;
  final int energy;
  final Wallet wallet;
  final List<InventoryEntry> inventory;
  final Loadout loadout;
  final Set<String> unlockedContinentIds;
  final Set<String> unlockedCountryIds;
  final Set<String> unlockedLocationIds;
  final Set<String> discoveredSpeciesIds;

  /// Топ самых тяжёлых пойманных рыб (трофеи), отсортирован по убыванию веса.
  final List<Catch> trophies;

  /// Сколько экземпляров каждого вида поймано (для бестиария).
  final Map<String, int> speciesCounts;

  /// Рекордный вес (граммы) по каждому виду — самый крупный пойманный
  /// экземпляр. Карточка бестиария красится по эффективной редкости рекорда.
  final Map<String, int> speciesBestGrams;

  /// «Опыт мастерства» — отдельная валюта древа навыков. Копится за новые
  /// уровни рыбака и за трофейные уловы; тратится на узлы; сгорает при сбросе.
  final int skillPoints;
  final Map<String, int> skills;

  final DateTime? premiumUntil;

  /// Уровень активного премиума (0 — нет; 1/2/3 — день/неделя/месяц).
  final int premiumTier;

  /// Текущий турнир (пусто — не участвует), накопленный зачётный вес и дедлайн.
  final String activeTournamentId;
  final int tournamentScore;
  final DateTime? tournamentEndsAt;

  /// Сколько турниров выиграно (1-е место) — для достижений.
  final int tournamentWins;

  /// Ежедневный вход: время последнего получения и текущая серия дней.
  final DateTime? lastDailyClaim;
  final int dailyStreak;

  /// Когда энергия в последний раз пересчитывалась (для офлайн-восстановления).
  final DateTime? lastEnergyAt;

  /// Ежедневные поручения: дата набора (YYYY-MM-DD), прогресс по метрикам и
  /// id уже забранных за день поручений.
  final String dailyTaskDate;
  final Map<String, int> dailyProgress;
  final Set<String> dailyClaimed;

  /// Купленные «полезные советы» по водоёмам (id советов).
  final Set<String> purchasedTips;

  /// Текущая энергия с учётом восстановления со временем (живое значение).
  int get currentEnergy {
    final last = lastEnergyAt;
    if (last == null) return energy.clamp(0, maxEnergy);
    final gained =
        DateTime.now().difference(last).inSeconds ~/ energyRegenSeconds;
    return (energy + gained).clamp(0, maxEnergy);
  }

  bool get isPremium =>
      premiumUntil != null && premiumUntil!.isAfter(DateTime.now());

  /// Действующий уровень премиума с учётом срока.
  int get activePremiumTier => isPremium ? premiumTier : 0;

  bool get inTournament => activeTournamentId.isNotEmpty;

  /// Доступна ли сегодня ежедневная награда (другой календарный день).
  bool get dailyAvailable {
    final last = lastDailyClaim;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year &&
        last.month == now.month &&
        last.day == now.day);
  }

  /// Какой день серии будет засчитан следующим (1..∞). Если уже забрано
  /// сегодня — возвращает текущую серию (для подсветки последней награды).
  int get dailyNextStreak {
    final last = lastDailyClaim;
    if (last == null) return 1;
    if (!dailyAvailable) return dailyStreak;
    final now = DateTime.now();
    final y = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final wasYesterday =
        last.year == y.year && last.month == y.month && last.day == y.day;
    return wasYesterday ? dailyStreak + 1 : 1;
  }

  Player copyWith({
    String? nickname,
    int? level,
    int? totalCaughtGrams,
    int? energy,
    Wallet? wallet,
    List<InventoryEntry>? inventory,
    Loadout? loadout,
    Set<String>? unlockedContinentIds,
    Set<String>? unlockedCountryIds,
    Set<String>? unlockedLocationIds,
    Set<String>? discoveredSpeciesIds,
    List<Catch>? trophies,
    Map<String, int>? speciesCounts,
    Map<String, int>? speciesBestGrams,
    int? skillPoints,
    Map<String, int>? skills,
    DateTime? premiumUntil,
    int? premiumTier,
    String? activeTournamentId,
    int? tournamentScore,
    DateTime? tournamentEndsAt,
    int? tournamentWins,
    DateTime? lastDailyClaim,
    int? dailyStreak,
    DateTime? lastEnergyAt,
    String? dailyTaskDate,
    Map<String, int>? dailyProgress,
    Set<String>? dailyClaimed,
    Set<String>? purchasedTips,
  }) =>
      Player(
        nickname: nickname ?? this.nickname,
        level: level ?? this.level,
        totalCaughtGrams: totalCaughtGrams ?? this.totalCaughtGrams,
        energy: energy ?? this.energy,
        wallet: wallet ?? this.wallet,
        inventory: inventory ?? this.inventory,
        loadout: loadout ?? this.loadout,
        unlockedContinentIds: unlockedContinentIds ?? this.unlockedContinentIds,
        unlockedCountryIds: unlockedCountryIds ?? this.unlockedCountryIds,
        unlockedLocationIds: unlockedLocationIds ?? this.unlockedLocationIds,
        discoveredSpeciesIds: discoveredSpeciesIds ?? this.discoveredSpeciesIds,
        trophies: trophies ?? this.trophies,
        speciesCounts: speciesCounts ?? this.speciesCounts,
        speciesBestGrams: speciesBestGrams ?? this.speciesBestGrams,
        skillPoints: skillPoints ?? this.skillPoints,
        skills: skills ?? this.skills,
        premiumUntil: premiumUntil ?? this.premiumUntil,
        premiumTier: premiumTier ?? this.premiumTier,
        activeTournamentId: activeTournamentId ?? this.activeTournamentId,
        tournamentScore: tournamentScore ?? this.tournamentScore,
        tournamentEndsAt: tournamentEndsAt ?? this.tournamentEndsAt,
        tournamentWins: tournamentWins ?? this.tournamentWins,
        lastDailyClaim: lastDailyClaim ?? this.lastDailyClaim,
        dailyStreak: dailyStreak ?? this.dailyStreak,
        lastEnergyAt: lastEnergyAt ?? this.lastEnergyAt,
        dailyTaskDate: dailyTaskDate ?? this.dailyTaskDate,
        dailyProgress: dailyProgress ?? this.dailyProgress,
        dailyClaimed: dailyClaimed ?? this.dailyClaimed,
        purchasedTips: purchasedTips ?? this.purchasedTips,
      );

  Map<String, Object?> toJson() => {
        'nickname': nickname,
        'level': level,
        'totalCaughtGrams': totalCaughtGrams,
        'energy': energy,
        'wallet': wallet.toJson(),
        'inventory': inventory.map((e) => e.toJson()).toList(),
        'loadout': loadout.toJson(),
        'unlockedContinentIds': unlockedContinentIds.toList(),
        'unlockedCountryIds': unlockedCountryIds.toList(),
        'unlockedLocationIds': unlockedLocationIds.toList(),
        'discoveredSpeciesIds': discoveredSpeciesIds.toList(),
        'trophies': trophies.map((c) => c.toJson()).toList(),
        'speciesCounts': speciesCounts,
        'speciesBestGrams': speciesBestGrams,
        'skillPoints': skillPoints,
        'skills': skills,
        'premiumUntil': premiumUntil?.toIso8601String(),
        'premiumTier': premiumTier,
        'activeTournamentId': activeTournamentId,
        'tournamentScore': tournamentScore,
        'tournamentEndsAt': tournamentEndsAt?.toIso8601String(),
        'tournamentWins': tournamentWins,
        'lastDailyClaim': lastDailyClaim?.toIso8601String(),
        'dailyStreak': dailyStreak,
        'lastEnergyAt': lastEnergyAt?.toIso8601String(),
        'dailyTaskDate': dailyTaskDate,
        'dailyProgress': dailyProgress,
        'dailyClaimed': dailyClaimed.toList(),
        'purchasedTips': purchasedTips.toList(),
      };

  factory Player.fromJson(Map<String, Object?> j) => Player(
        nickname: j['nickname'] as String? ?? 'Рыбак',
        level: (j['level'] as num?)?.toInt() ?? 1,
        totalCaughtGrams: (j['totalCaughtGrams'] as num?)?.toInt() ?? 0,
        energy: (j['energy'] as num?)?.toInt() ?? 100,
        wallet: Wallet.fromJson(
            (j['wallet'] as Map?)?.cast<String, Object?>() ?? const {}),
        inventory: ((j['inventory'] as List?) ?? const [])
            .map((e) => InventoryEntry.fromJson((e as Map).cast()))
            .toList(),
        loadout: Loadout.fromJson(
            (j['loadout'] as Map?)?.cast<String, Object?>() ?? const {}),
        unlockedContinentIds:
            ((j['unlockedContinentIds'] as List?) ?? const ['europe'])
                .cast<String>()
                .toSet(),
        unlockedCountryIds:
            ((j['unlockedCountryIds'] as List?) ?? const ['ru'])
                .cast<String>()
                .toSet(),
        unlockedLocationIds:
            ((j['unlockedLocationIds'] as List?) ?? const ['ru_ladoga'])
                .cast<String>()
                .toSet(),
        discoveredSpeciesIds:
            ((j['discoveredSpeciesIds'] as List?) ?? const [])
                .cast<String>()
                .toSet(),
        trophies: ((j['trophies'] as List?) ?? const [])
            .map((e) => Catch.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        speciesCounts: ((j['speciesCounts'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        speciesBestGrams: ((j['speciesBestGrams'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        skillPoints: (j['skillPoints'] as num?)?.toInt() ?? 0,
        skills: ((j['skills'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        premiumUntil: j['premiumUntil'] == null
            ? null
            : DateTime.tryParse(j['premiumUntil'] as String),
        premiumTier: (j['premiumTier'] as num?)?.toInt() ?? 0,
        activeTournamentId: j['activeTournamentId'] as String? ?? '',
        tournamentScore: (j['tournamentScore'] as num?)?.toInt() ?? 0,
        tournamentEndsAt: j['tournamentEndsAt'] == null
            ? null
            : DateTime.tryParse(j['tournamentEndsAt'] as String),
        tournamentWins: (j['tournamentWins'] as num?)?.toInt() ?? 0,
        lastDailyClaim: j['lastDailyClaim'] == null
            ? null
            : DateTime.tryParse(j['lastDailyClaim'] as String),
        dailyStreak: (j['dailyStreak'] as num?)?.toInt() ?? 0,
        lastEnergyAt: j['lastEnergyAt'] == null
            ? null
            : DateTime.tryParse(j['lastEnergyAt'] as String),
        dailyTaskDate: j['dailyTaskDate'] as String? ?? '',
        dailyProgress: ((j['dailyProgress'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        dailyClaimed:
            ((j['dailyClaimed'] as List?) ?? const []).cast<String>().toSet(),
        purchasedTips:
            ((j['purchasedTips'] as List?) ?? const []).cast<String>().toSet(),
      );
}
