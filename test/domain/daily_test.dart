import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/domain/entities/player.dart';

void main() {
  test('новая игра — ежедневка доступна, серия с 1', () {
    final p = Player.newGame('Тест');
    expect(p.dailyAvailable, isTrue);
    expect(p.dailyNextStreak, 1);
  });

  test('после получения сегодня — недоступна', () {
    final p = Player.newGame('Тест')
        .copyWith(lastDailyClaim: DateTime.now(), dailyStreak: 1);
    expect(p.dailyAvailable, isFalse);
    expect(p.dailyNextStreak, 1); // показываем текущую серию
  });

  test('заход на следующий день продолжает серию', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final p = Player.newGame('Тест')
        .copyWith(lastDailyClaim: yesterday, dailyStreak: 3);
    expect(p.dailyAvailable, isTrue);
    expect(p.dailyNextStreak, 4);
  });

  test('пропуск дня сбрасывает серию к 1', () {
    final old = DateTime.now().subtract(const Duration(days: 3));
    final p = Player.newGame('Тест')
        .copyWith(lastDailyClaim: old, dailyStreak: 5);
    expect(p.dailyAvailable, isTrue);
    expect(p.dailyNextStreak, 1);
  });

  test('турнирные поля сериализуются', () {
    final p = Player.newGame('Тест').copyWith(
      activeTournamentId: 'summer_champ',
      tournamentScore: 4200,
      tournamentWins: 2,
      dailyStreak: 4,
    );
    final back = Player.fromJson(p.toJson());
    expect(back.activeTournamentId, 'summer_champ');
    expect(back.tournamentScore, 4200);
    expect(back.tournamentWins, 2);
    expect(back.dailyStreak, 4);
    expect(back.inTournament, isTrue);
  });
}
