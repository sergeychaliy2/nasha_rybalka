import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/features/tournaments/tournament.dart';

void main() {
  final t = kSeedTournaments.first;

  test('победитель получает первый приз и золото', () {
    final r = computeTournamentResult(t, 9999999, 42);
    expect(r.place, 1);
    expect(r.won, isTrue);
    expect(r.prizeSilver, t.reward1);
    expect(r.prizeGold, t.goldReward);
    expect(r.rows.length, 13); // 12 ботов + игрок
    expect(r.rows.first.isMe, isTrue);
  });

  test('нулевой улов — последнее место и без приза', () {
    final r = computeTournamentResult(t, 0, 42);
    expect(r.place, r.total);
    expect(r.prizeSilver, 0);
    expect(r.prizeGold, 0);
    expect(r.rows.last.isMe, isTrue);
  });

  test('результат детерминирован по seed', () {
    final a = computeTournamentResult(t, 3000, 7);
    final b = computeTournamentResult(t, 3000, 7);
    expect(a.place, b.place);
    expect(
      a.rows.map((e) => e.rating).toList(),
      b.rows.map((e) => e.rating).toList(),
    );
  });

  test('таблица отсортирована по убыванию зачёта', () {
    final r = computeTournamentResult(t, 2500, 99);
    for (var i = 1; i < r.rows.length; i++) {
      expect(r.rows[i - 1].rating >= r.rows[i].rating, isTrue);
      expect(r.rows[i].place, i + 1);
    }
  });

  test('превью соперников не содержит игрока', () {
    final rows = previewLeaderboard(t, t.id.hashCode);
    expect(rows.length, 12);
    expect(rows.any((e) => e.isMe), isFalse);
  });
}
