import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Идентификаторы звуковых эффектов (для пофайловых настроек и админ-дефолтов).
enum Sfx { splash, bite, catchFish, reel, sonar, rain }

extension SfxMeta on Sfx {
  String get key => switch (this) {
        Sfx.splash => 'splash',
        Sfx.bite => 'bite',
        Sfx.catchFish => 'catch',
        Sfx.reel => 'reel',
        Sfx.sonar => 'sonar',
        Sfx.rain => 'rain',
      };
  String get label => switch (this) {
        Sfx.splash => 'Всплеск заброса',
        Sfx.bite => 'Поклёвка',
        Sfx.catchFish => 'Улов',
        Sfx.reel => 'Катушка',
        Sfx.sonar => 'Эхолот',
        Sfx.rain => 'Дождь',
      };
  String get file => switch (this) {
        Sfx.splash => 'splash.wav',
        Sfx.bite => 'bite.wav',
        Sfx.catchFish => 'catch.wav',
        Sfx.reel => 'reel_click.wav',
        Sfx.sonar => 'sonar_beep.wav',
        Sfx.rain => 'rain_start.wav',
      };
  double get baseVolume => switch (this) {
        Sfx.splash => 0.8,
        Sfx.bite => 1.0,
        Sfx.catchFish => 0.9,
        Sfx.reel => 0.6,
        Sfx.sonar => 0.7,
        Sfx.rain => 0.7,
      };
}

/// Звуки игры: короткие синтезированные эффекты (assets/audio, оригинальные).
///
/// Пул плееров по кругу, чтобы эффекты могли накладываться. Настройки:
/// мастер-выключатель [enabled], общая громкость [volume] и пофайловые
/// переключатели. Дефолты можно задать в админке (см. `ContentOverrides.audio`
/// → [applyAdminDefaults]); настройки игрока их переопределяют.
class SoundService {
  SoundService._();

  static bool enabled = true;
  static double volume = 0.9;
  static final Map<String, bool> _effectOn = {
    for (final s in Sfx.values) s.key: true,
  };

  // Админ-дефолты (применяются, если у игрока нет своей настройки).
  static bool _defEnabled = true;
  static double _defVolume = 0.9;
  static final Map<String, bool> _defEffectOn = {
    for (final s in Sfx.values) s.key: true,
  };

  static final List<AudioPlayer> _pool = [
    for (var i = 0; i < 4; i++) AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  ];
  static int _next = 0;

  static bool isEffectOn(Sfx s) => _effectOn[s.key] ?? true;

  /// Дефолты из админки (override-слой). Вызывается на старте до чтения prefs.
  static void applyAdminDefaults({
    bool? enabled,
    double? volume,
    Map<String, bool>? effects,
  }) {
    if (enabled != null) _defEnabled = enabled;
    if (volume != null) _defVolume = volume.clamp(0.0, 1.0);
    if (effects != null) {
      for (final e in effects.entries) {
        _defEffectOn[e.key] = e.value;
      }
    }
  }

  /// Настройки игрока (перекрывают дефолты). Ключи prefs:
  /// `settings.sound`, `settings.soundVolume`, `settings.sfx.<key>`.
  static void loadFromPrefs(SharedPreferences prefs) {
    enabled = prefs.getBool('settings.sound') ?? _defEnabled;
    volume = prefs.getDouble('settings.soundVolume') ?? _defVolume;
    for (final s in Sfx.values) {
      _effectOn[s.key] = prefs.getBool('settings.sfx.${s.key}') ??
          (_defEffectOn[s.key] ?? true);
    }
  }

  static void setEnabled(SharedPreferences prefs, bool v) {
    enabled = v;
    prefs.setBool('settings.sound', v);
  }

  static void setVolume(SharedPreferences prefs, double v) {
    volume = v.clamp(0.0, 1.0);
    prefs.setDouble('settings.soundVolume', volume);
  }

  static void setEffect(SharedPreferences prefs, Sfx s, bool v) {
    _effectOn[s.key] = v;
    prefs.setBool('settings.sfx.${s.key}', v);
  }

  static void play(Sfx s) {
    if (!enabled || volume <= 0 || !(_effectOn[s.key] ?? true)) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    // Ошибки аудио не должны ронять геймплей (нет устройства и т.п.).
    p
        .play(AssetSource('audio/${s.file}'), volume: s.baseVolume * volume)
        .catchError((_) {});
  }

  static void splash() => play(Sfx.splash);
  static void bite() => play(Sfx.bite);
  static void catchFish() => play(Sfx.catchFish);
  static void reelClick() => play(Sfx.reel);
  static void sonarBeep() => play(Sfx.sonar);
  static void rainStart() => play(Sfx.rain);
}
