import 'package:audioplayers/audioplayers.dart';

/// Звуки игры: короткие синтезированные эффекты (assets/audio, оригинальные).
///
/// Пул плееров по кругу, чтобы эффекты могли накладываться (всплеск + клёв).
/// Глобальный выключатель [enabled] связан с настройкой «Звук».
class SoundService {
  SoundService._();

  static bool enabled = true;

  static final List<AudioPlayer> _pool = [
    for (var i = 0; i < 4; i++) AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  ];
  static int _next = 0;

  static void _play(String file, {double volume = 1.0}) {
    if (!enabled) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    // Ошибки аудио не должны ронять геймплей (нет устройства и т.п.).
    p.play(AssetSource('audio/$file'), volume: volume).catchError((_) {});
  }

  /// Всплеск приводнения оснастки.
  static void splash() => _play('splash.wav', volume: 0.8);

  /// Поклёвка — пора подсекать.
  static void bite() => _play('bite.wav');

  /// Улов в садке.
  static void catchFish() => _play('catch.wav', volume: 0.9);

  /// Щелчок катушки (подмотка).
  static void reelClick() => _play('reel_click.wav', volume: 0.6);

  /// Писк эхолота (включение/выключение).
  static void sonarBeep() => _play('sonar_beep.wav', volume: 0.7);

  /// Начался дождь.
  static void rainStart() => _play('rain_start.wav', volume: 0.7);
}
