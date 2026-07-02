import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../shared/sound_service.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Настройки звука по умолчанию (для новых игроков). Игрок затем может
/// переопределить их в своих настройках. Хранится в overrides → `audio`.
class AudioEditor extends StatefulWidget {
  const AudioEditor({super.key, required this.overrides});
  final ContentOverrides overrides;

  @override
  State<AudioEditor> createState() => _AudioEditorState();
}

class _AudioEditorState extends State<AudioEditor> {
  late bool _enabled;
  late double _volume;
  late Map<String, bool> _effects;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final a = widget.overrides.audio();
    _enabled = (a['enabled'] as bool?) ?? true;
    _volume = (a['volume'] as num?)?.toDouble() ?? 0.9;
    _effects = {
      for (final s in Sfx.values)
        s.key: (a['effects'] is Map)
            ? ((a['effects'] as Map)[s.key] != false)
            : true,
    };
  }

  Future<void> _save() async {
    widget.overrides.setAudio({
      'enabled': _enabled,
      'volume': _volume,
      'effects': _effects,
    });
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() => _dirty = false);
    _toast('Сохранено · применится у новых игроков');
  }

  Future<void> _reset() async {
    widget.overrides.clearAudio();
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() {
      _enabled = true;
      _volume = 0.9;
      _effects = {for (final s in Sfx.values) s.key: true};
      _dirty = false;
    });
    _toast('Возврат к дефолту');
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: const Text('Звук по умолчанию', style: TextStyle(color: _gold)),
        actions: [
          TextButton(
              onPressed: _reset,
              child: const Text('К дефолту',
                  style: TextStyle(color: Colors.white54))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _dirty ? _save : null,
              icon: const Icon(Icons.save, size: 18, color: Colors.black),
              label:
                  const Text('Сохранить', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
              'Это дефолты для игроков, которые ещё не меняли звук в настройках. '
              'Каждый игрок может переопределить их у себя.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 12.5)),
          const SizedBox(height: 14),
          _panelBox(Column(children: [
            SwitchListTile(
              value: _enabled,
              activeThumbColor: _gold,
              contentPadding: EdgeInsets.zero,
              title: const Text('Звук включён',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              onChanged: (v) => setState(() {
                _enabled = v;
                _dirty = true;
              }),
            ),
            Row(children: [
              const Icon(Icons.volume_up, color: Colors.white54, size: 20),
              Expanded(
                child: Slider(
                  value: _volume,
                  activeColor: _gold,
                  divisions: 20,
                  label: '${(_volume * 100).round()}%',
                  onChanged: (v) => setState(() {
                    _volume = v;
                    _dirty = true;
                  }),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${(_volume * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70)),
              ),
            ]),
          ])),
          const SizedBox(height: 12),
          _panelBox(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Эффекты по умолчанию',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              for (final s in Sfx.values)
                SwitchListTile(
                  value: _effects[s.key] ?? true,
                  activeThumbColor: _gold,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.label,
                      style: const TextStyle(color: Colors.white)),
                  onChanged: (v) => setState(() {
                    _effects[s.key] = v;
                    _dirty = true;
                  }),
                ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _panelBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );
}
