import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../data/seed/content_state.dart';
import '../domain/entities/fishing_location.dart';
import '../features/map/region_store.dart';
import '../features/map/russia_geo.dart';
import '../features/tournaments/tournament.dart';
import '../shared/content_images.dart';
import 'map_view.dart';
import 'zone_editor.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Редактор турниров: создать / править / удалить. Полный список заменяет сид
/// (сохраняется в оверрайды; игра берёт после перезапуска).
class TournamentsEditor extends StatefulWidget {
  const TournamentsEditor({super.key, required this.overrides});
  final ContentOverrides overrides;

  @override
  State<TournamentsEditor> createState() => _TournamentsEditorState();
}

class _TournamentsEditorState extends State<TournamentsEditor> {
  late List<Tournament> _list;
  bool _dirty = false;
  List<RuRegion> _regions = [];
  Rect? _bounds;

  @override
  void initState() {
    super.initState();
    _list = [...(widget.overrides.tournaments() ?? kSeedTournaments)];
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final rs = await loadRuRegions();
    if (!mounted) return;
    setState(() {
      _regions = rs;
      _bounds = RussiaMapTransform.projectedBoundsOf(
          rs.expand((r) => r.rings).expand((ring) => ring));
    });
  }

  void _openZones(Tournament t) {
    final stem = t.backdrop.split('/').last.replaceAll('.png', '');
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ZoneEditor(overrides: widget.overrides, initialStem: stem)));
  }

  void _openBigMap() {
    if (_bounds == null) return;
    final geo = activeWaterGeo();
    final pins = <MapPin>[
      for (final t in _list)
        if (geo[t.locationId] != null)
          (
            id: t.id,
            label: t.title,
            lon: geo[t.locationId]!.$1,
            lat: geo[t.locationId]!.$2
          ),
    ];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminMapView(
        title: 'Карта турниров',
        regions: _regions,
        bounds: _bounds!,
        pins: pins,
        pinColor: const Color(0xFFE5483B),
        onTapPin: (id) {
          Navigator.of(context).pop();
          final t = _list.where((e) => e.id == id).firstOrNull;
          if (t != null) _openForm(t);
        },
      ),
    ));
  }

  Future<void> _openForm(Tournament? t) async {
    final res = await Navigator.of(context).push<Tournament>(
      MaterialPageRoute(builder: (_) => _TournamentForm(initial: t)),
    );
    if (res == null) return;
    setState(() {
      final i = _list.indexWhere((e) => e.id == res.id);
      if (i >= 0) {
        _list[i] = res;
      } else {
        _list.add(res);
      }
      _dirty = true;
    });
  }

  Future<void> _saveAll() async {
    widget.overrides.setTournaments(_list);
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() => _dirty = false);
    _toast('Сохранено · перезапусти игру');
  }

  Future<void> _resetSeed() async {
    widget.overrides.clearTournaments();
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() {
      _list = [...kSeedTournaments];
      _dirty = false;
    });
    _toast('Возврат к сид-турнирам');
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
        title: const Text('Турниры', style: TextStyle(color: _gold)),
        actions: [
          IconButton(
            tooltip: 'Открыть карту',
            onPressed: _openBigMap,
            icon: const Icon(Icons.public, color: _gold),
          ),
          TextButton(
              onPressed: _resetSeed,
              child: const Text('К сиду',
                  style: TextStyle(color: Colors.white54))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _dirty ? _saveAll : null,
              icon: const Icon(Icons.save, size: 18, color: Colors.black),
              label: const Text('Сохранить',
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Турнир'),
      ),
      body: Column(children: [
        _overview(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _row(_list[i], i),
          ),
        ),
      ]),
    );
  }

  /// Карта турниров: точка на водоёме каждого турнира; тап — открыть правку.
  Widget _overview() {
    if (_regions.isEmpty || _bounds == null) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }
    return Container(
      height: 240,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1016),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (ctx, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final t = RussiaMapTransform.fitRaw(_bounds!, size, paddingFrac: 0.02);
        final geo = activeWaterGeo();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            Tournament? best;
            var bestD = 20.0;
            for (final tt in _list) {
              final g = geo[tt.locationId];
              if (g == null) continue;
              final dd = (t.map(g.$1, g.$2) - d.localPosition).distance;
              if (dd < bestD) {
                bestD = dd;
                best = tt;
              }
            }
            if (best != null) _openForm(best);
          },
          child: CustomPaint(
              size: size,
              painter: _TourMapPainter(t, _regions, _list, geo)),
        );
      }),
    );
  }

  Widget _row(Tournament t, int i) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openForm(t),
        child: Row(children: [
          SizedBox(
            width: 96,
            height: 74,
            child: contentImage(assetStem(t.backdrop), t.backdrop),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    '${t.locationName} · ур.${t.requiredLevel} · '
                    '${t.durationSec ~/ 60}мин · 🥇${t.reward1}/${t.goldReward}з',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Правка',
            onPressed: () => _openForm(t),
            icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
          ),
          IconButton(
            tooltip: 'Зоны заброса водоёма',
            onPressed: () => _openZones(t),
            icon: const Icon(Icons.brush, color: Color(0xFF56C271), size: 20),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => setState(() {
              _list.removeAt(i);
              _dirty = true;
            }),
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFE5726A), size: 20),
          ),
        ]),
      ),
    );
  }
}

