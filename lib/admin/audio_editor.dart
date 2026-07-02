import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../shared/content_audio.dart';
import '../shared/sound_service.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Замена аудиофайлов игры: музыка меню и звуковые эффекты. Громкость и
/// включение игрок настраивает у себя (в игре) — здесь только сами файлы.
/// Загруженный файл кладётся в общую папку и читается игрой напрямую.
class AudioEditor extends StatefulWidget {
  const AudioEditor({super.key});

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
              Text(custom ? 'своя запись' : 'встроенная',
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
