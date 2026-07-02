import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/content_audio.dart';
import '../shared/sound_service.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Замена аудиофайлов игры (музыка меню и эффекты) + просмотр ТЕКУЩИХ настроек
/// звука игрока на этом устройстве (громкость/вкл — только чтение, их меняет
/// игрок в игре). Загруженный файл кладётся в общую папку и читается игрой.
class AudioEditor extends StatefulWidget {
  const AudioEditor({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<AudioEditor> createState() => _AudioEditorState();
}

class _Slot {
  const _Slot(this.key, this.label, this.asset, this.icon);
  final String key;
  final String label;
  final String asset;
  final IconData icon;
}

class _AudioEditorState extends State<AudioEditor> {
  static const _slots = [
    _Slot('music', 'Музыка меню', 'menu_music.wav', Icons.music_note),
    _Slot('splash', 'Всплеск заброса', 'splash.wav', Icons.water),
    _Slot('bite', 'Поклёвка', 'bite.wav', Icons.notifications_active),
    _Slot('catch', 'Улов', 'catch.wav', Icons.celebration),
    _Slot('reel', 'Катушка', 'reel_click.wav', Icons.settings),
    _Slot('sonar', 'Эхолот', 'sonar_beep.wav', Icons.radar),
    _Slot('rain', 'Дождь', 'rain_start.wav', Icons.grain),
  ];

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel));

  Future<void> _upload(_Slot s) async {
    const group = XTypeGroup(
        label: 'Аудио', extensions: ['wav', 'mp3', 'ogg', 'm4a', 'aac']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last : 'wav';
    saveContentAudio(s.key, ext, await file.readAsBytes());
    if (mounted) {
      setState(() {});
      _toast('Загружено: $name');
    }
  }

  void _delete(_Slot s) {
    deleteContentAudio(s.key);
    setState(() {});
    _toast('Файл заменён на встроенный');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: const Text('Аудио игры', style: TextStyle(color: _gold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _currentSettings(),
          const SizedBox(height: 14),
          Text(
              'Замена файлов музыки и эффектов. Форматы: WAV, MP3, OGG, M4A. '
              'Громкость и включение звука игрок настраивает в самой игре.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 12.5)),
          const SizedBox(height: 14),
          for (final s in _slots) _row(s),
        ],
      ),
    );
  }

  /// Текущие настройки звука на этом устройстве (общий стор с игрой) — только
  /// для просмотра; меняет их игрок в самой игре.
  Widget _currentSettings() {
    final p = widget.prefs;
    final soundOn = p.getBool('settings.sound') ?? true;
    final vol = ((p.getDouble('settings.soundVolume') ?? 0.9) * 100).round();
    final musicOn = p.getBool('settings.music') ?? true;
    final mvol = ((p.getDouble('settings.musicVolume') ?? 0.5) * 100).round();
    String pct(String key) {
      final v = p.getDouble('settings.sfxVol.$key');
      if (v != null) return '${(v * 100).round()}%';
      final legacy = p.getBool('settings.sfx.$key');
      return legacy == false ? '0%' : '100%';
    }

    Widget chip(String label, String value, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: (on ? _gold : const Color(0xFFE5726A))
                    .withValues(alpha: 0.4)),
          ),
          child: Text('$label: $value',
              style: TextStyle(
                  color: on ? Colors.white : Colors.white54, fontSize: 12)),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tune, color: _gold, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Текущие настройки звука (на этом устройстве)',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('Музыка', musicOn ? '$mvol%' : 'выкл', musicOn),
            chip('Эффекты (общее)', soundOn ? '$vol%' : 'выкл', soundOn),
            for (final s in Sfx.values) chip(s.label, pct(s.key), soundOn),
          ]),
        ],
      ),
    );
  }

  Widget _row(_Slot s) {
    final custom = hasContentAudio(s.key);
    final isMusic = s.key == 'music';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (isMusic ? _gold : Colors.white).withValues(alpha: 0.14)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isMusic ? _gold : const Color(0xFF54C9C9))
                .withValues(alpha: 0.16),
          ),
          child: Icon(s.icon,
              color: isMusic ? _gold : const Color(0xFF54C9C9), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              Text(
                  custom
                      ? 'своя запись · ${(contentAudioPath(s.key) ?? '').split('.').last.toUpperCase()}'
                      : 'встроенная',
                  style: TextStyle(
                      color: custom
                          ? const Color(0xFF56C271)
                          : Colors.white38,
                      fontSize: 11.5)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Прослушать',
          onPressed: () => SoundService.previewOnce(s.key, s.asset),
          icon: const Icon(Icons.play_circle, color: Colors.white70),
        ),
        TextButton.icon(
          onPressed: () => _upload(s),
          icon: const Icon(Icons.upload, size: 16, color: _gold),
          label: const Text('Заменить…',
              style: TextStyle(color: _gold, fontSize: 12.5)),
        ),
        if (custom)
          IconButton(
            tooltip: 'Вернуть встроенный',
            onPressed: () => _delete(s),
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFE5726A), size: 20),
          ),
      ]),
    );
  }
}
