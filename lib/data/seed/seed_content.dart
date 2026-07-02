import 'dart:math' as math;

import '../../domain/entities/fish_species.dart';
import '../../domain/entities/fishing_location.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/world.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/fishing_enums.dart';
import '../../domain/value_objects/weight.dart';

/// Встроенный стартовый контент игры (Dart‑сид).
///
/// Это «данные», отделённые от движка: добавление страны/рыбы/снасти — правка
/// этого файла (позже — JSON‑ассета) без изменения логики. Все фоны временно
/// ссылаются на единственный placeholder; реальные фото подменяются по путям.
abstract final class SeedContent {
  static const _bg = 'assets/locations/misty_pier_dawn.png';

  // --- Мир: континенты ----------------------------------------------------

  static const continents = <Continent>[
    Continent(
      id: 'europe',
      name: 'Европа',
      unlockLevel: 1,
      unlockCost: Money.silver(0),
      countryIds: ['ru', 'no', 'de'],
    ),
    Continent(
      id: 'asia',
      name: 'Азия',
      unlockLevel: 6,
      unlockCost: Money.silver(8000),
      countryIds: ['jp', 'th'],
    ),
    Continent(
      id: 'north_america',
      name: 'Северная Америка',
      unlockLevel: 10,
      unlockCost: Money.silver(18000),
      countryIds: ['ca', 'us'],
    ),
    Continent(
      id: 'south_america',
      name: 'Южная Америка',
      unlockLevel: 14,
      unlockCost: Money.silver(30000),
      countryIds: ['br'],
    ),
    Continent(
      id: 'africa',
      name: 'Африка',
      unlockLevel: 18,
      unlockCost: Money.silver(45000),
      countryIds: ['eg'],
    ),
    Continent(
      id: 'oceania',
      name: 'Австралия и Океания',
      unlockLevel: 22,
      unlockCost: Money.silver(62000),
      countryIds: ['au'],
    ),
  ];

  // --- Мир: страны --------------------------------------------------------

  static const countries = <Country>[
    Country(
      id: 'ru',
      name: 'Россия',
      continentId: 'europe',
      unlockLevel: 1,
      unlockCost: Money.silver(0),
      travelMinutes: 0,
      locationIds: [
        'ru_ladoga', 'ru_seliger', 'ru_rybinsk', 'ru_don', 'ru_akhtuba',
        'ru_yenisei', 'ru_baikal', 'ru_amur', 'ru_kamchatka',
      ],
    ),
    Country(
      id: 'no',
      name: 'Норвегия',
      continentId: 'europe',
      unlockLevel: 4,
      unlockCost: Money.silver(3500),
      travelMinutes: 180,
      locationIds: ['no_fjord_edge', 'no_cold_lake'],
    ),
    Country(
      id: 'de',
      name: 'Германия',
      continentId: 'europe',
      unlockLevel: 7,
      unlockCost: Money.silver(6000),
      travelMinutes: 150,
      locationIds: ['de_canal', 'de_forest_lake'],
    ),
    Country(
      id: 'jp',
      name: 'Япония',
      continentId: 'asia',
      unlockLevel: 6,
      unlockCost: Money.silver(9000),
      travelMinutes: 300,
      locationIds: ['jp_mountain_stream', 'jp_koi_pond'],
    ),
    Country(
      id: 'th',
      name: 'Таиланд',
      continentId: 'asia',
      unlockLevel: 9,
      unlockCost: Money.silver(12000),
      travelMinutes: 360,
      locationIds: ['th_jungle_river'],
    ),
    Country(
      id: 'ca',
      name: 'Канада',
      continentId: 'north_america',
      unlockLevel: 10,
      unlockCost: Money.silver(20000),
      travelMinutes: 420,
      locationIds: ['ca_pine_lake', 'ca_rapids'],
    ),
    Country(
      id: 'us',
      name: 'США',
      continentId: 'north_america',
      unlockLevel: 12,
      unlockCost: Money.silver(26000),
      travelMinutes: 450,
      locationIds: ['us_big_lake'],
    ),
    Country(
      id: 'br',
      name: 'Бразилия',
      continentId: 'south_america',
      unlockLevel: 14,
      unlockCost: Money.silver(32000),
      travelMinutes: 540,
      locationIds: ['br_amazon_bend'],
    ),
    Country(
      id: 'eg',
      name: 'Египет',
      continentId: 'africa',
      unlockLevel: 18,
      unlockCost: Money.silver(46000),
      travelMinutes: 600,
      locationIds: ['eg_nile_bank'],
    ),
    Country(
      id: 'au',
      name: 'Австралия',
      continentId: 'oceania',
      unlockLevel: 22,
      unlockCost: Money.silver(62000),
      travelMinutes: 720,
      locationIds: ['au_reef_flat'],
    ),
  ];

  // --- Мир: локации -------------------------------------------------------

