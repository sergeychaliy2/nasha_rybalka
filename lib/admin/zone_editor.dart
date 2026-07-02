import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../data/seed/seed_content.dart';
import '../features/fishing/water_masks.dart';
import '../shared/content_images.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);
const _mw = kWaterMaskW;
const _mh = kWaterMaskH;

/// Редактор зон заброса: рисуешь кистью по фону локации, где ВОДА (можно
/// забрасывать) и где НЕЛЬЗЯ. Сохраняется в оверрайды; игра берёт после
/// перезапуска. База — авто-маска [kWaterMasks].
class ZoneEditor extends StatefulWidget {
  const ZoneEditor({super.key, required this.overrides, this.initialStem});
  final ContentOverrides overrides;

  /// Открыть сразу на локации с этим фоном (stem, напр. `ru_baikal`).
  final String? initialStem;

  @override
  State<ZoneEditor> createState() => _ZoneEditorState();
}

class _LocOpt {
  _LocOpt(this.name, this.stem, this.backdrop);
  final String name;
  final String stem;
  final String backdrop;
}

class _ZoneEditorState extends State<ZoneEditor> {
  late final List<_LocOpt> _locs;
  int _sel = 0;
  List<bool> _cells = List.filled(_mw * _mh, false);
  bool _addWater = false; // false — рисуем «нельзя», true — «вода»
  int _brush = 2;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _locs = [
      for (final l in SeedContent.locations)
        if (kWaterMasks.containsKey(_stem(l.primaryBackdrop)))
          _LocOpt(l.name, _stem(l.primaryBackdrop), l.primaryBackdrop),
    ];
    var start = 0;
    if (widget.initialStem != null) {
      final i = _locs.indexWhere((l) => l.stem == widget.initialStem);
      if (i >= 0) start = i;
    }
    if (_locs.isNotEmpty) _load(start);
  }

  static String _stem(String path) {
    final s = path.split('/').last;
    return s.endsWith('.png') ? s.substring(0, s.length - 4) : s;
  }

  void _load(int i) {
    _sel = i;
    final stem = _locs[i].stem;
    final src = widget.overrides.waterMasks()[stem] ?? kWaterMasks[stem] ?? '';
    _cells = List.generate(
        _mw * _mh, (k) => k < src.length && src[k] == '1');
    _dirty = false;
    setState(() {});
  }

  void _paintAt(Offset pos, Size box) {
    final col = (pos.dx / box.width * _mw).floor();
    final row = (pos.dy / box.height * _mh).floor();
    for (var dr = -_brush; dr <= _brush; dr++) {
      for (var dc = -_brush; dc <= _brush; dc++) {
        if (dc * dc + dr * dr > _brush * _brush + 1) continue;
        final r = row + dr, c = col + dc;
        if (r < 0 || r >= _mh || c < 0 || c >= _mw) continue;
        _cells[r * _mw + c] = _addWater;
      }
    }
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final str = _cells.map((b) => b ? '1' : '0').join();
    widget.overrides.setWaterMask(_locs[_sel].stem, str);
    await widget.overrides.save();
    widget.overrides.applyToGame();
    if (mounted) _toast('Сохранено · перезапусти игру, чтобы увидеть');
  }

  void _resetAuto() {
    final stem = _locs[_sel].stem;
    final src = kWaterMasks[stem] ?? '';
    setState(() {
      _cells = List.generate(_mw * _mh, (k) => k < src.length && src[k] == '1');
      _dirty = true;
    });
  }

  Future<void> _clearOverride() async {
    widget.overrides.clearWaterMask(_locs[_sel].stem);
    await widget.overrides.save();
    widget.overrides.applyToGame();
    _load(_sel);
    if (mounted) _toast('Оверрайд снят — вернулась авто-маска');
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(m),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _panel,
    ));

  @override
  Widget build(BuildContext context) {
    if (_locs.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Нет локаций с масками')));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        title: const Text('Зоны заброса', style: TextStyle(color: _gold)),
        iconTheme: const IconThemeData(color: _gold),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _toolbar(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(builder: (ctx, c) {
                      final w = c.maxWidth;
                      final box = Size(w, w * _mh / _mw);
                      return SizedBox(
                        width: box.width,
                        height: box.height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _paintAt(d.localPosition, box),
                            onPanStart: (d) => _paintAt(d.localPosition, box),
                            onPanUpdate: (d) => _paintAt(d.localPosition, box),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                contentImage(
                                    _locs[_sel].stem, _locs[_sel].backdrop),
                                CustomPaint(painter: _MaskOverlay(_cells)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            _legend(),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      color: const Color(0xFF10151B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<int>(
            value: _sel,
            dropdownColor: _panel,
            underline: const SizedBox.shrink(),
            items: [
              for (var i = 0; i < _locs.length; i++)
                DropdownMenuItem(value: i, child: Text(_locs[i].name)),
            ],
            onChanged: (v) {
              if (v != null) _load(v);
            },
          ),
          _seg(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Кисть', style: TextStyle(color: Colors.white54)),
            SizedBox(
              width: 130,
              child: Slider(
                value: _brush.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                activeColor: _gold,
                label: '$_brush',
                onChanged: (v) => setState(() => _brush = v.round()),
              ),
            ),
          ]),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _gold),
            onPressed: _dirty ? _save : null,
            icon: const Icon(Icons.save, size: 18, color: Colors.black),
            label: const Text('Сохранить',
                style: TextStyle(color: Colors.black)),
          ),
          OutlinedButton.icon(
            onPressed: _resetAuto,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Авто-маска'),
          ),
          TextButton(
            onPressed: _clearOverride,
            child: const Text('Снять оверрайд',
                style: TextStyle(color: Color(0xFFE5836A))),
          ),
        ],
      ),
    );
  }

  Widget _seg() {
    Widget btn(String label, bool water, IconData ic) {
      final on = _addWater == water;
      final col = water ? const Color(0xFF56C271) : const Color(0xFFE5726A);
      return GestureDetector(
        onTap: () => setState(() => _addWater = water),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? col.withValues(alpha: 0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: on ? col : Colors.white24),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 15, color: on ? col : Colors.white54),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: on ? col : Colors.white54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
          ]),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn('Нельзя', false, Icons.block),
      const SizedBox(width: 6),
      btn('Вода', true, Icons.water_drop),
    ]);
  }

  Widget _legend() {
    Widget chip(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, color: c),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        chip(const Color(0x8856C271), 'вода — можно забрасывать'),
        const SizedBox(width: 20),
        chip(const Color(0x88E5726A), 'нельзя забрасывать'),
      ]),
    );
  }
}

class _MaskOverlay extends CustomPainter {
  _MaskOverlay(this.cells);
  final List<bool> cells;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / _mw, ch = size.height / _mh;
    final water = Paint()..color = const Color(0x3356C271);
    final block = Paint()..color = const Color(0x66E5726A);
    for (var r = 0; r < _mh; r++) {
      for (var c = 0; c < _mw; c++) {
        final rect = Rect.fromLTWH(c * cw, r * ch, cw + 0.5, ch + 0.5);
        canvas.drawRect(rect, cells[r * _mw + c] ? water : block);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MaskOverlay old) => true;
}
