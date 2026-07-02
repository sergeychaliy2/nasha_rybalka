import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../data/seed/seed_content.dart';
import '../domain/entities/fishing_location.dart';
import '../domain/value_objects/currency.dart';
import '../domain/value_objects/weight.dart';
import '../features/fishing/water_masks.dart';
import '../features/map/region_store.dart';
import '../features/map/russia_geo.dart';
import '../shared/content_images.dart';
import 'image_picker.dart';
import 'map_view.dart';
import 'zone_editor.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);
const _shapes = ['flat', 'dropOff', 'pit', 'ridge'];

/// Редактор локаций: создать на карте (клик → координаты), править описание,
/// фон, глубину, зарыбление. Полный список + координаты — в оверрайды.
class LocationsEditor extends StatefulWidget {
  const LocationsEditor({super.key, required this.overrides});
  final ContentOverrides overrides;

  @override
  State<LocationsEditor> createState() => _LocationsEditorState();
}

class _LocationsEditorState extends State<LocationsEditor> {
  late List<FishingLocation> _list;
  late Map<String, (double, double)> _geo;
  bool _dirty = false;
  List<RuRegion> _regions = [];
  Rect? _bounds;

  @override
  void initState() {
    super.initState();
    _list = [...(widget.overrides.locations() ?? SeedContent.locations)];
    _geo = {...activeWaterGeo()};
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

  Future<void> _openForm(FishingLocation? loc) async {
    final res =
        await Navigator.of(context).push<(FishingLocation, (double, double))>(
      MaterialPageRoute(
          builder: (_) => _LocForm(
              overrides: widget.overrides,
              initial: loc,
              geo: loc == null ? null : _geo[loc.id])),
    );
    if (res == null) return;
    final (l, geo) = res;
    setState(() {
      final i = _list.indexWhere((e) => e.id == l.id);
      if (i >= 0) {
        _list[i] = l;
      } else {
        _list.add(l);
      }
      _geo[l.id] = geo;
      _dirty = true;
    });
  }

  Future<void> _saveAll() async {
    widget.overrides.setLocations(_list);
    for (final l in _list) {
      final g = _geo[l.id];
      if (g != null) widget.overrides.setWaterGeo(l.id, g.$1, g.$2);
    }
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() => _dirty = false);
    _toast('Сохранено · перезапусти игру');
  }

  Future<void> _resetSeed() async {
    widget.overrides.clearLocations();
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() {
      _list = [...SeedContent.locations];
      _geo = {...kWaterGeo};
      _dirty = false;
    });
    _toast('Возврат к сид-локациям');
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
        title: const Text('Локации', style: TextStyle(color: _gold)),
        actions: [
          IconButton(
            tooltip: 'Открыть карту',
            onPressed: _openBigMap,
            icon: const Icon(Icons.public, color: _gold),
          ),
          TextButton(
              onPressed: _resetSeed,
              child:
                  const Text('К сиду', style: TextStyle(color: Colors.white54))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _dirty ? _saveAll : null,
              icon: const Icon(Icons.save, size: 18, color: Colors.black),
              label:
                  const Text('Сохранить', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Локация'),
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

  /// Обзорная карта: все водоёмы точками; тап по точке — открыть на правку.
  Widget _overview() {
    if (_regions.isEmpty || _bounds == null) {
      return const SizedBox(
          height: 250, child: Center(child: CircularProgressIndicator()));
    }
    return Container(
      height: 250,
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
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            FishingLocation? best;
            var bestD = 20.0;
            for (final l in _list) {
              final g = _geo[l.id];
              if (g == null) continue;
              final dd = (t.map(g.$1, g.$2) - d.localPosition).distance;
              if (dd < bestD) {
                bestD = dd;
                best = l;
              }
            }
            if (best != null) _openForm(best);
          },
          child: CustomPaint(
              size: size, painter: _OverviewPainter(t, _regions, _list, _geo)),
        );
      }),
    );
  }

  Widget _row(FishingLocation l, int i) {
    final g = _geo[l.id];
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openForm(l),
        child: Row(children: [
          SizedBox(
            width: 96,
            height: 70,
            child: contentImage(
                assetStem(l.primaryBackdrop), l.primaryBackdrop),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    '${l.species.length} видов · дно ${l.depthProfile.maxDepthMeters}м'
                    '${g != null ? ' · ${g.$1.toStringAsFixed(1)},${g.$2.toStringAsFixed(1)}' : ''}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Правка',
            onPressed: () => _openForm(l),
            icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
          ),
          IconButton(
            tooltip: 'Зоны заброса',
            onPressed: () => _openZones(l),
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

  void _openZones(FishingLocation l) {
    final stem = l.primaryBackdrop.split('/').last.replaceAll('.png', '');
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ZoneEditor(overrides: widget.overrides, initialStem: stem)));
  }

  void _openBigMap() {
    if (_bounds == null) return;
    final pins = <MapPin>[
      for (final l in _list)
        if (_geo[l.id] != null)
          (id: l.id, label: l.name, lon: _geo[l.id]!.$1, lat: _geo[l.id]!.$2),
    ];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminMapView(
        title: 'Карта локаций',
        regions: _regions,
        bounds: _bounds!,
        pins: pins,
        onTapPin: (id) {
          Navigator.of(context).pop();
          final l = _list.where((e) => e.id == id).firstOrNull;
          if (l != null) _openForm(l);
        },
      ),
    ));
  }
}

