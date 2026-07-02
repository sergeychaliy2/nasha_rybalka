import '../entities/player.dart';

/// Хранилище профиля игрока (локальный сейв на устройстве).
abstract interface class PlayerRepository {
  /// Загружает сохранённого игрока или null, если новой игры ещё не было.
  Future<Player?> load();

  /// Сохраняет полный снимок прогресса.
  Future<void> save(Player player);

  /// Сбрасывает прогресс (новая игра).
  Future<void> clear();
}