class _TournamentForm extends StatefulWidget {
  const _TournamentForm({this.initial});
  final Tournament? initial;

  @override
  State<_TournamentForm> createState() => _TournamentFormState();
}

class _TournamentFormState extends State<_TournamentForm> {
  late final Map<String, TextEditingController> _c;
  late String _locId;
  List<RuRegion> _regions = [];
  Rect? _bounds;

  Future<void> _loadRegions() async {
    final rs = await loadRuRegions();
    if (!mounted) return;
    setState(() {
      _regions = rs;
      _bounds = RussiaMapTransform.projectedBoundsOf(
          rs.expand((r) => r.rings).expand((ring) => ring));
    });
  }

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _c = {
      for (final k in [
        'title',
        'dateRange',
        'stageCount',
        'requiredLevel',
        'entrySilver',
        'entryGold',
        'durationSec',
        'parGrams',
        'reward1',
        'reward2',
        'reward3',
        'goldReward',
        'info',
      ])
        k: TextEditingController(),
    };
    if (t != null) {
      _c['title']!.text = t.title;
      _c['dateRange']!.text = t.dateRange;
      _c['stageCount']!.text = '${t.stageCount}';
      _c['requiredLevel']!.text = '${t.requiredLevel}';
      _c['entrySilver']!.text = '${t.entrySilver}';
      _c['entryGold']!.text = '${t.entryGold}';
      _c['durationSec']!.text = '${t.durationSec}';
      _c['parGrams']!.text = '${t.parGrams}';
      _c['reward1']!.text = '${t.reward1}';
      _c['reward2']!.text = '${t.reward2}';
      _c['reward3']!.text = '${t.reward3}';
      _c['goldReward']!.text = '${t.goldReward}';
      _c['info']!.text = t.info;
      _locId = t.locationId;
    } else {
      _c['stageCount']!.text = '1';
      _c['requiredLevel']!.text = '1';
      _c['durationSec']!.text = '150';
      _c['parGrams']!.text = '2000';
      _locId = activeLocations().first.id;
    }
    _loadRegions();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(String k, int d) => int.tryParse(_c[k]!.text.trim()) ?? d;

  void _save() {
    final loc = activeLocations().firstWhere((l) => l.id == _locId,
        orElse: () => activeLocations().first);
    final id = widget.initial?.id ??
        'tour_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.of(context).pop(Tournament(
      id: id,
      title: _c['title']!.text.trim().isEmpty
          ? 'Новый турнир'
          : _c['title']!.text.trim(),
      dateRange: _c['dateRange']!.text.trim(),
      locationName: loc.name,
      locationId: loc.id,
      backdrop: loc.primaryBackdrop,
      stageCount: _int('stageCount', 1),
      requiredLevel: _int('requiredLevel', 1),
      entrySilver: _int('entrySilver', 0),
      entryGold: _int('entryGold', 0),
      durationSec: _int('durationSec', 120),
      parGrams: _int('parGrams', 1000),
      reward1: _int('reward1', 0),
      reward2: _int('reward2', 0),
      reward3: _int('reward3', 0),
      goldReward: _int('goldReward', 0),
      info: _c['info']!.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(widget.initial == null ? 'Новый турнир' : 'Правка турнира',
            style: const TextStyle(color: _gold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18, color: Colors.black),
              label: const Text('Готово',
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _text('title', 'Название'),
          _text('dateRange', 'Подзаголовок (напр. «Серия · 3 этапа»)'),
          const SizedBox(height: 4),
          const Text('Место проведения: тапни водоём на карте (красная точка)',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _venueMap(),
          const SizedBox(height: 8),
          _locationPicker(),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _num('stageCount', 'Этапы'),
            _num('requiredLevel', 'Треб. уровень'),
            _num('durationSec', 'Длит., сек'),
            _num('parGrams', 'Сила ботов (пар, г)'),
            _num('entrySilver', 'Взнос серебро'),
            _num('entryGold', 'Взнос золото'),
            _num('reward1', 'Приз 1 (серебро)'),
            _num('reward2', 'Приз 2'),
            _num('reward3', 'Приз 3'),
            _num('goldReward', 'Золото победителю'),
          ]),
          const SizedBox(height: 12),
          _text('info', 'Описание', lines: 4),
        ],
      ),
    );
  }

  Widget _text(String k, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[k],
          maxLines: lines,
          style: const TextStyle(color: Colors.white),
          decoration: _dec(label),
        ),
      );

  Widget _num(String k, String label) => SizedBox(
        width: 180,
        child: TextField(
          controller: _c[k],
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _dec(label),
        ),
      );

  /// Карта выбора места: границы регионов, водоёмы точками; выбранный —
  /// красным (цвет турниров). Тап по точке — назначить водоём турниру.
  Widget _venueMap() {
    if (_regions.isEmpty || _bounds == null) {
      return const SizedBox(
          height: 230, child: Center(child: CircularProgressIndicator()));
    }
    final geo = activeWaterGeo();
    final locs = activeLocations();
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1016),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (ctx, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final t = RussiaMapTransform.fitRaw(_bounds!, size, paddingFrac: 0.02);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            String? best;
            var bestD = 22.0;
            for (final l in locs) {
              final g = geo[l.id];
              if (g == null) continue;
              final dd = (t.map(g.$1, g.$2) - d.localPosition).distance;
              if (dd < bestD) {
                bestD = dd;
                best = l.id;
              }
            }
            if (best != null) setState(() => _locId = best!);
          },
          child: CustomPaint(
            size: size,
            painter: _VenuePickPainter(t, _regions, locs, geo, _locId),
          ),
        );
      }),
    );
  }

  Widget _locationPicker() {
    return InputDecorator(
      decoration: _dec('Водоём (зачётная сессия)'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _locId,
          isExpanded: true,
          dropdownColor: _panel,
          style: const TextStyle(color: Colors.white),
          items: [
            for (final l in activeLocations())
              DropdownMenuItem(value: l.id, child: Text(l.name)),
          ],
          onChanged: (v) => setState(() => _locId = v ?? _locId),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _gold)),
      );
}

