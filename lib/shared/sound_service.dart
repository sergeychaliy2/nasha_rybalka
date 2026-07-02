import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_audio.dart';

/// Идентификаторы звуковых эффектов (для пофайловых настроек и замены файла).
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

/// Аудио игры: короткие эффекты (перекрываются пулом плееров) и фоновая
/// музыка меню (луп). Громкость и переключатели — настройки ИГРОКА (в игре).
/// Сами файлы (эффекты и музыку) можно заменить в админке — см. [audioSource]
/// (свой файл → встроенный ассет).
class SoundService {
  SoundService._();

  // Эффекты. У каждого — своя громкость 0..1 (0 = выключен).
  static bool enabled = true;
  static double volume = 0.9;
  static final Map<String, double> _effectVol = {
    for (final s in Sfx.values) s.key: 1.0,
  };

  // Музыка меню.
  static bool musicEnabled = true;
  static double musicVolume = 0.5;
  static const musicFile = 'menu_music.wav';
  static const musicKey = 'music';

  static final List<AudioPlayer> _pool = [
    for (var i = 0; i < 4; i++) AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  ];
  static int _next = 0;
  static final AudioPlayer _music = AudioPlayer()
    ..setReleaseMode(ReleaseMode.loop);
  static final AudioPlayer _preview = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  static bool _musicPlaying = false;

  static double effectVolume(Sfx s) => _effectVol[s.key] ?? 1.0;
  static bool isEffectOn(Sfx s) => (_effectVol[s.key] ?? 1.0) > 0;

  /// Настройки игрока. Ключи prefs: `settings.sound`, `settings.soundVolume`,
  /// `settings.sfxVol.<key>` (громкость эффекта 0..1), `settings.music`,
  /// `settings.musicVolume`. Совместимость: старый тумблер `settings.sfx.<key>`
  /// (false → громкость 0).
  static void loadFromPrefs(SharedPreferences prefs) {
    enabled = prefs.getBool('settings.sound') ?? true;
    volume = prefs.getDouble('settings.soundVolume') ?? 0.9;
    for (final s in Sfx.values) {
      final v = prefs.getDouble('settings.sfxVol.${s.key}');
      if (v != null) {
        _effectVol[s.key] = v.clamp(0.0, 1.0);
      } else {
        final legacy = prefs.getBool('settings.sfx.${s.key}');
        _effectVol[s.key] = legacy == false ? 0.0 : 1.0;
      }
    }
    musicEnabled = prefs.getBool('settings.music') ?? true;
    musicVolume = prefs.getDouble('settings.musicVolume') ?? 0.5;
  }

  // --- Эффекты ------------------------------------------------------------------

  static void setEnabled(SharedPreferences prefs, bool v) {
    enabled = v;
    prefs.setBool('settings.sound', v);
  }

  static void setVolume(SharedPreferences prefs, double v) {
    volume = v.clamp(0.0, 1.0);
    prefs.setDouble('settings.soundVolume', volume);
  }

  static void setEffectVolume(SharedPreferences prefs, Sfx s, double v) {
    _effectVol[s.key] = v.clamp(0.0, 1.0);
    prefs.setDouble('settings.sfxVol.${s.key}', _effectVol[s.key]!);
  }

  static void play(Sfx s) {
    final ev = _effectVol[s.key] ?? 1.0;
    if (!enabled || volume <= 0 || ev <= 0) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    p
        .play(audioSource(s.key, s.file), volume: s.baseVolume * volume * ev)
        .catchError((_) {});
  }

  static void splash() => play(Sfx.splash);
  static void bite() => play(Sfx.bite);
  static void catchFish() => play(Sfx.catchFish);
  static void reelClick() => play(Sfx.reel);
  static void sonarBeep() => play(Sfx.sonar);
  static void rainStart() => play(Sfx.rain);

  // --- Музыка меню --------------------------------------------------------------

  static void startMenuMusic() {
    if (!musicEnabled || musicVolume <= 0) return;
    if (_musicPlaying) {
      _music.setVolume(musicVolume);
      return;
    }
    _musicPlaying = true;
    _music
        .play(audioSource(musicKey, musicFile), volume: musicVolume)
        .catchError((_) {
      _musicPlaying = false;
    });
  }

  static void stopMenuMusic() {
    _musicPlaying = false;
    _music.stop().catchError((_) {});
  }

  static void setMusicEnabled(SharedPreferences prefs, bool v) {
    musicEnabled = v;
    prefs.setBool('settings.music', v);
    if (v) {
      startMenuMusic();
    } else {
      stopMenuMusic();
    }
  }

  static void setMusicVolume(SharedPreferences prefs, double v) {
    musicVolume = v.clamp(0.0, 1.0);
    prefs.setDouble('settings.musicVolume', musicVolume);
    if (_musicPlaying) _music.setVolume(musicVolume);
  }

  /// Разовое прослушивание файла (для проверки в админке/настройках).
  static void previewOnce(String key, String assetFile) {
    _preview.stop();
    _preview.play(audioSource(key, assetFile), volume: 0.9).catchError((_) {});
  }
}
