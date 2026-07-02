import 'dart:math';

/// Турнир (этапное соревнование). Локальные сид-данные: оппоненты — боты,
/// зачёт по суммарному весу пойманной рыбы за отведённое время.
class Tournament {
  const Tournament({
    required this.id,
    required this.stageCount,
    required this.title,
    required this.dateRange,
    required this.locationName,
    required this.locationId,
    required this.requiredLevel,
    required this.entrySilver,
    required this.entryGold,
    required this.durationSec,
    required this.parGrams,
    required this.reward1,
    required this.reward2,
    required this.reward3,
    required this.goldReward,
    required this.backdrop,
    required this.info,
    this.regionId = '',
    this.lon = 0,
    this.lat = 0,
  });

  final String id;
  final int stageCount; // число этапов (косметика)
  final String title;
  final String dateRange;
  final String locationName;

  /// Реальный водоём, где проходит зачётная сессия (id из сид-контента).
  final String locationId;
  final int requiredLevel;

  /// Взнос за участие (серебро ИЛИ золото — что есть у игрока).
  final int entrySilver;
  final int entryGold;

  /// Длительность зачётной сессии в секундах.
  final int durationSec;

  /// «Пар» — ориентир силы соперников (центр распределения очков ботов, граммы).
  final int parGrams;

  /// Призовые серебром за 1/2/3 место и золото победителю.
  final int reward1;
  final int reward2;
  final int reward3;
  final int goldReward;

  final String backdrop;
  final String info;

  /// Регион проведения (id = англ. название субъекта РФ). Пусто у сид-турниров
  /// (тогда точка на карте берётся из геопозиции водоёма `locationId`).
  final String regionId;

  /// Своя точка турнира на карте (в пределах региона). 0,0 — не задана
  /// (используется геопозиция водоёма).
  final double lon;
  final double lat;

  bool get hasOwnPoint => lon != 0 || lat != 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stageCount': stageCount,
        'title': title,
        'dateRange': dateRange,
        'locationName': locationName,
        'locationId': locationId,
        'requiredLevel': requiredLevel,
        'entrySilver': entrySilver,
        'entryGold': entryGold,
        'durationSec': durationSec,
        'parGrams': parGrams,
        'reward1': reward1,
        'reward2': reward2,
        'reward3': reward3,
        'goldReward': goldReward,
        'backdrop': backdrop,
        'info': info,
        'regionId': regionId,
        'lon': lon,
        'lat': lat,
      };

  static int _i(Object? v, int d) => v is num ? v.toInt() : d;
  static double _d(Object? v, double d) => v is num ? v.toDouble() : d;

  factory Tournament.fromJson(Map<String, dynamic> j) => Tournament(
        id: (j['id'] ?? '') as String,
        stageCount: _i(j['stageCount'], 1),
        title: (j['title'] ?? '') as String,
        dateRange: (j['dateRange'] ?? '') as String,
        locationName: (j['locationName'] ?? '') as String,
        locationId: (j['locationId'] ?? '') as String,
        requiredLevel: _i(j['requiredLevel'], 1),
        entrySilver: _i(j['entrySilver'], 0),
        entryGold: _i(j['entryGold'], 0),
        durationSec: _i(j['durationSec'], 120),
        parGrams: _i(j['parGrams'], 1000),
        reward1: _i(j['reward1'], 0),
        reward2: _i(j['reward2'], 0),
        reward3: _i(j['reward3'], 0),
        goldReward: _i(j['goldReward'], 0),
        backdrop: (j['backdrop'] ?? '') as String,
        info: (j['info'] ?? '') as String,
        regionId: (j['regionId'] ?? '') as String,
        lon: _d(j['lon'], 0),
        lat: _d(j['lat'], 0),
      );

  Tournament copyWith({
    String? id,
    int? stageCount,
    String? title,
    String? dateRange,
    String? locationName,
    String? locationId,
    int? requiredLevel,
    int? entrySilver,
    int? entryGold,
    int? durationSec,
    int? parGrams,
    int? reward1,
    int? reward2,
    int? reward3,
    int? goldReward,
    String? backdrop,
    String? info,
    String? regionId,
    double? lon,
    double? lat,
  }) =>
      Tournament(
        id: id ?? this.id,
        stageCount: stageCount ?? this.stageCount,
        title: title ?? this.title,
        dateRange: dateRange ?? this.dateRange,
        locationName: locationName ?? this.locationName,
        locationId: locationId ?? this.locationId,
        requiredLevel: requiredLevel ?? this.requiredLevel,
        entrySilver: entrySilver ?? this.entrySilver,
        entryGold: entryGold ?? this.entryGold,
        durationSec: durationSec ?? this.durationSec,
        parGrams: parGrams ?? this.parGrams,
        reward1: reward1 ?? this.reward1,
        reward2: reward2 ?? this.reward2,
        reward3: reward3 ?? this.reward3,
        goldReward: goldReward ?? this.goldReward,
        backdrop: backdrop ?? this.backdrop,
        info: info ?? this.info,
        regionId: regionId ?? this.regionId,
        lon: lon ?? this.lon,
        lat: lat ?? this.lat,
      );
}

/// Оверрайд списка турниров из админки (полный список заменяет сид).
/// Пусто — используются [kSeedTournaments].
List<Tournament>? _tournamentsOverride;
void setTournamentsOverride(List<Tournament>? list) =>
    _tournamentsOverride = list;

/// Актуальные турниры: правки админки приоритетнее сида.
List<Tournament> activeTournaments() => _tournamentsOverride ?? kSeedTournaments;

