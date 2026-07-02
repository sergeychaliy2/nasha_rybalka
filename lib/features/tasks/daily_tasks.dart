import 'dart:math';

/// Ежедневное поручение: считается по метрике дневного прогресса игрока.
class DailyTask {
  const DailyTask({
    required this.id,
    required this.text,
    required this.metric,
    required this.target,
    required this.silver,
    this.gold = 0,
  });

  final String id;
  final String text;

  /// Ключ метрики в `Player.dailyProgress` (catch/release/keep/weight/big/
  /// trophy/spend).
  final String metric;
  final int target;
  final int silver;
  final int gold;
}

const _templates = <DailyTask>[
  DailyTask(id: 'catch5', text: 'Поймайте 5 рыб', metric: 'catch', target: 5, silver: 80),
  DailyTask(id: 'catch12', text: 'Поймайте 12 рыб', metric: 'catch', target: 12, silver: 180),
  DailyTask(id: 'release8', text: 'Отпустите 8 рыб', metric: 'release', target: 8, silver: 140),
  DailyTask(id: 'release20', text: 'Отпустите 20 рыб', metric: 'release', target: 20, silver: 300),
  DailyTask(id: 'keep6', text: 'Заберите 6 рыб', metric: 'keep', target: 6, silver: 120),
  DailyTask(id: 'weight5', text: 'Налови 5 кг за день', metric: 'weight', target: 5000, silver: 150),
  DailyTask(id: 'weight20', text: 'Налови 20 кг за день', metric: 'weight', target: 20000, silver: 420),
  DailyTask(id: 'big3', text: 'Поймайте 3 рыбы крупнее 1 кг', metric: 'big', target: 3, silver: 200),
  DailyTask(id: 'trophy1', text: 'Поймайте трофейную рыбу', metric: 'trophy', target: 1, silver: 250, gold: 2),
  DailyTask(id: 'spend1500', text: 'Потратьте 1500 серебра', metric: 'spend', target: 1500, silver: 160),
];

/// Ключ календарного дня — совпадает с `_dayKey` в контроллере.
String taskDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Детерминированный набор из 4 поручений на день (стабилен в рамках суток).
List<DailyTask> dailyTasksFor(DateTime date) {
  final seed = date.year * 10000 + date.month * 100 + date.day;
  final pool = [..._templates]..shuffle(Random(seed));
  return pool.take(4).toList();
}
