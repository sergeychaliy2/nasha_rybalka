import 'package:flutter/material.dart';

/// Ветка древа навыков (как в ARK Raiders): три направления развития рыбака.
enum SkillBranch { mastery, tackle, economy }

/// Узел навыка: прокачиваемый перк. Эффект задаётся ключом и приростом за
/// уровень; разблокировка — по необязательному предшественнику [prereq].
class SkillNode {
  const SkillNode({
    required this.id,
    required this.branch,
    required this.title,
    required this.description,
    required this.icon,
    required this.maxLevel,
    required this.effectKey,
    required this.effectPerLevel,
    this.prereq,
  });

  final String id;
  final SkillBranch branch;
  final String title;
  final String description;
  final IconData icon;
  final int maxLevel;
  final String effectKey;
  final double effectPerLevel;
  final String? prereq; // id узла, который должен иметь уровень ≥ 1

  /// Человекочитаемое значение прироста (умножается на [n] уровней).
  String valueText(int n) {
    final v = effectPerLevel * n;
    switch (effectKey) {
      case 'strikeWindow':
        return '+${v.toStringAsFixed(2)} с к подсечке';
      case 'breakForgive':
        return '+${v.toStringAsFixed(2)} с запаса на обрыв';
      case 'lineForgive':
        return '+${v.toStringAsFixed(2)} с до схода';
      case 'reelGain':
        return '+${(v * 100).round()}% к подмотке';
      case 'extraBait':
        return '+${v.toStringAsFixed(0)} наживки за покупку';
      case 'biteBonus':
        return '+${(v * 100).round()}% к клёву';
      case 'fightProgress':
        return '+${(v * 100).round()}% к вываживанию';
      case 'trophyBias':
        return '+${(v * 100).round()}% к весу рыбы';
      case 'dangerSlow':
        return '−${(v * 100).round()}% риска обрыва';
      case 'goldChance':
        return '+${(v * 100).round()}% шанс золота';
      case 'silverPct':
        return '+${(v * 100).round()}% серебра';
      case 'xpPct':
        return '+${(v * 100).round()}% опыта';
      case 'unlockDiscount':
        return '−${(v * 100).round()}% за открытие водоёма';
      case 'shopDiscount':
        return '−${(v * 100).round()}% в магазине';
      case 'salvagePct':
        return '+${(v * 100).round()}% серебра за утиль';
      case 'xpKeepPct':
        return '+${(v * 100).round()}% опыта за «Забрать»';
      case 'goldTrophyBonus':
        return '+${v.toStringAsFixed(0)} золота за трофей';
      default:
        return '+${(v * 100).round()}%';
    }
  }

  /// Прирост за один уровень (для подписи на узле).
  String get perLevelText => valueText(1);

  /// Глубина узла в ветке (0 — базовый, растёт по цепочке предшественников).
  int get depth {
    var d = 0;
    var n = this;
    while (n.prereq != null) {
      final p = SeedSkills.byId(n.prereq!);
      if (p == null) break;
      d++;
      n = p;
    }
    return d;
  }

  double get _branchMult => switch (branch) {
        SkillBranch.mastery => 1.3,
        SkillBranch.tackle => 1.15,
        SkillBranch.economy => 1.0,
      };

  /// Сколько ОПЫТА МАСТЕРСТВА стоит поднять навык с [currentLevel] на
  /// следующий. Дорого и по нарастающей: глубже в ветке и выше уровень —
  /// дороже (узлы открываются только по цепочке от корня).
  int xpCostFor(int currentLevel) {
    final raw = 50 * (currentLevel + 1) * (1 + depth * 0.6) * _branchMult;
    return (raw / 5).round() * 5; // округление до 5
  }
}