class _LocForm extends StatefulWidget {
  const _LocForm({required this.overrides, this.initial, this.geo});
  final ContentOverrides overrides;
  final FishingLocation? initial;
  final (double, double)? geo;

  @override
  State<_LocForm> createState() => _LocFormState();
}

class _LocFormState extends State<_LocForm> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _maxDepth = TextEditingController();
  final _entrySilver = TextEditingController();
  final _morning = TextEditingController();
  String _shape = 'flat';
  String _country = 'ru';
  String _backdrop = '';
  double _lon = 90, _lat = 60;
  bool _placed = false; // поставлена ли точка
  List<RuRegion> _regions = [];
  RuRegion? _region; // выбранный регион (точку ставим только в нём)
  Rect? _bounds; // спроецированные границы всех регионов (для карты)
  late List<SpeciesSpawn> _spawns;
  late final List<String> _backdrops;
  final Map<String, String> _groupById = {
    for (final s in SeedContent.species()) s.id: s.group
  };
  final Map<String, String> _nameById = {
    for (final s in SeedContent.species()) s.id: s.name
  };

  Future<void> _loadRegions() async {
    final rs = await loadRuRegions();
    if (!mounted) return;
    setState(() {
      _regions = rs;
      _bounds = RussiaMapTransform.projectedBoundsOf(
          rs.expand((r) => r.rings).expand((ring) => ring));
      // Для правки — автовыбор региона под текущей точкой.
      if (_placed) {
        _region = rs.where((r) => r.contains(_lon, _lat)).firstOrNull ?? _region;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadRegions();
    // Все доступные фоны — из фонов существующих локаций (уникальные).
    final set = <String>{};
    for (final l in SeedContent.locations) {
      set.addAll(l.backdropAssets);
    }
    _backdrops = set.toList()..sort();
    final t = widget.initial;
    if (t != null) {
      _name.text = t.name;
      _desc.text = t.description;
      _maxDepth.text = '${t.depthProfile.maxDepthMeters}';
      _entrySilver.text = '${t.entryCost.amount}';
      _morning.text = '${t.morningBonusMinutes}';
      _shape = _shapes.contains(t.depthProfile.shape) ? t.depthProfile.shape : 'flat';
      _country = t.countryId;
      _backdrop = t.primaryBackdrop;
      _spawns = [...t.species];
      if (widget.geo != null) {
        _lon = widget.geo!.$1;
        _lat = widget.geo!.$2;
        _placed = true;
      }
    } else {
      _maxDepth.text = '10';
      _entrySilver.text = '0';
      _morning.text = '0';
      _backdrop = _backdrops.isNotEmpty ? _backdrops.first : '';
      _spawns = [];
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _maxDepth, _entrySilver, _morning]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c, int d) => int.tryParse(c.text.trim()) ?? d;

  Widget _regionRow() {
    final sorted = _regions.toList()
      ..sort((a, b) => a.nameRu.compareTo(b.nameRu));
    return InputDecorator(
      decoration: _dec('Регион (сначала выбери, потом ставь точку)'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RuRegion>(
          value: _region,
          isExpanded: true,
          hint: const Text('— выбери регион —',
              style: TextStyle(color: Colors.white38)),
          dropdownColor: _panel,
          style: const TextStyle(color: Colors.white),
          items: [
            for (final r in sorted)
              DropdownMenuItem(value: r, child: Text(r.nameRu)),
          ],
          onChanged: (v) => setState(() => _region = v),
        ),
      ),
    );
  }

  Widget _mapArea() {
    if (_regions.isEmpty || _bounds == null) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1016),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _MapPicker(
        regions: _regions,
        selected: _region,
        bounds: _bounds!,
        lon: _lon,
        lat: _lat,
        hasPoint: _placed,
        onPick: (lo, la) => setState(() {
          _lon = lo;
          _lat = la;
          _placed = true;
        }),
        onOutside: () => ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(_region == null
                ? 'Сначала выбери регион, потом ставь точку'
                : 'Точка вне региона «${_region!.nameRu}» — ставь внутри границ'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _panel)),
      ),
    );
  }

  Widget _hintRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        _placed
            ? 'Точка: ${_lon.toStringAsFixed(2)}°, ${_lat.toStringAsFixed(2)}°'
                '${_region != null ? ' · ${_region!.nameRu}' : ''}'
            : (_region == null
                ? 'Выбери регион, затем кликни внутри его границ'
                : 'Кликни внутри «${_region!.nameRu}»'),
        style: const TextStyle(color: _gold, fontSize: 12),
      ),
    );
  }

  Widget _zoneButton() {
    final stem = _backdrop.split('/').last.replaceAll('.png', '');
    final has = kWaterMasks.containsKey(stem);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ZoneEditor(overrides: widget.overrides, initialStem: stem))),
        icon: const Icon(Icons.brush, size: 18, color: Color(0xFF56C271)),
        label: Text(
            has
                ? 'Настроить зоны заброса этой локации'
                : 'Зоны заброса (нет маски для этого фона)',
            style: const TextStyle(color: Color(0xFF56C271))),
      ),
    );
  }

  Widget _familiesLine() {
    if (_spawns.isEmpty) return const SizedBox.shrink();
    final fams = _spawns
        .map((s) => _groupById[s.speciesId] ?? '')
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (fams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text('Семейства (видно игроку): ${fams.join(', ')}',
          style: const TextStyle(color: Color(0xFF7FB3D5), fontSize: 12)),
    );
  }

  void _save() {
    if (!_placed) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Поставь точку на карте (выбери регион и кликни внутри)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _panel));
      return;
    }
    final id = widget.initial?.id ??
        'loc_${DateTime.now().millisecondsSinceEpoch}';
    final loc = FishingLocation(
      id: id,
      name: _name.text.trim().isEmpty ? 'Новый водоём' : _name.text.trim(),
      description: _desc.text.trim(),
      countryId: _country,
      entryCost: Money.silver(_int(_entrySilver, 0)),
      depthProfile: DepthProfile(
        seed: widget.initial?.depthProfile.seed ??
            (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
        maxDepthMeters: _int(_maxDepth, 10),
        shape: _shape,
      ),
      species: _spawns,
      trash: widget.initial?.trash ?? const [],
      backdropAssets: [_backdrop],
      morningBonusMinutes: _int(_morning, 0),
      requiredVehicleTier: widget.initial?.requiredVehicleTier ?? 0,
    );
    Navigator.of(context).pop((loc, (_lon, _lat)));
  }

  Future<void> _editSpawn(SpeciesSpawn? s) async {
    final res = await showDialog<SpeciesSpawn>(
        context: context, builder: (_) => _SpawnDialog(initial: s));
    if (res == null) return;
    setState(() {
      final i = _spawns.indexWhere((e) => e.speciesId == res.speciesId);
      if (i >= 0) {
        _spawns[i] = res;
      } else {
        _spawns.add(res);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(widget.initial == null ? 'Новый водоём' : 'Правка водоёма',
            style: const TextStyle(color: _gold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18, color: Colors.black),
              label: const Text('Готово', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Информация о водоёме',
              style: TextStyle(
                  color: _gold, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _text(_name, 'Название'),
          _text(_desc, 'Описание (видит игрок в «О месте» и на карте)',
              lines: 3),
          const Divider(color: Colors.white12, height: 22),
          const Text('Место на карте: выбери регион → поставь точку',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _regionRow(),
          const SizedBox(height: 8),
          _mapArea(),
          _hintRow(),
          const SizedBox(height: 4),
          _zoneButton(),
          const Divider(color: Colors.white12, height: 22),
          AdminImagePicker(
            key: ValueKey('bg_$_backdrop'),
            imageKey: assetStem(_backdrop),
            asset: _backdrop,
            label: 'Фон локации (сцена ловли и карточки)',
          ),
          const SizedBox(height: 12),
          _drop('Страна/регион', _country, {
            for (final c in SeedContent.countries) c.id: c.name,
          }, (v) => setState(() => _country = v)),
          const SizedBox(height: 12),
          _dropBackdrop(),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _num(_maxDepth, 'Макс. глубина, м'),
            _num(_entrySilver, 'Вход, серебро'),
            _num(_morning, 'Утр. бонус, мин'),
          ]),
          const SizedBox(height: 12),
          _drop('Форма дна', _shape, {for (final s in _shapes) s: s},
              (v) => setState(() => _shape = v)),
          const SizedBox(height: 18),
          Row(children: [
            const Text('Зарыбление',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _editSpawn(null),
              icon: const Icon(Icons.add, color: _gold, size: 18),
              label: const Text('Вид', style: TextStyle(color: _gold)),
            ),
          ]),
          const Text('Реально водятся и клюют (для админа). Игрок увидит виды и '
              'семейства ниже.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          _familiesLine(),
          for (final s in _spawns) _spawnRow(s),
          if (_spawns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Нет видов — добавь через «Вид».',
                  style: TextStyle(color: Colors.white38, fontSize: 12.5)),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _spawnRow(SpeciesSpawn s) {
    final name = _nameById[s.speciesId] ?? s.speciesId;
    return Card(
      color: _panel,
      child: ListTile(
        title: Text(name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
            'уд ${(s.floatChance * 100).round()}% · сп ${(s.spinningChance * 100).round()}% · '
            '${(s.weightMin.grams / 1000).toStringAsFixed(1)}–${(s.weightMax.grams / 1000).toStringAsFixed(1)} кг',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              onPressed: () => _editSpawn(s),
              icon: const Icon(Icons.edit, color: Colors.white54, size: 18)),
          IconButton(
              onPressed: () =>
                  setState(() => _spawns.removeWhere((e) => e.speciesId == s.speciesId)),
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFE5726A), size: 18)),
        ]),
      ),
    );
  }

  Widget _text(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          style: const TextStyle(color: Colors.white),
          decoration: _dec(label),
        ),
      );

  Widget _num(TextEditingController c, String label) => SizedBox(
        width: 180,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _dec(label),
        ),
      );

  Widget _drop(String label, String value, Map<String, String> opts,
      ValueChanged<String> onChanged) {
    final safe = opts.containsKey(value)
        ? value
        : (opts.keys.isNotEmpty ? opts.keys.first : value);
    return InputDecorator(
      decoration: _dec(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safe,
          isExpanded: true,
          dropdownColor: _panel,
          style: const TextStyle(color: Colors.white),
          items: [
            for (final e in opts.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => onChanged(v ?? safe),
        ),
      ),
    );
  }

  Widget _dropBackdrop() {
    final safe = _backdrops.contains(_backdrop)
        ? _backdrop
        : (_backdrops.isNotEmpty ? _backdrops.first : '');
    return InputDecorator(
      decoration: _dec('Фон локации'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safe,
          isExpanded: true,
          dropdownColor: _panel,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: [
            for (final b in _backdrops)
              DropdownMenuItem(
                  value: b, child: Text(b.split('/').last)),
          ],
          onChanged: (v) => setState(() => _backdrop = v ?? safe),
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

// --- Диалог зарыбления одного вида ------------------------------------------

class _SpawnDialog extends StatefulWidget {
  const _SpawnDialog({this.initial});
  final SpeciesSpawn? initial;

  @override
  State<_SpawnDialog> createState() => _SpawnDialogState();
}

class _SpawnDialogState extends State<_SpawnDialog> {
  late String _sp;
  final _float = TextEditingController();
  final _spin = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _sp = s?.speciesId ?? SeedContent.species().first.id;
    _float.text = ((s?.floatChance ?? 0.3) * 100).round().toString();
    _spin.text = ((s?.spinningChance ?? 0.3) * 100).round().toString();
    _min.text = ((s?.weightMin.grams ?? 100) / 1000).toStringAsFixed(2);
    _max.text = ((s?.weightMax.grams ?? 1000) / 1000).toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final c in [_float, _spin, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text('Вид на локации', style: TextStyle(color: _gold)),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButton<String>(
            value: _sp,
            isExpanded: true,
            dropdownColor: _panel,
            style: const TextStyle(color: Colors.white),
            items: [
              for (final s in SeedContent.species())
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _sp = v ?? _sp),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _f(_float, 'Шанс уд., %')),
            const SizedBox(width: 8),
            Expanded(child: _f(_spin, 'Шанс сп., %')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _f(_min, 'Вес мин, кг')),
            const SizedBox(width: 8),
            Expanded(child: _f(_max, 'Вес макс, кг')),
          ]),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _gold),
          onPressed: () {
            final minKg = double.tryParse(_min.text.trim().replaceAll(',', '.')) ?? 0.1;
            final maxKg = double.tryParse(_max.text.trim().replaceAll(',', '.')) ?? 1.0;
            Navigator.pop(
              context,
              SpeciesSpawn(
                speciesId: _sp,
                weightMin: Weight.kilograms(minKg),
                weightMax: Weight.kilograms(maxKg < minKg ? minKg : maxKg),
                floatChance:
                    ((int.tryParse(_float.text.trim()) ?? 30) / 100).clamp(0.0, 1.0),
                spinningChance:
                    ((int.tryParse(_spin.text.trim()) ?? 30) / 100).clamp(0.0, 1.0),
              ),
            );
          },
          child: const Text('OK', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _f(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          isDense: true,
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        ),
      );
}

// --- Карта-указатель --------------------------------------------------------

class _MapPicker extends StatelessWidget {
  const _MapPicker({
    required this.regions,
    required this.selected,
    required this.bounds,
    required this.lon,
    required this.lat,
    required this.hasPoint,
    required this.onPick,
    required this.onOutside,
  });
  final List<RuRegion> regions;
  final RuRegion? selected;
  final Rect bounds;
  final double lon, lat;
  final bool hasPoint;
  final void Function(double, double) onPick;
  final VoidCallback onOutside;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.9,
      child: LayoutBuilder(builder: (ctx, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final t = RussiaMapTransform.fitRaw(bounds, size, paddingFrac: 0.02);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handle(t, d.localPosition, tap: true),
          onPanStart: (d) => _handle(t, d.localPosition),
          onPanUpdate: (d) => _handle(t, d.localPosition),
          child: CustomPaint(
            size: size,
            painter:
                _MapPickPainter(t, regions, selected, lon, lat, hasPoint),
          ),
        );
      }),
    );
  }

  // Тап ставит точку (мимо региона — подсказка); удержание+перетаскивание
  // двигает её, оставаясь внутри выбранного региона.
  void _handle(RussiaMapTransform t, Offset pos, {bool tap = false}) {
    final (lo, la) = t.unmap(pos);
    if (selected != null && selected!.contains(lo, la)) {
      onPick(lo, la);
    } else if (tap) {
      onOutside();
    }
  }
}