/// Запись в таблице рейтинга турнира (вес зачёта в граммах).
class LeaderboardRow {
  const LeaderboardRow(this.place, this.player, this.rating, {this.isMe = false});
  final int place;
  final String player;
  final int rating; // граммы
  final bool isMe;
}

/// Итог турнира для игрока: место, призовые и финальная таблица.
class TournamentResult {
  const TournamentResult({
    required this.place,
    required this.total,
    required this.playerScore,
    required this.prizeSilver,
    required this.prizeGold,
    required this.rows,
  });

  final int place;
  final int total;
  final int playerScore;
  final int prizeSilver;
  final int prizeGold;
  final List<LeaderboardRow> rows;

  bool get won => place == 1;
  bool get podium => place <= 3;
}

/// Сид-турниры (контент-заглушка, легко заменить на доменный репозиторий).
const kSeedTournaments = <Tournament>[
  Tournament(
    id: 'summer_champ',
    stageCount: 1,
    title: 'Летний чемпионат',
    dateRange: 'Открытый зачёт · 1 этап',
    locationName: 'Ладожское озеро',
    locationId: 'ru_ladoga',
    requiredLevel: 2,
    entrySilver: 300,
    entryGold: 30,
    durationSec: 150,
    parGrams: 2200,
    reward1: 2000,
    reward2: 1000,
    reward3: 500,
    goldReward: 15,
    backdrop: 'assets/locations/ru_ladoga.png',
    info: 'Открытый летний чемпионат по ловле. За отведённое время лови как '
        'можно больше — в зачёт идёт суммарный вес всей пойманной рыбы. '
        'Соперники — местные рыбаки.',
  ),
  Tournament(
    id: 'grand_prix',
    stageCount: 3,
    title: 'Гран-при рыболова',
    dateRange: 'Серия · 3 этапа',
    locationName: 'Озеро Селигер',
    locationId: 'ru_seliger',
    requiredLevel: 6,
    entrySilver: 1200,
    entryGold: 100,
    durationSec: 180,
    parGrams: 4200,
    reward1: 5000,
    reward2: 2500,
    reward3: 1200,
    goldReward: 40,
    backdrop: 'assets/locations/ru_seliger.png',
    info: 'Престижная серия для опытных рыбаков. Сильные соперники и крупные '
        'призы — нужна хорошая снасть и плотный зачёт за время сессии.',
  ),
];

Tournament? tournamentById(String id) {
  for (final t in activeTournaments()) {
    if (t.id == id) return t;
  }
  return null;
}

/// Пул имён ботов (вымышленные, без реальных брендов и людей).
const _kBotNames = <String>[
  'Большая_Рыба213',
  'Волга1974',
  'Карп_Карпыч',
  'ЩукоЛов',
  'Тихий Омут',
  'Колебалка_77',
  'Спиннингист_Лёха',
  'Поплавок_Сан Саныч',
  'НочнойЖор',
  'Лещ_на_бок',
  'Зорька',
  'Камышовый Кот',
  'Воблер_Викинг',
  'Дед_Мормыш',
  'Утренний Клёв',
  'Сом_Усатый',
  'БлеснаЛеди',
  'Берег_Левый',
  'Окунь_Полосатый',
  'Фидер_Федя',
];

/// Считает итог турнира: генерирует очки ботов вокруг «пара», определяет место
/// игрока и призовые. [seed] делает результат воспроизводимым в рамках сессии.
TournamentResult computeTournamentResult(
  Tournament t,
  int playerScore,
  int seed,
) {
  final rng = Random(seed);
  const botCount = 12;

  final names = [..._kBotNames]..shuffle(rng);
  final rows = <LeaderboardRow>[];
  for (var i = 0; i < botCount; i++) {
    // 0.45..1.65 от «пара» — широкий разброс силы соперников.
    final factor = 0.45 + rng.nextDouble() * 1.2;
    final score = (t.parGrams * factor).round();
    rows.add(LeaderboardRow(0, names[i % names.length], score));
  }
  rows.add(LeaderboardRow(0, 'Вы', playerScore, isMe: true));

  rows.sort((a, b) => b.rating.compareTo(a.rating));
  final ranked = <LeaderboardRow>[];
  var place = 0;
  for (final r in rows) {
    place++;
    ranked.add(LeaderboardRow(place, r.player, r.rating, isMe: r.isMe));
  }
  final me = ranked.firstWhere((r) => r.isMe);

  return TournamentResult(
    place: me.place,
    total: ranked.length,
    playerScore: playerScore,
    prizeSilver: _silverFor(t, me.place),
    prizeGold: _goldFor(t, me.place),
    rows: ranked,
  );
}

/// Предпросмотр состава соперников (без игрока) — для вкладки «Рейтинг».
List<LeaderboardRow> previewLeaderboard(Tournament t, int seed) {
  final bots = computeTournamentResult(t, -1, seed).rows
      .where((e) => !e.isMe)
      .toList();
  return [
    for (var i = 0; i < bots.length; i++)
      LeaderboardRow(i + 1, bots[i].player, bots[i].rating),
  ];
}

int _silverFor(Tournament t, int place) {
  switch (place) {
    case 1:
      return t.reward1;
    case 2:
      return t.reward2;
    case 3:
      return t.reward3;
    default:
      // 4..10 — небольшое утешительное; дальше — ничего.
      if (place <= 10) return ((t.reward3 * (11 - place)) / 20).round();
      return 0;
  }
}

int _goldFor(Tournament t, int place) => switch (place) {
      1 => t.goldReward,
      2 => (t.goldReward * 0.5).round(),
      3 => (t.goldReward * 0.25).round(),
      _ => 0,
    };