/// Встроенное древо навыков.
abstract final class SeedSkills {
  static const nodes = <SkillNode>[
    // ======================= МАСТЕРСТВО (ловля/борьба) =======================
    SkillNode(
      id: 'm_bite',
      branch: SkillBranch.mastery,
      title: 'Острый глаз',
      description: 'Замечаешь поклёвку раньше — рыба берёт активнее.',
      icon: Icons.visibility,
      maxLevel: 5,
      effectKey: 'biteBonus',
      effectPerLevel: 0.05,
    ),
    SkillNode(
      id: 'm_strike',
      branch: SkillBranch.mastery,
      title: 'Реакция',
      description: 'Больше времени на подсечку после поклёвки.',
      icon: Icons.bolt,
      maxLevel: 3,
      effectKey: 'strikeWindow',
      effectPerLevel: 0.25,
      prereq: 'm_bite',
    ),
    SkillNode(
      id: 'm_fight',
      branch: SkillBranch.mastery,
      title: 'Терпение',
      description: 'Вываживание идёт быстрее при удержании зелёной зоны.',
      icon: Icons.fitness_center,
      maxLevel: 5,
      effectKey: 'fightProgress',
      effectPerLevel: 0.07,
      prereq: 'm_strike',
    ),
    SkillNode(
      id: 'm_trophy',
      branch: SkillBranch.mastery,
      title: 'Чутьё на трофей',
      description: 'Попадается рыба покрупнее — растёт вес улова.',
      icon: Icons.workspace_premium,
      maxLevel: 4,
      effectKey: 'trophyBias',
      effectPerLevel: 0.05,
      prereq: 'm_strike',
    ),
    SkillNode(
      id: 'm_calm',
      branch: SkillBranch.mastery,
      title: 'Хладнокровие',
      description: 'Перетяг копится медленнее — меньше шанс обрыва.',
      icon: Icons.self_improvement,
      maxLevel: 3,
      effectKey: 'dangerSlow',
      effectPerLevel: 0.10,
      prereq: 'm_fight',
    ),
    SkillNode(
      id: 'm_pump',
      branch: SkillBranch.mastery,
      title: 'Работа удилищем',
      description: 'Качаешь рыбу к берегу — подмотка чуть эффективнее.',
      icon: Icons.cyclone,
      maxLevel: 4,
      effectKey: 'reelGain',
      effectPerLevel: 0.03,
      prereq: 'm_fight',
    ),
    SkillNode(
      id: 'm_master',
      branch: SkillBranch.mastery,
      title: 'Мастер заброса',
      description: 'Опыт рыбака — рыба берёт ещё охотнее.',
      icon: Icons.stars,
      maxLevel: 5,
      effectKey: 'biteBonus',
      effectPerLevel: 0.04,
      prereq: 'm_trophy',
    ),
    SkillNode(
      id: 'm_steel',
      branch: SkillBranch.mastery,
      title: 'Стальные нервы',
      description: 'Дольше выдерживаешь рывки на грани обрыва.',
      icon: Icons.shield,
      maxLevel: 3,
      effectKey: 'breakForgive',
      effectPerLevel: 0.10,
      prereq: 'm_calm',
    ),
    SkillNode(
      id: 'm_focus',
      branch: SkillBranch.mastery,
      title: 'Концентрация',
      description: 'Ещё больше времени на подсечку.',
      icon: Icons.gps_fixed,
      maxLevel: 3,
      effectKey: 'strikeWindow',
      effectPerLevel: 0.15,
      prereq: 'm_pump',
    ),
    SkillNode(
      id: 'm_legend',
      branch: SkillBranch.mastery,
      title: 'Охотник за рекордом',
      description: 'Чаще попадается по-настоящему крупная рыба.',
      icon: Icons.emoji_events,
      maxLevel: 4,
      effectKey: 'trophyBias',
      effectPerLevel: 0.04,
      prereq: 'm_master',
    ),
    SkillNode(
      id: 'm_zen',
      branch: SkillBranch.mastery,
      title: 'Дзен рыбака',
      description: 'Перетяг растёт ещё медленнее — рыба устаёт первой.',
      icon: Icons.spa,
      maxLevel: 3,
      effectKey: 'dangerSlow',
      effectPerLevel: 0.07,
      prereq: 'm_steel',
    ),
    SkillNode(
      id: 'm_sense',
      branch: SkillBranch.mastery,
      title: 'Шестое чувство',
      description: 'Будто читаешь воду — клёв заметно лучше.',
      icon: Icons.psychology,
      maxLevel: 3,
      effectKey: 'biteBonus',
      effectPerLevel: 0.05,
      prereq: 'm_legend',
    ),
    SkillNode(
      id: 'm_grand',
      branch: SkillBranch.mastery,
      title: 'Гранд-мастер',
      description: 'Вываживание любой рыбы даётся заметно легче.',
      icon: Icons.military_tech,
      maxLevel: 5,
      effectKey: 'fightProgress',
      effectPerLevel: 0.06,
      prereq: 'm_zen',
    ),
    SkillNode(
      id: 'm_apex',
      branch: SkillBranch.mastery,
      title: 'Зов глубины',
      description: 'Трофеи клюют как никогда часто.',
      icon: Icons.whatshot,
      maxLevel: 5,
      effectKey: 'trophyBias',
      effectPerLevel: 0.05,
      prereq: 'm_grand',
    ),
    SkillNode(
      id: 'm_god',
      branch: SkillBranch.mastery,
      title: 'Венец мастерства',
      description: 'Легендарное чутьё: рыба будто сама идёт на крючок.',
      icon: Icons.auto_awesome,
      maxLevel: 3,
      effectKey: 'biteBonus',
      effectPerLevel: 0.05,
      prereq: 'm_apex',
    ),
    // ============================= СНАСТЬ =============================
    SkillNode(
      id: 't_bait',
      branch: SkillBranch.tackle,
      title: 'Бережливость',
      description: 'Шанс не израсходовать наживку/приманку при использовании.',
      icon: Icons.recycling,
      maxLevel: 5,
      effectKey: 'baitSave',
      effectPerLevel: 0.07,
    ),
    SkillNode(
      id: 't_break',
      branch: SkillBranch.tackle,
      title: 'Крепкая рука',
      description: 'Дольше держишь перетяг без обрыва.',
      icon: Icons.back_hand,
      maxLevel: 3,
      effectKey: 'breakForgive',
      effectPerLevel: 0.12,
      prereq: 't_bait',
    ),
    SkillNode(
      id: 't_buy',
      branch: SkillBranch.tackle,
      title: 'Запасливый',
      description: 'Покупая наживку/приманку, получаешь больше за те же деньги.',
      icon: Icons.inventory_2,
      maxLevel: 3,
      effectKey: 'extraBait',
      effectPerLevel: 1.0,
      prereq: 't_bait',
    ),
    SkillNode(
      id: 't_reel',
      branch: SkillBranch.tackle,
      title: 'Плавный ход',
      description: 'Катушка эффективнее подматывает на вываживании.',
      icon: Icons.settings,
      maxLevel: 5,
      effectKey: 'reelGain',
      effectPerLevel: 0.04,
      prereq: 't_break',
    ),
    SkillNode(
      id: 't_care',
      branch: SkillBranch.tackle,
      title: 'Уход за снастью',
      description: 'Ухоженная снасть надёжнее — реже подводит на рывке.',
      icon: Icons.build,
      maxLevel: 3,
      effectKey: 'breakForgive',
      effectPerLevel: 0.08,
      prereq: 't_buy',
    ),
    SkillNode(
      id: 't_slack',
      branch: SkillBranch.tackle,
      title: 'Чуткая снасть',
      description: 'Больше времени, прежде чем рыба сорвётся при слабине.',
      icon: Icons.timer,
      maxLevel: 3,
      effectKey: 'lineForgive',
      effectPerLevel: 0.18,
      prereq: 't_reel',
    ),
    SkillNode(
      id: 't_smooth',
      branch: SkillBranch.tackle,
      title: 'Шёлковый фрикцион',
      description: 'Подмотка ещё эффективнее на тяжёлой рыбе.',
      icon: Icons.tune,
      maxLevel: 5,
      effectKey: 'reelGain',
      effectPerLevel: 0.03,
      prereq: 't_reel',
    ),
    SkillNode(
      id: 't_stock',
      branch: SkillBranch.tackle,
      title: 'Оптовик',
      description: 'Ещё больше расходников за ту же цену в лавке.',
      icon: Icons.warehouse,
      maxLevel: 3,
      effectKey: 'extraBait',
      effectPerLevel: 1.0,
      prereq: 't_care',
    ),
    SkillNode(
      id: 't_line',
      branch: SkillBranch.tackle,
      title: 'Запас лески',
      description: 'Ещё больше форы до схода при слабине.',
      icon: Icons.straighten,
      maxLevel: 3,
      effectKey: 'lineForgive',
      effectPerLevel: 0.15,
      prereq: 't_slack',
    ),
    SkillNode(
      id: 't_drag',
      branch: SkillBranch.tackle,
      title: 'Тонкая настройка',
      description: 'Точно выставленный фрикцион прощает перетяг дольше.',
      icon: Icons.speed,
      maxLevel: 3,
      effectKey: 'breakForgive',
      effectPerLevel: 0.10,
      prereq: 't_smooth',
    ),
    SkillNode(
      id: 't_thrift',
      branch: SkillBranch.tackle,
      title: 'Рачительность',
      description: 'Ещё выше шанс сохранить наживку.',
      icon: Icons.energy_savings_leaf,
      maxLevel: 4,
      effectKey: 'baitSave',
      effectPerLevel: 0.05,
      prereq: 't_stock',
    ),
    SkillNode(
      id: 't_power',
      branch: SkillBranch.tackle,
      title: 'Силовая катушка',
      description: 'Мощная протяжка — подмотка ещё результативнее.',
      icon: Icons.sync,
      maxLevel: 5,
      effectKey: 'reelGain',
      effectPerLevel: 0.04,
      prereq: 't_drag',
    ),
    SkillNode(
      id: 't_cast',
      branch: SkillBranch.tackle,
      title: 'Точный заброс',
      description: 'Кладёшь оснастку точно в рыбную точку — клёв выше.',
      icon: Icons.my_location,
      maxLevel: 4,
      effectKey: 'biteBonus',
      effectPerLevel: 0.04,
      prereq: 't_thrift',
    ),
    SkillNode(
      id: 't_master',
      branch: SkillBranch.tackle,
      title: 'Снаряжение мастера',
      description: 'Идеально собранная снасть подматывает максимально плавно.',
      icon: Icons.construction,
      maxLevel: 5,
      effectKey: 'reelGain',
      effectPerLevel: 0.05,
      prereq: 't_power',
    ),
    SkillNode(
      id: 't_legend',
      branch: SkillBranch.tackle,
      title: 'Ни грамма впустую',
      description: 'Расходники почти не тратятся зря.',
      icon: Icons.hardware,
      maxLevel: 3,
      effectKey: 'baitSave',
      effectPerLevel: 0.05,
      prereq: 't_master',
    ),
    // ============================ ЭКОНОМИКА ============================
    SkillNode(
      id: 'e_silver',
      branch: SkillBranch.economy,
      title: 'Торговец',
      description: 'Больше серебра за «Забрать».',
      icon: Icons.savings,
      maxLevel: 5,
      effectKey: 'silverPct',
      effectPerLevel: 0.06,
    ),
    SkillNode(
      id: 'e_xp',
      branch: SkillBranch.economy,
      title: 'Бывалый',
      description: 'Больше опыта за «Отпустить».',
      icon: Icons.school,
      maxLevel: 5,
      effectKey: 'xpPct',
      effectPerLevel: 0.06,
    ),
    SkillNode(
      id: 'e_unlock',
      branch: SkillBranch.economy,
      title: 'Связи',
      description: 'Дешевле открывать новые водоёмы.',
      icon: Icons.handshake,
      maxLevel: 4,
      effectKey: 'unlockDiscount',
      effectPerLevel: 0.05,
      prereq: 'e_silver',
    ),
    SkillNode(
      id: 'e_gold',
      branch: SkillBranch.economy,
      title: 'Золотая жила',
      description: 'Шанс получить золото за любой улов.',
      icon: Icons.diamond,
      maxLevel: 4,
      effectKey: 'goldChance',
      effectPerLevel: 0.05,
      prereq: 'e_silver',
    ),
    SkillNode(
      id: 'e_shop',
      branch: SkillBranch.economy,
      title: 'Скидка в лавке',
      description: 'Снасти в магазине дешевле.',
      icon: Icons.sell,
      maxLevel: 5,
      effectKey: 'shopDiscount',
      effectPerLevel: 0.04,
      prereq: 'e_xp',
    ),
    SkillNode(
      id: 'e_rich',
      branch: SkillBranch.economy,
      title: 'Меценат',
      description: 'Ещё больше серебра за крупную рыбу.',
      icon: Icons.account_balance,
      maxLevel: 5,
      effectKey: 'silverPct',
      effectPerLevel: 0.05,
      prereq: 'e_unlock',
    ),
    SkillNode(
      id: 'e_salvage',
      branch: SkillBranch.economy,
      title: 'Старьёвщик',
      description: 'Больше серебра при утилизации снаряжения.',
      icon: Icons.restore_from_trash,
      maxLevel: 4,
      effectKey: 'salvagePct',
      effectPerLevel: 0.05,
      prereq: 'e_gold',
    ),
    SkillNode(
      id: 'e_keepxp',
      branch: SkillBranch.economy,
      title: 'Полевые заметки',
      description: 'Теперь немного опыта капает и за «Забрать».',
      icon: Icons.menu_book,
      maxLevel: 4,
      effectKey: 'xpKeepPct',
      effectPerLevel: 0.05,
      prereq: 'e_shop',
    ),
    SkillNode(
      id: 'e_trade',
      branch: SkillBranch.economy,
      title: 'Перекупщик',
      description: 'Ещё ниже цены в магазине.',
      icon: Icons.storefront,
      maxLevel: 4,
      effectKey: 'shopDiscount',
      effectPerLevel: 0.03,
      prereq: 'e_rich',
    ),
    SkillNode(
      id: 'e_jackpot',
      branch: SkillBranch.economy,
      title: 'Везунчик',
      description: 'Выше шанс золота за улов.',
      icon: Icons.casino,
      maxLevel: 4,
      effectKey: 'goldChance',
      effectPerLevel: 0.04,
      prereq: 'e_salvage',
    ),
    SkillNode(
      id: 'e_scholar',
      branch: SkillBranch.economy,
      title: 'Натуралист',
      description: 'Ещё больше опыта за «Отпустить».',
      icon: Icons.history_edu,
      maxLevel: 4,
      effectKey: 'xpPct',
      effectPerLevel: 0.05,
      prereq: 'e_keepxp',
    ),
    SkillNode(
      id: 'e_baron',
      branch: SkillBranch.economy,
      title: 'Барон',
      description: 'Серебро за рыбу течёт ещё щедрее.',
      icon: Icons.paid,
      maxLevel: 5,
      effectKey: 'silverPct',
      effectPerLevel: 0.05,
      prereq: 'e_trade',
    ),
    SkillNode(
      id: 'e_fortune',
      branch: SkillBranch.economy,
      title: 'Призовой фонд',
      description: 'За каждый трофей дают сверху немного золота.',
      icon: Icons.redeem,
      maxLevel: 3,
      effectKey: 'goldTrophyBonus',
      effectPerLevel: 1.0,
      prereq: 'e_jackpot',
    ),
    SkillNode(
      id: 'e_sage',
      branch: SkillBranch.economy,
      title: 'Серый кардинал',
      description: 'Открытие новых водоёмов ещё дешевле.',
      icon: Icons.lightbulb,
      maxLevel: 4,
      effectKey: 'unlockDiscount',
      effectPerLevel: 0.05,
      prereq: 'e_scholar',
    ),
    SkillNode(
      id: 'e_tycoon',
      branch: SkillBranch.economy,
      title: 'Магнат',
      description: 'Вершина торговли: максимум серебра за улов.',
      icon: Icons.monetization_on,
      maxLevel: 5,
      effectKey: 'silverPct',
      effectPerLevel: 0.06,
      prereq: 'e_baron',
    ),
    SkillNode(
      id: 'e_mogul',
      branch: SkillBranch.economy,
      title: 'Золотой век',
      description: 'Золото попадается заметно чаще.',
      icon: Icons.attach_money,
      maxLevel: 4,
      effectKey: 'goldChance',
      effectPerLevel: 0.05,
      prereq: 'e_tycoon',
    ),
  ];