class _MapPickPainter extends CustomPainter {
  _MapPickPainter(
      this.t, this.regions, this.selected, this.lon, this.lat, this.hasPoint);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final RuRegion? selected;
  final double lon, lat;
  final bool hasPoint;

  Path _regionPath(RuRegion r) {
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
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B1016));
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x33FFFFFF);
    for (final r in regions) {
      if (identical(r, selected)) continue;
      final path = _regionPath(r);
      canvas.drawPath(path, Paint()..color = const Color(0xFF17231C));
      canvas.drawPath(path, border);
    }
    // Выбранный регион — подсвечен и обведён золотом (как в игре).
    if (selected != null) {
      final path = _regionPath(selected!);
      canvas.drawPath(path, Paint()..color = const Color(0xFF264134));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = _gold);
    }
    // Существующие водоёмы.
    for (final e in activeWaterGeo().entries) {
      final p = t.map(e.value.$1, e.value.$2);
      canvas.drawCircle(p, 2.2, Paint()..color = const Color(0xFF5AA9E6));
    }
    // Текущая точка.
    if (hasPoint) {
      final cur = t.map(lon, lat);
      canvas.drawCircle(cur, 8, Paint()..color = _gold.withValues(alpha: 0.3));
      canvas.drawCircle(cur, 4, Paint()..color = _gold);
      canvas.drawCircle(
          cur,
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPickPainter old) =>
      old.lon != lon ||
      old.lat != lat ||
      !identical(old.selected, selected) ||
      old.hasPoint != hasPoint;
}

class _OverviewPainter extends CustomPainter {
  _OverviewPainter(this.t, this.regions, this.list, this.geo);
  final RussiaMapTransform t;
  final List<RuRegion> regions;
  final List<FishingLocation> list;
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
    for (final l in list) {
      final g = geo[l.id];
      if (g == null) continue;
      final p = t.map(g.$1, g.$2);
      canvas.drawCircle(p, 6, Paint()..color = _gold.withValues(alpha: 0.25));
      canvas.drawCircle(p, 3.2, Paint()..color = _gold);
      canvas.drawCircle(
          p,
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black);
      tp.text = TextSpan(
          text: l.name,
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
  bool shouldRepaint(covariant _OverviewPainter old) => true;
}
