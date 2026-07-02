import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../data/seed/content_state.dart';
import '../domain/entities/fishing_location.dart';
import '../features/map/region_store.dart';
import '../features/map/russia_geo.dart';
import '../features/tournaments/tournament.dart';
import '../shared/content_images.dart';
import 'admin_widgets.dart';
import 'image_picker.dart';
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
  RuRegion? _filter;

  /// Точка турнира на карте: своя, иначе геопозиция водоёма.
  (double, double)? _tourPoint(Tournament t) =>
      t.hasOwnPoint ? (t.lon, t.lat) : activeWaterGeo()[t.locationId];

  List<Tournament> get _shown {
    final f = _filter;
    if (f == null) return _list;
    return _list.where((t) {
      final p = _tourPoint(t);
      return p != null && f.contains(p.$1, p.$2);
    }).toList();
  }

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
    (double, double)? pt(Tournament t) =>
        t.hasOwnPoint ? (t.lon, t.lat) : geo[t.locationId];
    final pins = <MapPin>[
      for (final t in _list)
        if (pt(t) != null)
          (id: t.id, label: t.title, lon: pt(t)!.$1, lat: pt(t)!.$2),
    ];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminMapView(
        title: 'Карта турниров',
        regions: _regions,
        bounds: _bounds!,
        pins: pins,
        itemWord: 'турниров',
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
        RegionFilterBar(
          regions: _regions,
          selected: _filter,
          shownCount: _shown.length,
          word: 'турниров',
          onChanged: (r) => setState(() => _filter = r),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _row(_shown[i]),
          ),
        ),
      ]),
    );
  }

  /// Карта турниров: точки турниров (тап — правка), тап по региону — фильтр.
  Widget _overview() {
    if (_regions.isEmpty || _bounds == null) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }
    return Container(
      height: 240,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1016),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (ctx, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final t = RussiaMapTransform.fitRaw(_bounds!, size, paddingFrac: 0.02);
        return Stack(children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              Tournament? best;
              var bestD = 16.0;
              for (final tt in _list) {
                final g = _tourPoint(tt);
                if (g == null) continue;
                final dd = (t.map(g.$1, g.$2) - d.localPosition).distance;
                if (dd < bestD) {
                  bestD = dd;
                  best = tt;
                }
              }
              if (best != null) {
                _openForm(best);
                return;
              }
              final geo = t.unmap(d.localPosition);
              for (final r in _regions) {
                if (r.contains(geo.$1, geo.$2)) {
                  setState(() =>
                      _filter = r.nameEn == _filter?.nameEn ? null : r);
                  return;
                }
              }
            },
            child: CustomPaint(
                size: size,
                painter: _TourMapPainter(
                    t, _regions, _list, activeWaterGeo(), _filter)),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              tooltip: 'Открыть карту (зум, регионы)',
              onPressed: _openBigMap,
              icon: const Icon(Icons.open_in_full, color: _gold, size: 20),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _row(Tournament t) {
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
            child: contentImage('tour_${t.id}', t.backdrop),
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
              _list.removeWhere((e) => e.id == t.id);
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
  late final String _id;
  late String _locId; // водоём-источник рыбы/зон для зачётной сессии
  late double _lon;
  late double _lat;
  bool _placed = false;
  RuRegion? _region;
  List<RuRegion> _regions = [];
  Rect? _bounds;

  Future<void> _loadRegions() async {
    final rs = await loadRuRegions();
    if (!mounted) return;
    setState(() {
      _regions = rs;
      _bounds = RussiaMapTransform.projectedBoundsOf(
          rs.expand((r) => r.rings).expand((ring) => ring));
      // Восстановить регион существующего турнира: по id или по точке.
      final t = widget.initial;
      if (t != null) {
        if (t.regionId.isNotEmpty) {
          _region = rs.where((r) => r.nameEn == t.regionId).firstOrNull;
        }
        _region ??= _placed ? _regionAt(_lon, _lat) : null;
      }
    });
  }

  RuRegion? _regionAt(double lon, double lat) {
    for (final r in _regions) {
      if (r.contains(lon, lat)) return r;
    }
    return null;
  }

  /// Ближайший к точке водоём внутри региона (источник рыбы). Если в регионе
  /// водоёмов нет — ближайший в целом.
  String _bindLocation(double lon, double lat) {
    final geo = activeWaterGeo();
    final locs = activeLocations();
    String? best;
    var bestD = double.infinity;
    String? bestAny;
    var bestAnyD = double.infinity;
    for (final l in locs) {
      final g = geo[l.id];
      if (g == null) continue;
      final d = (g.$1 - lon) * (g.$1 - lon) + (g.$2 - lat) * (g.$2 - lat);
      if (d < bestAnyD) {
        bestAnyD = d;
        bestAny = l.id;
      }
      if (_region != null && _region!.contains(g.$1, g.$2) && d < bestD) {
        bestD = d;
        best = l.id;
      }
    }
    return best ?? bestAny ?? _locId;
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
      _id = t.id;
      if (t.hasOwnPoint) {
        _lon = t.lon;
        _lat = t.lat;
        _placed = true;
      } else {
        final g = activeWaterGeo()[t.locationId];
        _lon = g?.$1 ?? 0;
        _lat = g?.$2 ?? 0;
        _placed = g != null;
      }
    } else {
      _c['stageCount']!.text = '1';
      _c['requiredLevel']!.text = '1';
      _c['durationSec']!.text = '150';
      _c['parGrams']!.text = '2000';
      _locId = activeLocations().first.id;
      _id = 'tour_${DateTime.now().millisecondsSinceEpoch}';
      _lon = 0;
      _lat = 0;
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
    Navigator.of(context).pop(Tournament(
      id: _id,
      title: _c['title']!.text.trim().isEmpty
          ? 'Новый турнир'
          : _c['title']!.text.trim(),
      dateRange: _c['dateRange']!.text.trim(),
      locationName: _region?.nameRu ?? loc.name,
      locationId: loc.id,
      backdrop: loc.primaryBackdrop,
      regionId: _region?.nameEn ?? '',
      lon: _placed ? _lon : 0,
      lat: _placed ? _lat : 0,
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
          const Divider(color: Colors.white12, height: 22),
          const Text('Место проведения: выбери регион → поставь точку',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _regionRow(),
          const SizedBox(height: 8),
          _venueMap(),
          _hintRow(),
          const SizedBox(height: 10),
          AdminImagePicker(
            key: ValueKey('tour_$_id'),
            imageKey: 'tour_$_id',
            asset: activeLocations()
                    .where((l) => l.id == _locId)
                    .map((l) => l.primaryBackdrop)
                    .firstOrNull ??
                '',
            label: 'Фото турнира (афиша)',
          ),
          const SizedBox(height: 10),
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

  Widget _regionRow() {
    return InputDecorator(
      decoration: _dec('Регион проведения'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RuRegion>(
          value: _region,
          isExpanded: true,
          // Компактное скролл-меню, чтобы не перекрывать карту/приложение.
          menuMaxHeight: 320,
          hint: const Text('Выбери регион…',
              style: TextStyle(color: Colors.white38)),
          dropdownColor: _panel,
          style: const TextStyle(color: Colors.white),
          items: [
            for (final r in _regions)
              DropdownMenuItem(value: r, child: Text(r.nameRu)),
          ],
          onChanged: (v) => setState(() {
            _region = v;
            // Точку сбрасываем, если она вне нового региона.
            if (_placed && v != null && !v.contains(_lon, _lat)) {
              _placed = false;
            }
          }),
        ),
      ),
    );
  }

  Widget _hintRow() {
    final where = _region == null
        ? 'Сначала выбери регион'
        : (_placed
            ? 'Точка: ${_lon.toStringAsFixed(2)}°, ${_lat.toStringAsFixed(2)}° · '
                'рыба как на «${activeLocations().where((l) => l.id == _locId).map((l) => l.name).firstOrNull ?? '—'}»'
            : 'Кликни внутри «${_region!.nameRu}»');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(where,
          style: const TextStyle(color: _gold, fontSize: 12)),
    );
  }

  /// Карта: границы регионов (выбранный подсвечен), водоёмы точками, красная
  /// точка турнира. Клик/перетаскивание внутри выбранного региона — ставит точку.
  Widget _venueMap() {
    if (_regions.isEmpty || _bounds == null) {
      return const SizedBox(
          height: 250, child: Center(child: CircularProgressIndicator()));
    }
    return Container(
      height: 250,
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
          onTapDown: (d) => _place(t, d.localPosition),
          onPanStart: (d) => _place(t, d.localPosition, drag: true),
          onPanUpdate: (d) => _place(t, d.localPosition, drag: true),
          child: CustomPaint(
            size: size,
            painter: _VenuePickPainter(t, _regions, activeLocations(),
                activeWaterGeo(), _region, _placed ? Offset(_lon, _lat) : null),
          ),
        );
      }),
    );
  }

  void _place(RussiaMapTransform t, Offset pos, {bool drag = false}) {
    if (_region == null) return;
    final geo = t.unmap(pos);
    if (!_region!.contains(geo.$1, geo.$2)) {
      if (!drag) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text('Точка вне «${_region!.nameRu}»'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 900)));
      }
      return;
    }
    setState(() {
      _lon = geo.$1;
      _lat = geo.$2;
      _placed = true;
      _locId = _bindLocation(_lon, _lat);
    });
  }

  Widget _locationPicker() {
    return InputDecorator(
      decoration: _dec('Рыба и зоны берутся с водоёма'),
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
  _TourMapPainter(this.t, this.regions, this.list, this.geo, this.sel);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<Tournament> list;
  final Map<String, (double, double)> geo;
  final RuRegion? sel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B1016));
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x2AFFFFFF);
    const red = Color(0xFFE5483B);
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
      final isSel = sel != null && r.nameEn == sel!.nameEn;
      canvas.drawPath(
          path,
          Paint()
            ..color = isSel ? const Color(0xFF33201C) : const Color(0xFF16221B));
      canvas.drawPath(
          path,
          isSel
              ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = red)
              : border);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final tt in list) {
      final g = tt.hasOwnPoint ? (tt.lon, tt.lat) : geo[tt.locationId];
      if (g == null) continue;
      final inSel = sel == null || sel!.contains(g.$1, g.$2);
      final p = t.map(g.$1, g.$2);
      final col = inSel ? red : red.withValues(alpha: 0.18);
      canvas.drawCircle(p, 6, Paint()..color = col.withValues(alpha: 0.25));
      canvas.drawCircle(p, 3.4, Paint()..color = col);
      canvas.drawCircle(
          p,
          3.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withValues(alpha: inSel ? 1 : 0.3));
      if (!inSel) continue;
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

/// Карта выбора места турнира: границы регионов (выбранный подсвечен),
/// водоёмы золотыми точками (для ориентира), красная точка турнира.
class _VenuePickPainter extends CustomPainter {
  _VenuePickPainter(
      this.t, this.regions, this.locs, this.geo, this.selected, this.point);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<FishingLocation> locs;
  final Map<String, (double, double)> geo;
  final RuRegion? selected;
  final Offset? point; // lon/lat выбранной точки

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
      final isSel = selected != null && r.nameEn == selected!.nameEn;
      canvas.drawPath(
          path,
          Paint()
            ..color = isSel
                ? const Color(0xFF33251C)
                : const Color(0xFF16221B));
      canvas.drawPath(
          path,
          isSel
              ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = const Color(0xFFE5483B))
              : border);
    }
    // Водоёмы — маленькие золотые точки (ориентир).
    for (final l in locs) {
      final g = geo[l.id];
      if (g == null) continue;
      final p = t.map(g.$1, g.$2);
      canvas.drawCircle(
          p, 2.2, Paint()..color = _gold.withValues(alpha: 0.7));
    }
    // Точка турнира — крупная красная.
    if (point != null) {
      final p = t.map(point!.dx, point!.dy);
      const red = Color(0xFFE5483B);
      canvas.drawCircle(p, 9, Paint()..color = red.withValues(alpha: 0.3));
      canvas.drawCircle(p, 5, Paint()..color = red);
      canvas.drawCircle(
          p,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _VenuePickPainter old) =>
      old.selected?.nameEn != selected?.nameEn || old.point != point;
}