  static SkillNode? byId(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}

/// Суммарные эффекты навыков, посчитанные по уровням узлов игрока.
class SkillEffects {
  const SkillEffects({
    this.biteBonus = 0,
    this.strikeWindow = 0,
    this.fightProgress = 0,
    this.baitSave = 0,
    this.breakForgive = 0,
    this.reelGain = 0,
    this.extraBait = 0,
    this.silverPct = 0,
    this.xpPct = 0,
    this.unlockDiscount = 0,
    this.goldChance = 0,
    this.lineForgive = 0,
    this.trophyBias = 0,
    this.shopDiscount = 0,
    this.dangerSlow = 0,
    this.salvagePct = 0,
    this.xpKeepPct = 0,
    this.goldTrophyBonus = 0,
  });

  final double biteBonus;
  final double strikeWindow;
  final double fightProgress;
  final double baitSave;
  final double breakForgive;
  final double reelGain;
  final int extraBait;
  final double silverPct;
  final double xpPct;
  final double unlockDiscount;
  final double goldChance;
  final double lineForgive;
  final double trophyBias;
  final double shopDiscount;
  final double dangerSlow;
  final double salvagePct;
  final double xpKeepPct;
  final int goldTrophyBonus;

  factory SkillEffects.from(Map<String, int> skills) {
    final acc = <String, double>{};
    for (final n in SeedSkills.nodes) {
      final lvl = skills[n.id] ?? 0;
      if (lvl <= 0) continue;
      acc[n.effectKey] = (acc[n.effectKey] ?? 0) + n.effectPerLevel * lvl;
    }
    return SkillEffects(
      biteBonus: acc['biteBonus'] ?? 0,
      strikeWindow: acc['strikeWindow'] ?? 0,
      fightProgress: acc['fightProgress'] ?? 0,
      baitSave: (acc['baitSave'] ?? 0).clamp(0, 0.9),
      breakForgive: acc['breakForgive'] ?? 0,
      reelGain: acc['reelGain'] ?? 0,
      extraBait: (acc['extraBait'] ?? 0).round(),
      silverPct: acc['silverPct'] ?? 0,
      xpPct: acc['xpPct'] ?? 0,
      unlockDiscount: (acc['unlockDiscount'] ?? 0).clamp(0, 0.6),
      goldChance: (acc['goldChance'] ?? 0).clamp(0, 0.9),
      lineForgive: acc['lineForgive'] ?? 0,
      trophyBias: acc['trophyBias'] ?? 0,
      shopDiscount: (acc['shopDiscount'] ?? 0).clamp(0, 0.6),
      dangerSlow: (acc['dangerSlow'] ?? 0).clamp(0, 0.6),
      salvagePct: (acc['salvagePct'] ?? 0).clamp(0, 0.8),
      xpKeepPct: (acc['xpKeepPct'] ?? 0).clamp(0, 0.6),
      goldTrophyBonus: (acc['goldTrophyBonus'] ?? 0).round(),
    );
  }
}