class _TourMapPainter extends CustomPainter {
  _TourMapPainter(this.t, this.regions, this.list, this.geo);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<Tournament> list;
  final Map<String, (double, double)> geo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B1016));
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x2AFFFFFF);
    for (final r in regions) {
      final path = Path();
      for (final ring in r.rings) {
        for (var i = 0; i < ring.length; i++) {
          final p = t.map(ring[i].dx, ring[i].dy);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
      }
      canvas.drawPath(path, Paint()..color = const Color(0xFF16221B));
      canvas.drawPath(path, border);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    const red = Color(0xFFE5483B);
    for (final tt in list) {
      final g = geo[tt.locationId];
      if (g == null) continue;
      final p = t.map(g.$1, g.$2);
      canvas.drawCircle(p, 6, Paint()..color = red.withValues(alpha: 0.25));
      canvas.drawCircle(p, 3.4, Paint()..color = red);
      canvas.drawCircle(
          p,
          3.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black);
      tp.text = TextSpan(
          text: tt.title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)]));
      tp.layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _TourMapPainter old) => true;
}

/// Карта выбора места турнира: регионы с границами, водоёмы золотыми точками,
/// выбранный — крупной красной (цвет турниров) с подписью.
class _VenuePickPainter extends CustomPainter {
  _VenuePickPainter(this.t, this.regions, this.locs, this.geo, this.selectedId);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<FishingLocation> locs;
  final Map<String, (double, double)> geo;
  final String selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B1016));
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x2AFFFFFF);
    for (final r in regions) {
      final path = Path();
      for (final ring in r.rings) {
        for (var i = 0; i < ring.length; i++) {
          final p = t.map(ring[i].dx, ring[i].dy);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
      }
      canvas.drawPath(path, Paint()..color = const Color(0xFF16221B));
      canvas.drawPath(path, border);
    }
    const red = Color(0xFFE5483B);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final l in locs) {
      final g = geo[l.id];
      if (g == null) continue;
      final p = t.map(g.$1, g.$2);
      final sel = l.id == selectedId;
      if (sel) {
        canvas.drawCircle(p, 9, Paint()..color = red.withValues(alpha: 0.3));
        canvas.drawCircle(p, 4.4, Paint()..color = red);
        canvas.drawCircle(
            p,
            4.4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Colors.black);
      } else {
        canvas.drawCircle(p, 2.6, Paint()..color = _gold);
      }
      tp.text = TextSpan(
          text: l.name,
          style: TextStyle(
              color: sel ? Colors.white : Colors.white60,
              fontSize: sel ? 9.5 : 8,
              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)]));
      tp.layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy + (sel ? 7 : 4)));
    }
  }

  @override
  bool shouldRepaint(covariant _VenuePickPainter old) =>
      old.selectedId != selectedId;
}