  // final (не const): зарыбление РФ собирается хелпером _spawn(...).
  static final locations = <FishingLocation>[
    // --- Россия: реальные водоёмы (запад → восток) ---
    FishingLocation(
      id: 'ru_ladoga',
      name: 'Ладожское озеро',
      description:
          'Крупнейшее озеро Европы. Шхеры, холодная чистая вода: окунь и судак '
          'у каменных гряд, щука в заливах, ход лосося по осени.',
      countryId: 'ru',
      entryCost: Money.silver(0),
      depthProfile:
          DepthProfile(seed: 311060, maxDepthMeters: 9, shape: 'dropOff'),
      backdropAssets: ['assets/locations/ru_ladoga.png'],
      species: [
        _spawn('perch', 80, 1300, f: 0.34, s: 0.42),
        _spawn('zander', 600, 5500, f: 0.10, s: 0.38),
        _spawn('pike', 700, 7000, f: 0.12, s: 0.40),
        _spawn('roach', 50, 600, f: 0.42, s: 0.05),
        _spawn('bream', 300, 3000, f: 0.34, s: 0.05),
        _spawn('burbot', 400, 4000, f: 0.14, s: 0.10),
        _spawn('ruffe', 25, 180, f: 0.30, s: 0.04),
        _spawn('whitefish', 300, 3500, f: 0.16, s: 0.18),
        _spawn('smelt', 25, 220, f: 0.26, s: 0.06),
        _spawn('salmon', 2000, 10000, f: 0.04, s: 0.16),
      ],
      trash: [
        TrashSpawn(id: 'snag', name: 'Коряга', chance: 0.05, reward: CurrencyType.silver, rewardMin: 5, rewardMax: 25),
      ],
      morningBonusMinutes: 10,
    ),
    FishingLocation(
      id: 'ru_seliger',
      name: 'Озеро Селигер',
      description:
          'Плёсы и протоки среди островов Валдая. Классика поплавка: лещ и '
          'плотва у тростника, щука на жерлицы.',
      countryId: 'ru',
      entryCost: Money.silver(300),
      depthProfile: DepthProfile(seed: 331572, maxDepthMeters: 5, shape: 'flat'),
      backdropAssets: ['assets/locations/ru_seliger.png'],
      species: [
        _spawn('bream', 300, 2800, f: 0.40, s: 0.06),
        _spawn('roach', 50, 700, f: 0.42, s: 0.05),
        _spawn('pike', 800, 8000, f: 0.10, s: 0.46),
        _spawn('perch', 90, 1100, f: 0.32, s: 0.42),
        _spawn('crucian', 80, 1600, f: 0.36, s: 0.04),
        _spawn('rudd', 50, 900, f: 0.34, s: 0.05),
        _spawn('tench', 300, 3000, f: 0.20, s: 0.04),
        _spawn('ide', 200, 2500, f: 0.22, s: 0.12),
        _spawn('silver_bream', 60, 700, f: 0.30, s: 0.04),
        _spawn('ruffe', 25, 180, f: 0.28, s: 0.04),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'ru_rybinsk',
      name: 'Рыбинское вдхр.',
      description:
          '«Рыбинское море» на Волге. Просторы и затопленный коряжник: '
          'трофейный судак и стаи леща над ямами.',
      countryId: 'ru',
      entryCost: Money.silver(800),
      depthProfile: DepthProfile(seed: 385840, maxDepthMeters: 7, shape: 'flat'),
      backdropAssets: ['assets/locations/ru_rybinsk.png'],
      species: [
        _spawn('bream', 400, 3200, f: 0.40, s: 0.06),
        _spawn('zander', 700, 6500, f: 0.10, s: 0.44),
        _spawn('pike', 900, 9000, f: 0.10, s: 0.44),
        _spawn('roach', 60, 700, f: 0.40, s: 0.05),
        _spawn('blue_bream', 100, 800, f: 0.30, s: 0.05),
        _spawn('sabrefish', 100, 1400, f: 0.22, s: 0.20),
        _spawn('bersh', 200, 1400, f: 0.10, s: 0.30),
        _spawn('burbot', 400, 5000, f: 0.12, s: 0.08),
        _spawn('perch', 90, 1300, f: 0.32, s: 0.40),
        _spawn('silver_bream', 60, 700, f: 0.30, s: 0.04),
      ],
      trash: [
        TrashSpawn(id: 'net', name: 'Старая сеть', chance: 0.05, reward: CurrencyType.silver, rewardMin: 10, rewardMax: 40),
      ],
    ),
    FishingLocation(
      id: 'ru_don',
      name: 'Река Дон',
      description:
          'Тихий Дон: песчаные косы и глинистые яры. Лещ и сазан на течении, '
          'судак по бровкам, сом в омутах.',
      countryId: 'ru',
      entryCost: Money.silver(1500),
      depthProfile: DepthProfile(seed: 401490, maxDepthMeters: 8, shape: 'ridge'),
      backdropAssets: ['assets/locations/ru_don.png'],
      species: [
        _spawn('bream', 400, 3000, f: 0.38, s: 0.06),
        _spawn('zander', 700, 6000, f: 0.10, s: 0.42),
        _spawn('wild_carp', 1500, 16000, f: 0.18, s: 0.04),
        _spawn('catfish', 2000, 35000, f: 0.05, s: 0.20),
        _spawn('asp', 500, 4000, f: 0.08, s: 0.38),
        _spawn('chub', 200, 3500, f: 0.20, s: 0.30),
        _spawn('sabrefish', 100, 1500, f: 0.22, s: 0.22),
        _spawn('rudd', 50, 1000, f: 0.34, s: 0.05),
        _spawn('roach', 60, 800, f: 0.40, s: 0.05),
        _spawn('silver_bream', 60, 750, f: 0.30, s: 0.04),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'ru_akhtuba',
      name: 'Ахтуба (Ниж. Волга)',
      description:
          'Легендарная пойма Волги и Ахтубы. Жерех бьёт на перекатах, судак '
          'и трофейный сом держатся по ямам.',
      countryId: 'ru',
      entryCost: Money.silver(2500),
      depthProfile: DepthProfile(seed: 467482, maxDepthMeters: 12, shape: 'pit'),
      backdropAssets: ['assets/locations/ru_akhtuba.png'],
      species: [
        _spawn('asp', 600, 4500, f: 0.08, s: 0.46),
        _spawn('zander', 800, 7000, f: 0.10, s: 0.44),
        _spawn('catfish', 3000, 50000, f: 0.06, s: 0.24),
        _spawn('wild_carp', 2000, 18000, f: 0.16, s: 0.04),
        _spawn('bream', 400, 3000, f: 0.38, s: 0.06),
        _spawn('pike', 900, 9000, f: 0.10, s: 0.40),
        _spawn('bersh', 200, 1400, f: 0.10, s: 0.30),
        _spawn('sabrefish', 100, 1600, f: 0.22, s: 0.22),
        _spawn('roach', 60, 800, f: 0.40, s: 0.05),
        _spawn('sterlet', 500, 5000, f: 0.06, s: 0.05),
        _spawn('sturgeon', 3000, 40000, f: 0.01, s: 0.04),
      ],
      trash: [],
      morningBonusMinutes: 12,
    ),
    FishingLocation(
      id: 'ru_yenisei',
      name: 'Река Енисей',
      description:
          'Могучая сибирская река. Хариус на перекатах, щука в заливах и '
          'осторожный таймень — мечта спиннингиста.',
      countryId: 'ru',
      entryCost: Money.silver(4200),
      depthProfile: DepthProfile(seed: 928581, maxDepthMeters: 10, shape: 'ridge'),
      backdropAssets: ['assets/locations/ru_yenisei.png'],
      species: [
        _spawn('grayling', 150, 2200, f: 0.32, s: 0.42),
        _spawn('lenok', 400, 6000, f: 0.10, s: 0.34),
        _spawn('pike', 900, 10000, f: 0.10, s: 0.44),
        _spawn('perch', 100, 1400, f: 0.32, s: 0.40),
        _spawn('whitefish', 300, 4000, f: 0.18, s: 0.18),
        _spawn('burbot', 400, 5500, f: 0.12, s: 0.08),
        _spawn('dace', 30, 400, f: 0.36, s: 0.10),
        _spawn('muksun', 500, 5000, f: 0.10, s: 0.10),
        _spawn('nelma', 2000, 18000, f: 0.02, s: 0.10),
        _spawn('taimen', 3000, 30000, f: 0.02, s: 0.10),
        _spawn('sterlet', 500, 6000, f: 0.05, s: 0.05),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'ru_baikal',
      name: 'Озеро Байкал',
      description:
          'Самое глубокое озеро планеты. Прозрачная ледяная вода: омуль на '
          'глубине, хариус у каменистых берегов.',
      countryId: 'ru',
      entryCost: Money.silver(6500),
      depthProfile:
          DepthProfile(seed: 107653, maxDepthMeters: 24, shape: 'dropOff'),
      backdropAssets: ['assets/locations/ru_baikal.png'],
      species: [
        _spawn('omul', 200, 2800, f: 0.30, s: 0.22),
        _spawn('grayling', 150, 2000, f: 0.30, s: 0.40),
        _spawn('whitefish', 300, 4500, f: 0.18, s: 0.18),
        _spawn('lenok', 400, 6000, f: 0.08, s: 0.32),
        _spawn('perch', 100, 1200, f: 0.32, s: 0.38),
        _spawn('pike', 800, 8000, f: 0.10, s: 0.40),
        _spawn('burbot', 400, 6000, f: 0.12, s: 0.08),
        _spawn('vendace', 30, 350, f: 0.30, s: 0.06),
        _spawn('taimen', 3000, 32000, f: 0.02, s: 0.09),
        _spawn('baikal_char', 800, 9000, f: 0.04, s: 0.14),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'ru_amur',
      name: 'Река Амур',
      description:
          'Великая дальневосточная река. Сазан и караси в протоках, щука-'
          'амурка и сомы у коряжников.',
      countryId: 'ru',
      entryCost: Money.silver(9000),
      depthProfile: DepthProfile(seed: 135148, maxDepthMeters: 14, shape: 'pit'),
      backdropAssets: ['assets/locations/ru_amur.png'],
      species: [
        _spawn('wild_carp', 2000, 18000, f: 0.20, s: 0.04),
        _spawn('white_amur', 2000, 25000, f: 0.12, s: 0.04),
        _spawn('silver_carp', 2000, 24000, f: 0.10, s: 0.03),
        _spawn('crucian', 120, 1800, f: 0.40, s: 0.04),
        _spawn('pike', 900, 10000, f: 0.10, s: 0.44),
        _spawn('catfish', 2500, 40000, f: 0.06, s: 0.22),
        _spawn('verkhoglyad', 800, 8000, f: 0.06, s: 0.34),
        _spawn('lenok', 400, 6000, f: 0.08, s: 0.30),
        _spawn('rotan', 40, 700, f: 0.34, s: 0.10),
        _spawn('kaluga', 5000, 80000, f: 0.01, s: 0.05),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'ru_kamchatka',
      name: 'Река Большая (Камчатка)',
      description:
          'Дикая камчатская река под вулканами. Ход тихоокеанского лосося, '
          'голец и микижа на перекатах.',
      countryId: 'ru',
      entryCost: Money.silver(14000),
      depthProfile:
          DepthProfile(seed: 156352, maxDepthMeters: 5, shape: 'ridge'),
      backdropAssets: ['assets/locations/ru_kamchatka.png'],
      species: [
        _spawn('char', 300, 4500, f: 0.28, s: 0.40),
        _spawn('mykiss', 500, 9000, f: 0.16, s: 0.42),
        _spawn('pink_salmon', 1000, 5000, f: 0.10, s: 0.40),
        _spawn('chum', 1500, 12000, f: 0.06, s: 0.34),
        _spawn('sockeye', 1500, 7000, f: 0.06, s: 0.32),
        _spawn('coho', 2000, 14000, f: 0.05, s: 0.30),
        _spawn('grayling', 150, 2000, f: 0.26, s: 0.34),
        _spawn('smelt', 25, 250, f: 0.22, s: 0.06),
        _spawn('brown_trout', 500, 8000, f: 0.10, s: 0.32),
        _spawn('chinook', 4000, 40000, f: 0.01, s: 0.06),
      ],
      trash: [],
      morningBonusMinutes: 10,
    ),
    // Норвегия
    FishingLocation(
      id: 'no_fjord_edge',
      name: 'Край фьорда',
      description:
          'Холодная глубокая вода у скал. Сюда заходит крупная форель, лосось и '
          'морской хищник — нужна крепкая снасть и эхолот.',
      countryId: 'no',
      entryCost: Money.silver(400),
      depthProfile: DepthProfile(seed: 551337, maxDepthMeters: 18, shape: 'pit'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'trout', weightMin: Weight.grams(500), weightMax: Weight.grams(5000), floatChance: 0.20, spinningChance: 0.46),
        SpeciesSpawn(speciesId: 'salmon', weightMin: Weight.grams(2000), weightMax: Weight.grams(14000), floatChance: 0.10, spinningChance: 0.40),
        SpeciesSpawn(speciesId: 'cod', weightMin: Weight.grams(1500), weightMax: Weight.grams(20000), floatChance: 0.12, spinningChance: 0.36),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'no_cold_lake',
      name: 'Студёное озеро',
      description: 'Кристально чистое горное озеро. Голец и форель в холодной воде.',
      countryId: 'no',
      entryCost: Money.silver(700),
      depthProfile: DepthProfile(seed: 663214, maxDepthMeters: 14, shape: 'dropOff'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'char', weightMin: Weight.grams(400), weightMax: Weight.grams(4000), floatChance: 0.26, spinningChance: 0.40),
        SpeciesSpawn(speciesId: 'trout', weightMin: Weight.grams(400), weightMax: Weight.grams(4500), floatChance: 0.22, spinningChance: 0.42),
        SpeciesSpawn(speciesId: 'perch', weightMin: Weight.grams(100), weightMax: Weight.grams(1400), floatChance: 0.30, spinningChance: 0.40),
      ],
      trash: [],
    ),
    // Германия
    FishingLocation(
      id: 'de_canal',
      name: 'Старый канал',
      description: 'Спокойный городской канал — лещ, плотва и осторожный карп.',
      countryId: 'de',
      entryCost: Money.silver(900),
      depthProfile: DepthProfile(seed: 145236, maxDepthMeters: 5, shape: 'flat'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'bream', weightMin: Weight.grams(400), weightMax: Weight.grams(3000), floatChance: 0.40, spinningChance: 0.06),
        SpeciesSpawn(speciesId: 'roach', weightMin: Weight.grams(50), weightMax: Weight.grams(700), floatChance: 0.42, spinningChance: 0.05),
        SpeciesSpawn(speciesId: 'carp', weightMin: Weight.grams(1500), weightMax: Weight.grams(12000), floatChance: 0.22, spinningChance: 0.05),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'de_forest_lake',
      name: 'Лесное озеро',
      description: 'Уютное озеро в буковом лесу — щука, окунь и трофейный карп.',
      countryId: 'de',
      entryCost: Money.silver(1200),
      depthProfile: DepthProfile(seed: 905142, maxDepthMeters: 8, shape: 'dropOff'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'pike', weightMin: Weight.grams(800), weightMax: Weight.grams(9000), floatChance: 0.10, spinningChance: 0.48),
        SpeciesSpawn(speciesId: 'perch', weightMin: Weight.grams(120), weightMax: Weight.grams(1600), floatChance: 0.30, spinningChance: 0.42),
        SpeciesSpawn(speciesId: 'carp', weightMin: Weight.grams(2000), weightMax: Weight.grams(16000), floatChance: 0.20, spinningChance: 0.04),
      ],
      trash: [],
    ),
    // Япония
    FishingLocation(
      id: 'jp_mountain_stream',
      name: 'Горный ручей',
      description: 'Прозрачный быстрый ручей в горах — деликатная ловля форели и гольца.',
      countryId: 'jp',
      entryCost: Money.silver(600),
      depthProfile: DepthProfile(seed: 920011, maxDepthMeters: 2, shape: 'ridge'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'trout', weightMin: Weight.grams(200), weightMax: Weight.grams(2500), floatChance: 0.30, spinningChance: 0.42),
        SpeciesSpawn(speciesId: 'char', weightMin: Weight.grams(150), weightMax: Weight.grams(1800), floatChance: 0.32, spinningChance: 0.38),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'jp_koi_pond',
      name: 'Храмовый пруд',
      description: 'Тихий пруд у храма — крупный карп, карась и тиляпия.',
      countryId: 'jp',
      entryCost: Money.silver(1100),
      depthProfile: DepthProfile(seed: 471829, maxDepthMeters: 4, shape: 'flat'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'carp', weightMin: Weight.grams(2000), weightMax: Weight.grams(18000), floatChance: 0.26, spinningChance: 0.04),
        SpeciesSpawn(speciesId: 'crucian', weightMin: Weight.grams(100), weightMax: Weight.grams(1800), floatChance: 0.40, spinningChance: 0.04),
        SpeciesSpawn(speciesId: 'tilapia', weightMin: Weight.grams(300), weightMax: Weight.grams(3000), floatChance: 0.34, spinningChance: 0.10),
      ],
      trash: [],
    ),
    // Таиланд
    FishingLocation(
      id: 'th_jungle_river',
      name: 'Река джунглей',
      description: 'Мутная тёплая река — гигантский сом, барамунди и тиляпия.',
      countryId: 'th',
      entryCost: Money.silver(1600),
      depthProfile: DepthProfile(seed: 332277, maxDepthMeters: 11, shape: 'pit'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'catfish', weightMin: Weight.grams(3000), weightMax: Weight.grams(40000), floatChance: 0.10, spinningChance: 0.30),
        SpeciesSpawn(speciesId: 'barramundi', weightMin: Weight.grams(1500), weightMax: Weight.grams(12000), floatChance: 0.10, spinningChance: 0.44),
        SpeciesSpawn(speciesId: 'tilapia', weightMin: Weight.grams(300), weightMax: Weight.grams(3500), floatChance: 0.34, spinningChance: 0.12),
      ],
      trash: [],
    ),
    // Канада
    FishingLocation(
      id: 'ca_pine_lake',
      name: 'Сосновое озеро',
      description: 'Большое озеро в тайге — трофейная щука, судак и форель.',
      countryId: 'ca',
      entryCost: Money.silver(1200),
      depthProfile: DepthProfile(seed: 333190, maxDepthMeters: 22, shape: 'dropOff'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'pike', weightMin: Weight.grams(1500), weightMax: Weight.grams(12000), floatChance: 0.08, spinningChance: 0.52),
        SpeciesSpawn(speciesId: 'zander', weightMin: Weight.grams(1000), weightMax: Weight.grams(7000), floatChance: 0.10, spinningChance: 0.44),
        SpeciesSpawn(speciesId: 'trout', weightMin: Weight.grams(600), weightMax: Weight.grams(6000), floatChance: 0.18, spinningChance: 0.40),
      ],
      trash: [],
    ),
    FishingLocation(
      id: 'ca_rapids',
      name: 'Пороги',
      description: 'Бурные пороги — мощный лосось, форель и жерех на течении.',
      countryId: 'ca',
      entryCost: Money.silver(1800),
      depthProfile: DepthProfile(seed: 818201, maxDepthMeters: 7, shape: 'ridge'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'salmon', weightMin: Weight.grams(2500), weightMax: Weight.grams(16000), floatChance: 0.10, spinningChance: 0.42),
        SpeciesSpawn(speciesId: 'trout', weightMin: Weight.grams(500), weightMax: Weight.grams(5000), floatChance: 0.20, spinningChance: 0.42),
        SpeciesSpawn(speciesId: 'asp', weightMin: Weight.grams(600), weightMax: Weight.grams(4500), floatChance: 0.08, spinningChance: 0.44),
      ],
      trash: [],
    ),
    // США
    FishingLocation(
      id: 'us_big_lake',
      name: 'Великое озеро',
      description: 'Огромная акватория — трофейная щука, судак и сом.',
      countryId: 'us',
      entryCost: Money.silver(2400),
      depthProfile: DepthProfile(seed: 556012, maxDepthMeters: 26, shape: 'pit'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'pike', weightMin: Weight.grams(2000), weightMax: Weight.grams(14000), floatChance: 0.07, spinningChance: 0.52),
        SpeciesSpawn(speciesId: 'zander', weightMin: Weight.grams(1200), weightMax: Weight.grams(8000), floatChance: 0.10, spinningChance: 0.46),
        SpeciesSpawn(speciesId: 'catfish', weightMin: Weight.grams(3000), weightMax: Weight.grams(45000), floatChance: 0.06, spinningChance: 0.24),
      ],
      trash: [],
    ),
    // Бразилия
    FishingLocation(
      id: 'br_amazon_bend',
      name: 'Излучина Амазонки',
      description: 'Тёплая мутная вода — павлиний окунь, сом-гигант и тиляпия.',
      countryId: 'br',
      entryCost: Money.silver(3200),
      depthProfile: DepthProfile(seed: 700451, maxDepthMeters: 12, shape: 'dropOff'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'peacock_bass', weightMin: Weight.grams(1000), weightMax: Weight.grams(9000), floatChance: 0.10, spinningChance: 0.48),
        SpeciesSpawn(speciesId: 'catfish', weightMin: Weight.grams(4000), weightMax: Weight.grams(60000), floatChance: 0.05, spinningChance: 0.22),
        SpeciesSpawn(speciesId: 'tilapia', weightMin: Weight.grams(400), weightMax: Weight.grams(4000), floatChance: 0.34, spinningChance: 0.12),
      ],
      trash: [],
    ),
    // Египет
    FishingLocation(
      id: 'eg_nile_bank',
      name: 'Берег Нила',
      description: 'Древняя река под палящим солнцем — нильский окунь, сом и тиляпия.',
      countryId: 'eg',
      entryCost: Money.silver(4200),
      depthProfile: DepthProfile(seed: 191970, maxDepthMeters: 15, shape: 'pit'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'barramundi', weightMin: Weight.grams(2000), weightMax: Weight.grams(20000), floatChance: 0.08, spinningChance: 0.44),
        SpeciesSpawn(speciesId: 'catfish', weightMin: Weight.grams(3000), weightMax: Weight.grams(50000), floatChance: 0.06, spinningChance: 0.24),
        SpeciesSpawn(speciesId: 'tilapia', weightMin: Weight.grams(400), weightMax: Weight.grams(4500), floatChance: 0.34, spinningChance: 0.12),
      ],
      trash: [],
    ),
    // Австралия
    FishingLocation(
      id: 'au_reef_flat',
      name: 'Рифовая отмель',
      description: 'Прозрачная морская отмель — барамунди, треска и морская форель.',
      countryId: 'au',
      entryCost: Money.silver(5600),
      depthProfile: DepthProfile(seed: 424242, maxDepthMeters: 20, shape: 'dropOff'),
      backdropAssets: [_bg],
      species: [
        SpeciesSpawn(speciesId: 'barramundi', weightMin: Weight.grams(2500), weightMax: Weight.grams(22000), floatChance: 0.08, spinningChance: 0.46),
        SpeciesSpawn(speciesId: 'cod', weightMin: Weight.grams(2000), weightMax: Weight.grams(26000), floatChance: 0.12, spinningChance: 0.34),
        SpeciesSpawn(speciesId: 'salmon', weightMin: Weight.grams(2000), weightMax: Weight.grams(13000), floatChance: 0.10, spinningChance: 0.38),
      ],
      trash: [],
    ),
  ];

  // --- Рыбы ----------------------------------------------------------------

  static List<FishSpecies> species() => [
        _fish('perch', 'Окунь', 'Полосатый хищник, держится стаями у коряг и свалов.',
            'хищник', Rarity.common, 50, 1500, 8, 6,
            lures: {LureType.spinner.code: 0.7, LureType.softBait.code: 0.6, LureType.worm.code: 0.5},
            time: {TimeOfDay.morning: 0.4, TimeOfDay.day: 0.25, TimeOfDay.evening: 0.3, TimeOfDay.night: 0.05}),
        _fish('pike', 'Щука', 'Засадный хищник камыша и бровок. Отчаянно сопротивляется.',
            'хищник', Rarity.uncommon, 700, 15000, 22, 18,
            lures: {LureType.wobbler.code: 0.85, LureType.spoon.code: 0.7, LureType.softBait.code: 0.55},
            size: {LureSize.small: 0.15, LureSize.medium: 0.4, LureSize.large: 0.45}),
        _fish('zander', 'Судак', 'Сумеречный хищник глубоких бровок и ям. Любит джиг.',
            'хищник', Rarity.rare, 800, 8000, 30, 26,
            lures: {LureType.softBait.code: 0.8, LureType.wobbler.code: 0.5},
            color: {LureColor.natural: 0.7, LureColor.bright: 0.3},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.2, DepthZone.dropOff: 0.4, DepthZone.pit: 0.35}),
        _fish('bream', 'Лещ', 'Осторожная донная рыба, кормится на иле.',
            'мирная', Rarity.common, 300, 4000, 14, 12,
            lures: {LureType.worm.code: 0.7, LureType.maggot.code: 0.7, LureType.corn.code: 0.6}),
        _fish('trout', 'Форель', 'Сильная рыба чистой холодной воды.',
            'хищник', Rarity.rare, 200, 6000, 26, 22,
            lures: {LureType.spinner.code: 0.75, LureType.wobbler.code: 0.55},
            weather: {Weather.clear: 0.3, Weather.cloudy: 0.45, Weather.rain: 0.25}),
        _fish('carp', 'Карп', 'Мощный мирный гигант. Долгое вываживание.',
            'мирная', Rarity.trophy, 1500, 20000, 40, 34,
            lures: {LureType.corn.code: 0.8, LureType.worm.code: 0.5}),
        _fish('roach', 'Плотва', 'Бойкая стайная рыбёшка прибрежной зоны.',
            'мирная', Rarity.common, 40, 700, 5, 4,
            lures: {LureType.maggot.code: 0.7, LureType.worm.code: 0.5, LureType.corn.code: 0.4}),
        _fish('crucian', 'Карась', 'Неприхотливый житель тёплых заросших прудов.',
            'мирная', Rarity.common, 80, 1800, 9, 8,
            lures: {LureType.worm.code: 0.7, LureType.corn.code: 0.6, LureType.maggot.code: 0.5}),
        _fish('asp', 'Жерех', 'Стремительный хищник верхнего слоя на течении.',
            'хищник', Rarity.rare, 500, 4500, 28, 24,
            lures: {LureType.spinner.code: 0.7, LureType.spoon.code: 0.6},
            depth: {DepthZone.shallow: 0.4, DepthZone.mid: 0.35, DepthZone.dropOff: 0.2, DepthZone.pit: 0.05}),
        _fish('catfish', 'Сом', 'Донный гигант ям и коряжника. Проверка снасти на прочность.',
            'донная', Rarity.trophy, 2000, 60000, 55, 48,
            lures: {LureType.softBait.code: 0.6, LureType.worm.code: 0.5},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.15, DepthZone.dropOff: 0.35, DepthZone.pit: 0.45}),
        _fish('salmon', 'Лосось', 'Сильная проходная рыба, борется до конца.',
            'хищник', Rarity.trophy, 2000, 16000, 48, 42,
            lures: {LureType.spoon.code: 0.7, LureType.spinner.code: 0.6, LureType.wobbler.code: 0.5}),
        _fish('char', 'Голец', 'Красивая рыба студёных вод, родня форели.',
            'хищник', Rarity.uncommon, 150, 4000, 20, 18,
            lures: {LureType.spinner.code: 0.7, LureType.softBait.code: 0.5}),
        _fish('cod', 'Треска', 'Морской донный хищник холодных вод.',
            'морская', Rarity.rare, 1500, 26000, 34, 30,
            lures: {LureType.softBait.code: 0.7, LureType.spoon.code: 0.5},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.2, DepthZone.dropOff: 0.35, DepthZone.pit: 0.4}),
        _fish('tilapia', 'Тиляпия', 'Тёплолюбивая мирная рыба южных вод.',
            'мирная', Rarity.common, 300, 4500, 12, 10,
            lures: {LureType.corn.code: 0.7, LureType.worm.code: 0.5}),
        _fish('barramundi', 'Барамунди', 'Сильный тропический хищник эстуариев.',
            'хищник', Rarity.rare, 1500, 22000, 38, 34,
            lures: {LureType.wobbler.code: 0.75, LureType.softBait.code: 0.6}),
        _fish('peacock_bass', 'Павлиний окунь', 'Яркий агрессивный хищник Амазонки.',
            'хищник', Rarity.rare, 1000, 9000, 36, 32,
            lures: {LureType.wobbler.code: 0.8, LureType.spinner.code: 0.55},
            color: {LureColor.bright: 0.7, LureColor.natural: 0.3}),
        _fish('grayling', 'Хариус', 'Красавец быстрой холодной воды с парусом-плавником.',
            'хищник', Rarity.uncommon, 150, 2500, 20, 18,
            lures: {LureType.spinner.code: 0.7, LureType.worm.code: 0.5, LureType.maggot.code: 0.45},
            weather: {Weather.clear: 0.35, Weather.cloudy: 0.45, Weather.rain: 0.20},
            depth: {DepthZone.shallow: 0.40, DepthZone.mid: 0.35, DepthZone.dropOff: 0.20, DepthZone.pit: 0.05}),
        _fish('omul', 'Омуль', 'Знаменитый байкальский эндемик, держится глубины.',
            'мирная', Rarity.rare, 200, 3000, 28, 24,
            lures: {LureType.maggot.code: 0.65, LureType.worm.code: 0.5},
            color: {LureColor.natural: 0.75, LureColor.bright: 0.25},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.25, DepthZone.dropOff: 0.40, DepthZone.pit: 0.30}),
        _fish('taimen', 'Таймень', 'Хозяин сибирских рек. Редчайший и сильнейший хищник.',
            'хищник', Rarity.legendary, 3000, 35000, 80, 70,
            lures: {LureType.wobbler.code: 0.7, LureType.spoon.code: 0.65},
            size: {LureSize.small: 0.05, LureSize.medium: 0.30, LureSize.large: 0.65},
            time: {TimeOfDay.morning: 0.35, TimeOfDay.day: 0.10, TimeOfDay.evening: 0.35, TimeOfDay.night: 0.20}),
        // --- Расширение по России: пресноводные хищники ---
        _fish('chub', 'Голавль', 'Сильный речной боец перекатов и нависших кустов.',
            'хищник', Rarity.uncommon, 200, 4000, 16, 14,
            lures: {LureType.wobbler.code: 0.6, LureType.spinner.code: 0.55, LureType.worm.code: 0.45},
            depth: {DepthZone.shallow: 0.4, DepthZone.mid: 0.35, DepthZone.dropOff: 0.2, DepthZone.pit: 0.05}),
        _fish('ide', 'Язь', 'Осторожная всеядная рыба тихих речных плёсов.',
            'мирная', Rarity.uncommon, 200, 3500, 15, 13,
            lures: {LureType.worm.code: 0.6, LureType.corn.code: 0.5, LureType.spinner.code: 0.4}),
        _fish('bersh', 'Берш', 'Младший родич судака с глубоких бровок.',
            'хищник', Rarity.rare, 200, 1500, 22, 18,
            lures: {LureType.softBait.code: 0.7, LureType.wobbler.code: 0.4},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.2, DepthZone.dropOff: 0.4, DepthZone.pit: 0.35}),
        _fish('burbot', 'Налим', 'Холодолюбивый донный хищник; активен ночью и в стужу.',
            'донная', Rarity.rare, 300, 6000, 26, 22,
            lures: {LureType.worm.code: 0.6, LureType.softBait.code: 0.5},
            time: {TimeOfDay.morning: 0.1, TimeOfDay.day: 0.05, TimeOfDay.evening: 0.25, TimeOfDay.night: 0.6},
            weather: {Weather.clear: 0.2, Weather.cloudy: 0.35, Weather.rain: 0.45},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.15, DepthZone.dropOff: 0.35, DepthZone.pit: 0.45}),
        _fish('ruffe', 'Ёрш', 'Колючий неприхотливый малыш у самого дна.',
            'донная', Rarity.common, 20, 200, 4, 3,
            lures: {LureType.worm.code: 0.7, LureType.maggot.code: 0.6}),
        _fish('lenok', 'Ленок', 'Сибирский хищник чистых горных рек, родня форели.',
            'хищник', Rarity.rare, 400, 6000, 30, 26,
            lures: {LureType.spinner.code: 0.65, LureType.wobbler.code: 0.55, LureType.worm.code: 0.4}),
        _fish('verkhoglyad', 'Верхогляд', 'Хищник амурских плёсов с задранным кверху ртом.',
            'хищник', Rarity.rare, 800, 8000, 30, 26,
            lures: {LureType.wobbler.code: 0.6, LureType.spinner.code: 0.5},
            depth: {DepthZone.shallow: 0.4, DepthZone.mid: 0.35, DepthZone.dropOff: 0.2, DepthZone.pit: 0.05}),
        _fish('rotan', 'Ротан', 'Прожорливый головёшка заморных прудов.',
            'хищник', Rarity.common, 40, 700, 5, 4,
            lures: {LureType.worm.code: 0.7, LureType.softBait.code: 0.45}),
        _fish('nelma', 'Нельма', 'Крупный хищный сиг — серебряная торпеда Севера.',
            'хищник', Rarity.trophy, 2000, 20000, 46, 40,
            lures: {LureType.spoon.code: 0.6, LureType.wobbler.code: 0.55}),
        // --- Мирные пресноводные ---
        _fish('wild_carp', 'Сазан', 'Дикий мощный предок карпа. Изматывающее вываживание.',
            'мирная', Rarity.trophy, 1500, 25000, 42, 36,
            lures: {LureType.corn.code: 0.8, LureType.worm.code: 0.5}),
        _fish('white_amur', 'Белый амур', 'Травоядный великан, силён и очень осторожен.',
            'мирная', Rarity.trophy, 2000, 30000, 44, 38,
            lures: {LureType.corn.code: 0.7, LureType.worm.code: 0.4}),
        _fish('silver_carp', 'Толстолобик', 'Фильтратор-гигант; клюёт редко, но мощно.',
            'мирная', Rarity.trophy, 2000, 28000, 42, 36,
            lures: {LureType.corn.code: 0.5}),
        _fish('tench', 'Линь', 'Тёмный житель заросших заливов; кормится по зорям.',
            'мирная', Rarity.uncommon, 200, 3500, 17, 15,
            lures: {LureType.worm.code: 0.7, LureType.corn.code: 0.6},
            time: {TimeOfDay.morning: 0.4, TimeOfDay.day: 0.15, TimeOfDay.evening: 0.4, TimeOfDay.night: 0.05},
            depth: {DepthZone.shallow: 0.55, DepthZone.mid: 0.3, DepthZone.dropOff: 0.1, DepthZone.pit: 0.05}),
        _fish('rudd', 'Красноперка', 'Яркая рыба травянистого мелководья.',
            'мирная', Rarity.common, 50, 1200, 6, 5,
            lures: {LureType.maggot.code: 0.6, LureType.corn.code: 0.5, LureType.worm.code: 0.45},
            depth: {DepthZone.shallow: 0.5, DepthZone.mid: 0.3, DepthZone.dropOff: 0.15, DepthZone.pit: 0.05}),
        _fish('silver_bream', 'Густера', 'Стайная серебристая рыбёшка тихих заводей.',
            'мирная', Rarity.common, 60, 800, 6, 5,
            lures: {LureType.maggot.code: 0.7, LureType.worm.code: 0.5}),
        _fish('blue_bream', 'Синец', 'Глубинный родич леща с синеватым отливом.',
            'мирная', Rarity.common, 100, 900, 8, 6,
            lures: {LureType.maggot.code: 0.6, LureType.worm.code: 0.5},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.25, DepthZone.dropOff: 0.4, DepthZone.pit: 0.3}),
        _fish('sabrefish', 'Чехонь', 'Стремительная «сабля» открытой воды.',
            'мирная', Rarity.uncommon, 100, 1600, 12, 10,
            lures: {LureType.maggot.code: 0.5, LureType.spinner.code: 0.45, LureType.worm.code: 0.4},
            depth: {DepthZone.shallow: 0.2, DepthZone.mid: 0.45, DepthZone.dropOff: 0.3, DepthZone.pit: 0.05}),
        _fish('bleak', 'Уклейка', 'Шустрая верховая мелочь у самой поверхности.',
            'мирная', Rarity.common, 15, 120, 3, 2,
            lures: {LureType.maggot.code: 0.8},
            depth: {DepthZone.shallow: 0.7, DepthZone.mid: 0.25, DepthZone.dropOff: 0.05, DepthZone.pit: 0.0}),
        _fish('gudgeon', 'Пескарь', 'Донный малыш чистых песчаных перекатов.',
            'донная', Rarity.common, 10, 150, 3, 2,
            lures: {LureType.worm.code: 0.7, LureType.maggot.code: 0.6},
            depth: {DepthZone.shallow: 0.6, DepthZone.mid: 0.3, DepthZone.dropOff: 0.1, DepthZone.pit: 0.0}),
        _fish('dace', 'Елец', 'Бойкая речная рыбка быстрых струй.',
            'мирная', Rarity.common, 30, 400, 4, 3,
            lures: {LureType.maggot.code: 0.6, LureType.worm.code: 0.5}),
        // --- Сиговые и лососёвые Севера/Сибири ---
        _fish('whitefish', 'Сиг', 'Серебристая рыба холодных глубин.',
            'мирная', Rarity.rare, 300, 4500, 26, 22,
            lures: {LureType.maggot.code: 0.6, LureType.spinner.code: 0.4},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.25, DepthZone.dropOff: 0.4, DepthZone.pit: 0.3}),
        _fish('muksun', 'Муксун', 'Ценный северный сиг сибирских рек.',
            'мирная', Rarity.rare, 500, 5000, 30, 26,
            lures: {LureType.maggot.code: 0.55, LureType.worm.code: 0.4},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.2, DepthZone.dropOff: 0.4, DepthZone.pit: 0.35}),
        _fish('vendace', 'Ряпушка', 'Мелкий стайный сижок прохладной воды.',
            'мирная', Rarity.common, 30, 350, 6, 5,
            lures: {LureType.maggot.code: 0.7},
            depth: {DepthZone.shallow: 0.1, DepthZone.mid: 0.35, DepthZone.dropOff: 0.4, DepthZone.pit: 0.15}),
        _fish('smelt', 'Корюшка', 'Пахнущая огурцом серебрянка; ход весной.',
            'мирная', Rarity.common, 20, 250, 5, 4,
            lures: {LureType.maggot.code: 0.6, LureType.worm.code: 0.4},
            time: {TimeOfDay.morning: 0.3, TimeOfDay.day: 0.15, TimeOfDay.evening: 0.25, TimeOfDay.night: 0.3}),
        _fish('brown_trout', 'Кумжа', 'Сильная пятнистая форель проходных рек.',
            'хищник', Rarity.rare, 500, 8000, 30, 26,
            lures: {LureType.spinner.code: 0.7, LureType.wobbler.code: 0.5}),
        _fish('mykiss', 'Микижа', 'Камчатская радужная форель — боец на струе.',
            'хищник', Rarity.rare, 500, 9000, 32, 28,
            lures: {LureType.spinner.code: 0.7, LureType.wobbler.code: 0.55}),
        _fish('baikal_char', 'Даватчан', 'Краснокнижный голец байкальских глубин.',
            'хищник', Rarity.trophy, 800, 9000, 40, 36,
            lures: {LureType.spinner.code: 0.6, LureType.spoon.code: 0.5},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.2, DepthZone.dropOff: 0.4, DepthZone.pit: 0.35}),
        // --- Тихоокеанские лососи Камчатки (проходные) ---
        _fish('pink_salmon', 'Горбуша', 'Самый массовый тихоокеанский лосось.',
            'хищник', Rarity.uncommon, 1000, 5000, 26, 22, habitat: Habitat.brackish,
            lures: {LureType.spoon.code: 0.55, LureType.spinner.code: 0.5}),
        _fish('chum', 'Кета', 'Проходной лосось; на ходу берёт яркую блесну.',
            'хищник', Rarity.rare, 1500, 12000, 36, 32, habitat: Habitat.brackish,
            lures: {LureType.spoon.code: 0.6, LureType.spinner.code: 0.5}),
        _fish('coho', 'Кижуч', 'Серебристый сильный лосось осеннего хода.',
            'хищник', Rarity.rare, 2000, 14000, 38, 34, habitat: Habitat.brackish,
            lures: {LureType.spoon.code: 0.65, LureType.wobbler.code: 0.5}),
        _fish('sockeye', 'Нерка', 'Краснотелый лосось чистых озёрных систем.',
            'хищник', Rarity.rare, 1500, 7000, 36, 32, habitat: Habitat.brackish,
            lures: {LureType.spinner.code: 0.55, LureType.spoon.code: 0.5}),
        _fish('chinook', 'Чавыча', 'Король тихоокеанских лососей — мощь и редкость.',
            'хищник', Rarity.legendary, 4000, 40000, 80, 70, habitat: Habitat.brackish,
            lures: {LureType.spoon.code: 0.7, LureType.wobbler.code: 0.6},
            size: {LureSize.small: 0.05, LureSize.medium: 0.3, LureSize.large: 0.65}),
        // --- Осетровые ---
        _fish('sterlet', 'Стерлядь', 'Небольшой осётр с донной кормёжкой.',
            'донная', Rarity.rare, 500, 6000, 34, 30,
            lures: {LureType.worm.code: 0.6},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.2, DepthZone.dropOff: 0.35, DepthZone.pit: 0.4}),
        _fish('sturgeon', 'Осётр', 'Древний донный исполин рек. Редчайший трофей.',
            'донная', Rarity.legendary, 3000, 50000, 90, 80,
            lures: {LureType.worm.code: 0.5},
            depth: {DepthZone.shallow: 0.05, DepthZone.mid: 0.15, DepthZone.dropOff: 0.35, DepthZone.pit: 0.45}),
        _fish('kaluga', 'Калуга', 'Амурский осётр-гигант — легенда глубоких ям.',
            'донная', Rarity.legendary, 5000, 80000, 110, 95,
            lures: {LureType.worm.code: 0.5, LureType.softBait.code: 0.4},
            depth: {DepthZone.shallow: 0.0, DepthZone.mid: 0.1, DepthZone.dropOff: 0.3, DepthZone.pit: 0.6}),
      ];

  // --- Снасти и эхолоты ------------------------------------------------------
  //
  // Каталог собирается линейками: вымышленные серии («Ива», «Сапсан»,
  // «Вьюга»…) по тирам. Эффективность, цена, требуемый уровень и редкость
  // растут вместе — баланс задаётся формулами ниже, без реальных брендов.
  // Первые тиры держат прежние id (rod_a, spin_a…) — сейвы совместимы.

  static final List<GearItem> gear = _buildGear();

  static GearRarity _tierRarity(int tier, int maxTier) {
    final t = tier / maxTier;
    if (t <= 0.3) return GearRarity.common;
    if (t <= 0.55) return GearRarity.uncommon;
    if (t <= 0.75) return GearRarity.rare;
    if (t <= 0.92) return GearRarity.epic;
    return GearRarity.legendary;
  }

  /// Цена тира: первые — бесплатно/дёшево серебром, верхние — за золото.
  static Money _tierPrice(int tier, int maxTier,
      {int silverBase = 420, int goldFrom = 8, int goldBase = 30}) {
    if (tier == 1) return const Money.silver(0);
    if (tier >= goldFrom) {
      final g = (goldBase * math.pow(1.55, tier - goldFrom)).round();
      return Money.gold(g);
    }
    final s = (silverBase * math.pow(1.75, tier - 2)).round();
    return Money.silver((s / 10).round() * 10);
  }

  static int _tierLevel(int tier) =>
      [1, 2, 3, 5, 7, 9, 12, 15, 18, 22][math.min(tier, 10) - 1];

  static List<GearItem> _buildGear() {
    final items = <GearItem>[];

    // --- Удочки: серия «Ива» → «Журавль» (10 тиров) ---
    const rodNames = [
      'Ива-Лайт', 'Ива-Классик', 'Ива-Матч', 'Журавль-Бриз', 'Журавль-Плёс',
      'Журавль-Маховик', 'Журавль-Карбон', 'Цапля-Турнир', 'Цапля-Элит',
      'Цапля-Легенда',
    ];
    const rodKg = <double>[1.5, 2.5, 4, 5.5, 7, 9, 12, 15, 18, 22];
    for (var t = 1; t <= 10; t++) {
      items.add(RodItem(
        id: t == 1 ? 'rod_a' : 'rod_t$t',
        name: 'Удочка «${rodNames[t - 1]}»',
        description:
            'Поплавочное удилище ${t <= 3 ? 'начального' : t <= 6 ? 'среднего' : 'турнирного'} класса, тир $t. Комфортная рыба до ${rodKg[t - 1]} кг.',
        category: GearCategory.rod,
        price: _tierPrice(t, 10),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 10),
        maxWeight: Weight.kilograms(rodKg[t - 1]),
      ));
    }

    // --- Спиннинги: серия «Кедр» → «Сапсан» (10 тиров) ---
    const spinNames = [
      'Кедр-Юниор', 'Кедр-Лес', 'Кедр-Река', 'Сапсан-Свист', 'Сапсан-Клин',
      'Сапсан-Шторм', 'Сапсан-Карбон', 'Беркут-Турнир', 'Беркут-Элит',
      'Беркут-Легенда',
    ];
    const spinKg = <double>[3, 5, 8, 11, 14, 18, 24, 30, 36, 45];
    for (var t = 1; t <= 10; t++) {
      items.add(RodItem(
        id: t == 1 ? 'spin_a' : 'spin_t$t',
        name: 'Спиннинг «${spinNames[t - 1]}»',
        description:
            'Спиннинговый бланк, тир $t: ${t <= 3 ? 'окунь и некрупная щука' : t <= 6 ? 'щука, судак, жерех' : 'сом, лосось, трофеи'}. До ${spinKg[t - 1]} кг.',
        category: GearCategory.spinningRod,
        price: _tierPrice(t, 10, silverBase: 520),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 10),
        maxWeight: Weight.kilograms(spinKg[t - 1]),
      ));
    }

    // --- Катушки поплавочные «Плотва» (8 тиров) ---
    const floatReelKg = <double>[2, 3.5, 5, 7, 9, 12, 15, 18];
    for (var t = 1; t <= 8; t++) {
      items.add(ReelItem(
        id: t == 1 ? 'reel_float_a' : 'reel_float_t$t',
        name: 'Катушка «Плотва-${t}00»',
        description:
            'Поплавочная катушка, тир $t. Плавность фрикциона ${(40 + t * 6)} %.',
        category: GearCategory.floatReel,
        price: _tierPrice(t, 8, silverBase: 360),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 8),
        maxWeight: Weight.kilograms(floatReelKg[t - 1]),
        smoothness: 0.40 + t * 0.06,
      ));
    }

    // --- Катушки спиннинговые «Вьюга» (8 тиров) ---
    const spinReelKg = <double>[4, 6, 9, 13, 18, 25, 34, 45];
    for (var t = 1; t <= 8; t++) {
      items.add(ReelItem(
        id: t == 1 ? 'reel_spin_a' : 'reel_spin_t$t',
        name: 'Катушка «Вьюга-${t * 1000}»',
        description:
            'Безынерционная силовая катушка, тир $t. Плавность ${(42 + t * 6)} %.',
        category: GearCategory.spinningReel,
        price: _tierPrice(t, 8, silverBase: 480),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 8),
        maxWeight: Weight.kilograms(spinReelKg[t - 1]),
        smoothness: 0.42 + t * 0.06,
      ));
    }

    // --- Лески «Кристалл» (8 тиров) ---
    const lineKg = <double>[2.5, 4, 6, 8, 11, 14, 17, 20];
    const lineMm = ['0.14', '0.18', '0.22', '0.26', '0.30', '0.35', '0.40', '0.45'];
    for (var t = 1; t <= 8; t++) {
      items.add(LineItem(
        id: t == 1 ? 'line_a' : 'line_t$t',
        name: 'Леска «Кристалл» ${lineMm[t - 1]} мм',
        description:
            'Монолеска, тир $t: разрыв ${lineKg[t - 1]} кг, ${100 + t * 15} м на шпуле.',
        category: GearCategory.line,
        price: _tierPrice(t, 8, silverBase: 240),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 8),
        lengthMeters: 100 + t * 15,
        maxWeight: Weight.kilograms(lineKg[t - 1]),
      ));
    }

    // --- Шнуры «Стальной шёлк» (8 тиров) ---
    const braidKg = <double>[6, 9, 13, 17, 22, 28, 35, 45];
    for (var t = 1; t <= 8; t++) {
      items.add(LineItem(
        id: t == 1 ? 'braid_a' : 'braid_t$t',
        name: 'Шнур «Стальной шёлк» X$t',
        description:
            'Плетёный шнур, тир $t: разрыв ${braidKg[t - 1]} кг, ${110 + t * 15} м.',
        category: GearCategory.braid,
        price: _tierPrice(t, 8, silverBase: 340),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 8),
        lengthMeters: 110 + t * 15,
        maxWeight: Weight.kilograms(braidKg[t - 1]),
      ));
    }

    // --- Крючки «Зацеп» (8 тиров) ---
    const hookNo = ['12', '10', '8', '6', '4', '2', '1', '1/0'];
    for (var t = 1; t <= 8; t++) {
      items.add(HookItem(
        id: t == 1 ? 'hook_a' : 'hook_t$t',
        name: 'Крючок «Зацеп» №${hookNo[t - 1]}',
        description:
            'Кованый крючок, тир $t. Шанс схода рыбы ${14 - t * 1.5} %.',
        price: _tierPrice(t, 8, silverBase: 160),
        requiredLevel: _tierLevel(t),
        rarity: _tierRarity(t, 8),
        escapeChance: (0.14 - t * 0.015).clamp(0.02, 0.14),
      ));
    }

    // --- Наживки (8 видов, расходники) ---
    items.addAll(const [
      LureItem(id: 'bait_worm', name: 'Червь садовый', description: 'Универсальная живая насадка на белую рыбу и окуня.', category: GearCategory.bait, price: Money.silver(20), requiredLevel: 1, lureType: LureType.worm, size: LureSize.medium, color: LureColor.natural),
      LureItem(id: 'bait_worm_big', name: 'Выползок', description: 'Крупный ночной червь — для леща, сазана и сома.', category: GearCategory.bait, price: Money.silver(45), requiredLevel: 3, rarity: GearRarity.uncommon, lureType: LureType.worm, size: LureSize.large, color: LureColor.natural),
      LureItem(id: 'bait_maggot', name: 'Опарыш', description: 'Деликатная насадка для осторожной рыбы.', category: GearCategory.bait, price: Money.silver(18), requiredLevel: 1, lureType: LureType.maggot, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'bait_maggot_red', name: 'Опарыш рубиновый', description: 'Подкрашенный опарыш — заметнее в мутной воде.', category: GearCategory.bait, price: Money.silver(30), requiredLevel: 2, rarity: GearRarity.uncommon, lureType: LureType.maggot, size: LureSize.small, color: LureColor.bright),
      LureItem(id: 'bait_corn', name: 'Кукуруза', description: 'Сладкая насадка для мирной рыбы.', category: GearCategory.bait, price: Money.silver(15), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.bright),
      LureItem(id: 'bait_corn_ferm', name: 'Кукуруза ферментированная', description: 'Пряная кукуруза — карп её обожает.', category: GearCategory.bait, price: Money.silver(40), requiredLevel: 4, rarity: GearRarity.uncommon, lureType: LureType.corn, size: LureSize.medium, color: LureColor.bright),
      LureItem(id: 'bait_dough', name: 'Тесто чесночное', description: 'Ароматное тесто для карася и леща.', category: GearCategory.bait, price: Money.silver(25), requiredLevel: 2, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'bait_caddis', name: 'Ручейник', description: 'Лакомство хариуса и форели из горных ручьёв.', category: GearCategory.bait, price: Money.silver(55), requiredLevel: 5, rarity: GearRarity.rare, lureType: LureType.maggot, size: LureSize.small, color: LureColor.natural),
    ]);

    // --- Приманки (14 видов) ---
    items.addAll(const [
      LureItem(id: 'lure_wobbler', name: 'Воблер «Плотвичка-S»', description: 'Мелкий плавающий воблер: окунь, голавль.', category: GearCategory.lure, price: Money.silver(120), requiredLevel: 2, lureType: LureType.wobbler, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'lure_wob_m', name: 'Воблер «Плотвичка-M»', description: 'Средний воблер с активной игрой: щука, судак.', category: GearCategory.lure, price: Money.silver(260), requiredLevel: 4, rarity: GearRarity.uncommon, lureType: LureType.wobbler, size: LureSize.medium, color: LureColor.bright),
      LureItem(id: 'lure_wob_l', name: 'Воблер «Плотвичка-L»', description: 'Крупный глубоководный воблер: трофейная щука, таймень.', category: GearCategory.lure, price: Money.silver(620), requiredLevel: 8, rarity: GearRarity.rare, lureType: LureType.wobbler, size: LureSize.large, color: LureColor.bright),
      LureItem(id: 'lure_spinner', name: 'Вертушка «Искра» №1', description: 'Маленькая вращалка: окунь, хариус, форель.', category: GearCategory.lure, price: Money.silver(90), requiredLevel: 2, lureType: LureType.spinner, size: LureSize.small, color: LureColor.bright),
      LureItem(id: 'lure_spin2', name: 'Вертушка «Искра» №3', description: 'Средняя вращалка с лепестком «лонг»: щука, жерех.', category: GearCategory.lure, price: Money.silver(210), requiredLevel: 4, rarity: GearRarity.uncommon, lureType: LureType.spinner, size: LureSize.medium, color: LureColor.bright),
      LureItem(id: 'lure_spin3', name: 'Вертушка «Искра» №5', description: 'Тяжёлая вращалка: лосось и крупный хищник на течении.', category: GearCategory.lure, price: Money.silver(520), requiredLevel: 7, rarity: GearRarity.rare, lureType: LureType.spinner, size: LureSize.large, color: LureColor.natural),
      LureItem(id: 'lure_spoon', name: 'Колебалка «Волна-40»', description: 'Лёгкая колеблющаяся блесна для мелководья.', category: GearCategory.lure, price: Money.silver(110), requiredLevel: 3, lureType: LureType.spoon, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'lure_spoon2', name: 'Колебалка «Волна-70»', description: 'Классика по щуке: уверенная игра на снос.', category: GearCategory.lure, price: Money.silver(280), requiredLevel: 5, rarity: GearRarity.uncommon, lureType: LureType.spoon, size: LureSize.medium, color: LureColor.bright),
      LureItem(id: 'lure_spoon3', name: 'Колебалка «Волна-100»', description: 'Тяжёлая дальнобойная блесна: лосось, треска.', category: GearCategory.lure, price: Money.silver(640), requiredLevel: 9, rarity: GearRarity.rare, lureType: LureType.spoon, size: LureSize.large, color: LureColor.natural),
      LureItem(id: 'lure_soft', name: 'Виброхвост «Хвостик-5»', description: 'Силикон на джиг-головке: судак, окунь у дна.', category: GearCategory.lure, price: Money.silver(60), requiredLevel: 2, lureType: LureType.softBait, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'lure_soft2', name: 'Виброхвост «Хвостик-9»', description: 'Средний силикон с активной пяткой: судак, щука.', category: GearCategory.lure, price: Money.silver(150), requiredLevel: 4, rarity: GearRarity.uncommon, lureType: LureType.softBait, size: LureSize.medium, color: LureColor.bright),
      LureItem(id: 'lure_soft3', name: 'Виброхвост «Хвостик-13»', description: 'Крупный силикон для трофейного судака и сома.', category: GearCategory.lure, price: Money.silver(380), requiredLevel: 7, rarity: GearRarity.rare, lureType: LureType.softBait, size: LureSize.large, color: LureColor.natural),
      LureItem(id: 'lure_frog', name: 'Лягушонок-незацепляйка', description: 'Поверхностная приманка по кувшинкам: щука в траве.', category: GearCategory.lure, price: Money.silver(540), requiredLevel: 6, rarity: GearRarity.rare, lureType: LureType.wobbler, size: LureSize.medium, color: LureColor.bright),
      LureItem(id: 'lure_jig_pro', name: 'Джиг «Ёрш-Турнир»', description: 'Турнирный силикон с аттрактантом — выбор чемпионов.', category: GearCategory.lure, price: Money.gold(45), requiredLevel: 12, rarity: GearRarity.epic, lureType: LureType.softBait, size: LureSize.large, color: LureColor.bright),
    ]);

    // --- Эхолоты (8 моделей, разные функции и «плюшки») ---
    items.addAll([
      EchoSounderItem(id: 'echo_mini', name: 'Эхолот «Глубина-Мини»', description: 'Карманный однолучевой: только глубина в точке заброса.', price: Money.silver(450), requiredLevel: 2, capabilities: const {SounderCapability.depthReadout}, rangeMeters: 5),
      EchoSounderItem(id: 'echo_shore', name: 'Эхолот «Берег»', description: 'Точная глубина и температура воды у поплавка.', price: Money.silver(900), requiredLevel: 3, rarity: GearRarity.uncommon, capabilities: const {SounderCapability.depthReadout, SounderCapability.temperature}, rangeMeters: 8),
      EchoSounderItem(id: 'echo_flasher', name: 'Флешер «Зима»', description: 'Круговой флешер: глубина, температура, дуги рыбы и сигнал глубины.', price: Money.silver(2600), requiredLevel: 4, rarity: GearRarity.uncommon, capabilities: const {SounderCapability.depthReadout, SounderCapability.temperature, SounderCapability.fishArches, SounderCapability.depthAlarm}, rangeMeters: 12),
      EchoSounderItem(id: 'echo_scan', name: 'Сканер дна «Рельеф»', description: 'Профиль дна, температура и зум придонного слоя.', price: Money.silver(3200), requiredLevel: 5, rarity: GearRarity.rare, capabilities: const {SounderCapability.depthReadout, SounderCapability.bottomProfile, SounderCapability.temperature, SounderCapability.zoom}, rangeMeters: 16),
      EchoSounderItem(id: 'echo_cast', name: 'Беспроводной «Поплавок-2»', description: 'Забрасываемый датчик: дно, стаи рыбы и метки точек.', price: Money.gold(90), requiredLevel: 7, rarity: GearRarity.rare, capabilities: const {SounderCapability.depthReadout, SounderCapability.bottomProfile, SounderCapability.fishArches, SounderCapability.gpsMarks}, rangeMeters: 20),
      EchoSounderItem(id: 'echo_sonar2d', name: '2D-эхолот «Косяк»', description: 'Стаи рыбы, структура дна, индикатор жора, зум и сигнал.', price: Money.gold(160), requiredLevel: 9, rarity: GearRarity.epic, capabilities: const {SounderCapability.depthReadout, SounderCapability.bottomProfile, SounderCapability.fishArches, SounderCapability.structureScan, SounderCapability.biteIndicator, SounderCapability.zoom, SounderCapability.temperature, SounderCapability.depthAlarm}, rangeMeters: 24),
      EchoSounderItem(id: 'echo_pro', name: 'Сонар «Капитан»', description: 'Распознавание размера и веса, сигнал по весу рыбы, лучшая глубина, термоклин и метки мест.', price: Money.gold(340), requiredLevel: 14, rarity: GearRarity.epic, capabilities: const {SounderCapability.depthReadout, SounderCapability.bottomProfile, SounderCapability.fishArches, SounderCapability.fishIdHint, SounderCapability.weightTag, SounderCapability.weightAlarm, SounderCapability.biteIndicator, SounderCapability.bestDepthHint, SounderCapability.structureScan, SounderCapability.temperature, SounderCapability.thermocline, SounderCapability.gpsMarks, SounderCapability.zoom}, rangeMeters: 32),
      EchoSounderItem(id: 'echo_orlan', name: 'Флагман «Орлан-X»', description: 'Живой сонар в реальном времени и весь арсенал функций. Луч 45 м.', price: Money.gold(950), requiredLevel: 20, rarity: GearRarity.legendary, capabilities: SounderCapability.values.toSet(), rangeMeters: 45),
    ]);

    // --- Прикормка (по семействам), спреи, перекус ---
    // Прикормка на воде приваживает СВОЁ семейство и повышает шанс вылова его
    // видов на время (универсальная просто оживляет точку). Перекус —
    // восстанавливает энергию (дороже = сытнее). Спреи — флейвор-инвентарь.
    items.addAll(const [
      // Прикормка по биологическим семействам. Узкая (одно семейство) — за
      // серебро; широкая (несколько) и универсальная (все) — за кристаллы.
      LureItem(id: 'ground_carp', name: 'Прикормка «Карповая каша»', description: 'Сладкая кукурузно-злаковая смесь — классика для карповых (лещ, плотва, карась, сазан).', category: GearCategory.groundbait, price: Money.silver(45), requiredLevel: 2, lureType: LureType.corn, size: LureSize.medium, color: LureColor.natural, targetGroups: ['Карповые'], chumSeconds: 55),
      LureItem(id: 'ground_perch', name: 'Прикормка «Окунёвый замес»', description: 'Мотыль и рубленый червь с аттрактантом — для окунёвых.', category: GearCategory.groundbait, price: Money.silver(70), requiredLevel: 3, rarity: GearRarity.uncommon, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural, targetGroups: ['Окунёвые'], chumSeconds: 55),
      LureItem(id: 'ground_pike', name: 'Прикормка «Щучий сектор»', description: 'Кровяной аттрактант и рыбная резка — будит щуковых.', category: GearCategory.groundbait, price: Money.silver(95), requiredLevel: 4, rarity: GearRarity.uncommon, lureType: LureType.corn, size: LureSize.large, color: LureColor.natural, targetGroups: ['Щуковые'], chumSeconds: 50),
      LureItem(id: 'ground_catfish', name: 'Прикормка «Сомовий аромат»', description: 'Пахучая печёночно-пеллетсовая смесь — для сомовых.', category: GearCategory.groundbait, price: Money.silver(150), requiredLevel: 6, rarity: GearRarity.rare, lureType: LureType.corn, size: LureSize.large, color: LureColor.natural, targetGroups: ['Сомовые'], chumSeconds: 70),
      LureItem(id: 'ground_whitefish', name: 'Прикормка «Бормаш-Север»', description: 'Рачок-бокоплав холодной воды — для сиговых и хариусовых.', category: GearCategory.groundbait, price: Money.silver(160), requiredLevel: 7, rarity: GearRarity.rare, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural, targetGroups: ['Сиговые', 'Хариусовые'], chumSeconds: 70),
      LureItem(id: 'ground_salmon', name: 'Прикормка «Икорный след»', description: 'Имитация икры и криль — приваживает лососёвых.', category: GearCategory.groundbait, price: Money.gold(35), requiredLevel: 9, rarity: GearRarity.epic, lureType: LureType.corn, size: LureSize.medium, color: LureColor.natural, targetGroups: ['Лососёвые'], chumSeconds: 75),
      LureItem(id: 'ground_sturgeon', name: 'Прикормка «Осетровый стол»', description: 'Тяжёлая донная смесь с моллюском — для осетровых.', category: GearCategory.groundbait, price: Money.gold(55), requiredLevel: 12, rarity: GearRarity.epic, lureType: LureType.corn, size: LureSize.large, color: LureColor.natural, targetGroups: ['Осетровые'], chumSeconds: 80),
      LureItem(id: 'ground_predator', name: 'Прикормка «Хищный комплекс»', description: 'Сразу для нескольких хищных семейств: окунёвые, щуковые, сомовые.', category: GearCategory.groundbait, price: Money.gold(50), requiredLevel: 8, rarity: GearRarity.epic, lureType: LureType.corn, size: LureSize.large, color: LureColor.natural, targetGroups: ['Окунёвые', 'Щуковые', 'Сомовые'], chumSeconds: 75),
      LureItem(id: 'ground_uni', name: 'Прикормка «Универсал-Магнит»', description: 'Сложный аттрактант на ВСЕ семейства водоёма разом — потому и дорогой.', category: GearCategory.groundbait, price: Money.gold(90), requiredLevel: 12, rarity: GearRarity.legendary, lureType: LureType.corn, size: LureSize.large, color: LureColor.natural, chumSeconds: 110),
      // Спреи и защита (флейвор-инвентарь).
      LureItem(id: 'spray_mosq', name: 'Спрей «Антикомар»', description: 'Без него на вечерней зорьке делать нечего.', category: GearCategory.spray, price: Money.silver(50), requiredLevel: 1, lureType: LureType.worm, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'spray_tick', name: 'Спрей «Стоп-Клещ»', description: 'Обязателен для диких таёжных берегов.', category: GearCategory.spray, price: Money.silver(80), requiredLevel: 5, rarity: GearRarity.uncommon, lureType: LureType.worm, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'spray_midge', name: 'Сетка-накомарник', description: 'Защита от мошки в сезон гнуса.', category: GearCategory.spray, price: Money.silver(65), requiredLevel: 3, lureType: LureType.worm, size: LureSize.small, color: LureColor.natural),
      // Перекус — восстановление энергии (дороже = сытнее).
      LureItem(id: 'food_choco', name: 'Шоколад «Привал»', description: 'Быстрый сахар — взбодриться между забросами.', category: GearCategory.energy, price: Money.silver(25), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_driedfish', name: 'Вобла к чаю', description: 'Солёная вобла — рыбацкая классика.', category: GearCategory.energy, price: Money.silver(28), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_nuts', name: 'Орехи и сухофрукты', description: 'Лёгкий перекус, чтобы не терять концентрацию.', category: GearCategory.energy, price: Money.silver(32), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_tea', name: 'Термос с чаем', description: 'Горячий чай — спасение на утреннике.', category: GearCategory.energy, price: Money.silver(30), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_bar', name: 'Энергобатончик «Клёв»', description: 'Орехи и мёд в обёртке — заряд на пару часов.', category: GearCategory.energy, price: Money.silver(35), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_honey', name: 'Чай с мёдом', description: 'Сладко и тепло — силы прибавляются.', category: GearCategory.energy, price: Money.silver(38), requiredLevel: 2, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_coffee', name: 'Кофе «Костровой»', description: 'Крепкий кофе для ночной ловли сома.', category: GearCategory.energy, price: Money.silver(40), requiredLevel: 2, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_lunch', name: 'Бутерброды рыбака', description: 'Перекус, ради которого половина и едет на рыбалку.', category: GearCategory.energy, price: Money.silver(45), requiredLevel: 1, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_drink', name: 'Энергетик «Заброс»', description: 'Банка бодрости — когда клюёт всю ночь.', category: GearCategory.energy, price: Money.silver(50), requiredLevel: 3, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_sandwich', name: 'Сэндвич с икрой', description: 'Сытный сэндвич — надолго восстанавливает силы.', category: GearCategory.energy, price: Money.silver(55), requiredLevel: 2, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_kasha', name: 'Гречка с тушёнкой', description: 'Котелок горячей каши — рыбацкий обед.', category: GearCategory.energy, price: Money.silver(60), requiredLevel: 2, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_soup', name: 'Уха в термосе', description: 'Наваристая уха — лучшее, что есть на берегу.', category: GearCategory.energy, price: Money.silver(70), requiredLevel: 3, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_pelmeni', name: 'Пельмени у костра', description: 'Горячие пельмени — плотный ужин рыбака.', category: GearCategory.energy, price: Money.silver(80), requiredLevel: 3, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
      LureItem(id: 'food_shashlyk', name: 'Шашлык на углях', description: 'Шашлык с дымком — полный заряд сил.', category: GearCategory.energy, price: Money.silver(90), requiredLevel: 4, lureType: LureType.corn, size: LureSize.small, color: LureColor.natural),
    ]);

    // --- Премиум-подписки: день / неделя / месяц ---
    items.addAll(const [
      PremiumItem(id: 'prem_day', name: 'Премиум «Зорька» (1 день)', description: 'На сутки: ×2 серебра и опыта за каждый улов.', price: Money.gold(15), requiredLevel: 1, rarity: GearRarity.rare, days: 1, tier: 1),
      PremiumItem(id: 'prem_week', name: 'Премиум «Путина» (7 дней)', description: 'Неделя: ×2 награды + рыба клюёт на 15 % активнее.', price: Money.gold(60), requiredLevel: 3, rarity: GearRarity.epic, days: 7, tier: 2),
      PremiumItem(id: 'prem_month', name: 'Премиум «Сезон» (30 дней)', description: 'Месяц: ×2 награды, +15 % клёва и наживка тратится вдвое реже.', price: Money.gold(180), requiredLevel: 5, rarity: GearRarity.legendary, days: 30, tier: 3),
    ]);

    return items;
  }

  /// Помощник построения вида рыбы с профилем поклёвки от равномерного дефолта.
  static FishSpecies _fish(
    String id,
    String name,
    String description,
    String family,
    Rarity rarity,
    int gramsMin,
    int gramsMax,
    int baseSilver,
    int baseXp, {
    Map<String, double>? lures,
    Map<LureSize, double>? size,
    Map<LureColor, double>? color,
    Map<TimeOfDay, double>? time,
    Map<Weather, double>? weather,
    Map<DepthZone, double>? depth,
    Habitat habitat = Habitat.fresh,
  }) {
    final base = BiteProfile.uniform();
    // Любая рыба может клюнуть на любую наживку (пол 0.15), но рекомендованная
    // наживка работает заметно эффективнее (её вес выше).
    final lureWeights = {for (final l in LureType.all) l.code: 0.15};
    if (lures != null) lureWeights.addAll(lures);
    return FishSpecies(
      id: id,
      name: name,
      description: description,
      family: family,
      group: kFishGroups[id] ?? '',
      habitat: habitat,
      rarity: rarity,
      weightMin: Weight.grams(gramsMin),
      weightMax: Weight.grams(gramsMax),
      baseSilver: baseSilver,
      baseXp: baseXp,
      biteProfile: BiteProfile(
        sizeWeights: size ?? base.sizeWeights,
        colorWeights: color ?? base.colorWeights,
        timeWeights: time ?? base.timeWeights,
        weatherWeights: weather ?? base.weatherWeights,
        depthWeights: depth ?? base.depthWeights,
        lureTypeWeights: lureWeights,
      ),
    );
  }

  /// Биологическое семейство вида — для прикормки («Подходит для: …»).
  static const Map<String, String> kFishGroups = {
    'perch': 'Окунёвые', 'pike': 'Щуковые', 'zander': 'Окунёвые',
    'bream': 'Карповые', 'trout': 'Лососёвые', 'carp': 'Карповые',
    'roach': 'Карповые', 'crucian': 'Карповые', 'asp': 'Карповые',
    'catfish': 'Сомовые', 'salmon': 'Лососёвые', 'char': 'Лососёвые',
    'cod': 'Тресковые', 'tilapia': 'Цихловые', 'barramundi': 'Латесовые',
    'peacock_bass': 'Цихловые', 'grayling': 'Хариусовые', 'omul': 'Сиговые',
    'taimen': 'Лососёвые', 'chub': 'Карповые', 'ide': 'Карповые',
    'bersh': 'Окунёвые', 'burbot': 'Тресковые', 'ruffe': 'Окунёвые',
    'lenok': 'Лососёвые', 'verkhoglyad': 'Карповые', 'rotan': 'Головешковые',
    'nelma': 'Сиговые', 'wild_carp': 'Карповые', 'white_amur': 'Карповые',
    'silver_carp': 'Карповые', 'tench': 'Карповые', 'rudd': 'Карповые',
    'silver_bream': 'Карповые', 'blue_bream': 'Карповые',
    'sabrefish': 'Карповые', 'bleak': 'Карповые', 'gudgeon': 'Карповые',
    'dace': 'Карповые', 'whitefish': 'Сиговые', 'muksun': 'Сиговые',
    'vendace': 'Сиговые', 'smelt': 'Корюшковые', 'brown_trout': 'Лососёвые',
    'mykiss': 'Лососёвые', 'baikal_char': 'Лососёвые',
    'pink_salmon': 'Лососёвые', 'chum': 'Лососёвые', 'coho': 'Лососёвые',
    'sockeye': 'Лососёвые', 'chinook': 'Лососёвые', 'sterlet': 'Осетровые',
    'sturgeon': 'Осетровые', 'kaluga': 'Осетровые',
  };

  /// Краткая запись зарыбления локации.
  static SpeciesSpawn _spawn(String id, int min, int max,
          {double f = 0.3, double s = 0.3}) =>
      SpeciesSpawn(
        speciesId: id,
        weightMin: Weight.grams(min),
        weightMax: Weight.grams(max),
        floatChance: f,
        spinningChance: s,
      );
}
