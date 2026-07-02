import 'package:flutter/material.dart' hide TimeOfDay;

import '../data/content_overrides.dart';
import '../data/seed/seed_content.dart';
import '../domain/entities/fish_species.dart';
import '../domain/value_objects/fishing_enums.dart';
import '../domain/value_objects/weight.dart';
import '../shared/content_images.dart';
import '../shared/rendering/fish_icons.dart';
import 'image_picker.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

String rarityRu(Rarity r) => switch (r) {
      Rarity.common => 'Обычная',
      Rarity.uncommon => 'Необычная',
      Rarity.rare => 'Редкая',
      Rarity.trophy => 'Трофейная',
      Rarity.legendary => 'Легендарная',
    };

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9AA4AD),
      Rarity.uncommon => const Color(0xFF6FBF73),
      Rarity.rare => const Color(0xFF5AA9E6),
      Rarity.trophy => const Color(0xFFB98CFF),
      Rarity.legendary => _gold,
    };

/// Редактор каталога рыб: создать/править/удалить вид, все характеристики и
/// профиль шансов клёва (наживки, время, погода, глубина, размер, цвет).
class SpeciesEditor extends StatefulWidget {
  const SpeciesEditor({super.key, required this.overrides});
  final ContentOverrides overrides;

  @override
  State<SpeciesEditor> createState() => _SpeciesEditorState();
}

class _SpeciesEditorState extends State<SpeciesEditor> {
  late List<FishSpecies> _list;
  bool _dirty = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _list = [...(widget.overrides.species() ?? SeedContent.species())];
  }

  Future<void> _openForm(FishSpecies? s) async {
    final res = await Navigator.of(context).push<FishSpecies>(
        MaterialPageRoute(builder: (_) => _SpeciesForm(initial: s)));
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
    widget.overrides.setSpecies(_list);
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() => _dirty = false);
    _toast('Сохранено · перезапусти игру');
  }

  Future<void> _resetSeed() async {
    widget.overrides.clearSpecies();
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() {
      _list = [...SeedContent.species()];
      _dirty = false;
    });
    _toast('Возврат к сид-каталогу рыб');
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel));

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _list
        : _list
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.group.toLowerCase().contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text('Рыбы · ${_list.length}',
            style: const TextStyle(color: _gold)),
        actions: [
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
        icon: const Icon(Icons.add),
        label: const Text('Вид'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Поиск по имени или семейству…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _row(filtered[i]),
          ),
        ),
      ]),
    );
  }

  Widget _row(FishSpecies s) {
    final rc = rarityColor(s.rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: () => _openForm(s),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 40,
              child: contentImage(
                'fish_${s.id}',
                'assets/fish/fish_${s.id}.png',
                fallback: (_) => ColoredBox(
                  color: const Color(0xFF0B1016),
                  child: Center(
                      child: FishIcon(s.id, discovered: true, size: 30)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: rc, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    '${s.group.isEmpty ? '—' : s.group} · ${rarityRu(s.rarity)} · '
                    '${(s.weightMin.grams / 1000).toStringAsFixed(1)}–'
                    '${(s.weightMax.grams / 1000).toStringAsFixed(1)} кг · '
                    '${s.baseSilver}с/${s.baseXp}xp',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Правка',
            onPressed: () => _openForm(s),
            icon: const Icon(Icons.edit, color: Colors.white54, size: 19),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => setState(() {
              _list.removeWhere((e) => e.id == s.id);
              _dirty = true;
            }),
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFE5726A), size: 19),
          ),
        ]),
      ),
    );
  }
}

// --- Форма вида ---------------------------------------------------------------

class _SpeciesForm extends StatefulWidget {
  const _SpeciesForm({this.initial});
  final FishSpecies? initial;

  @override
  State<_SpeciesForm> createState() => _SpeciesFormState();
}

class _SpeciesFormState extends State<_SpeciesForm> {
  late final String _id = widget.initial?.id ??
      'fish_${DateTime.now().millisecondsSinceEpoch}';
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _group = TextEditingController();
  final _family = TextEditingController();
  final _minKg = TextEditingController();
  final _maxKg = TextEditingController();
  final _silver = TextEditingController();
  final _xp = TextEditingController();
  Habitat _habitat = Habitat.fresh;
  Rarity _rarity = Rarity.common;

  // Профиль клёва — проценты по каждому ключу.
  late final Map<String, TextEditingController> _lure;
  late final Map<TimeOfDay, TextEditingController> _time;
  late final Map<Weather, TextEditingController> _weather;
  late final Map<DepthZone, TextEditingController> _depth;
  late final Map<LureSize, TextEditingController> _size;
  late final Map<LureColor, TextEditingController> _color;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final p = s?.biteProfile ?? BiteProfile.uniform();
    String pct(double v) => (v * 100).round().toString();
    _lure = {
      for (final l in LureType.all)
        l.code: TextEditingController(text: pct(p.lure(l.code))),
    };
    _time = {
      for (final t in TimeOfDay.values)
        t: TextEditingController(text: pct(p.time(t))),
    };
    _weather = {
      for (final w in Weather.values)
        w: TextEditingController(text: pct(p.weather(w))),
    };
    _depth = {
      for (final d in DepthZone.values)
        d: TextEditingController(text: pct(p.depth(d))),
    };
    _size = {
      for (final z in LureSize.values)
        z: TextEditingController(text: pct(p.size(z))),
    };
    _color = {
      for (final c in LureColor.values)
        c: TextEditingController(text: pct(p.colorFor(c))),
    };
    if (s != null) {
      _name.text = s.name;
      _desc.text = s.description;
      _group.text = s.group;
      _family.text = s.family;
      _minKg.text = (s.weightMin.grams / 1000).toStringAsFixed(2);
      _maxKg.text = (s.weightMax.grams / 1000).toStringAsFixed(2);
      _silver.text = '${s.baseSilver}';
      _xp.text = '${s.baseXp}';
      _habitat = s.habitat;
      _rarity = s.rarity;
    } else {
      _minKg.text = '0.10';
      _maxKg.text = '2.00';
      _silver.text = '12';
      _xp.text = '6';
      _family.text = 'мирная';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _desc, _group, _family, _minKg, _maxKg, _silver, _xp,
      ..._lure.values, ..._time.values, ..._weather.values,
      ..._depth.values, ..._size.values, ..._color.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _pct(TextEditingController c, double def) =>
      ((int.tryParse(c.text.trim()) ?? (def * 100).round()) / 100)
          .clamp(0.0, 1.0);

  void _save() {
    final minKg =
        double.tryParse(_minKg.text.trim().replaceAll(',', '.')) ?? 0.1;
    final maxKg =
        double.tryParse(_maxKg.text.trim().replaceAll(',', '.')) ?? 1.0;
    final profile = BiteProfile(
      lureTypeWeights: {
        for (final e in _lure.entries) e.key: _pct(e.value, 0.3)
      },
      timeWeights: {
        for (final e in _time.entries) e.key: _pct(e.value, 0.25)
      },
      weatherWeights: {
        for (final e in _weather.entries) e.key: _pct(e.value, 1 / 3)
      },
      depthWeights: {
        for (final e in _depth.entries) e.key: _pct(e.value, 0.25)
      },
      sizeWeights: {
        for (final e in _size.entries) e.key: _pct(e.value, 1 / 3)
      },
      colorWeights: {
        for (final e in _color.entries) e.key: _pct(e.value, 0.5)
      },
    );
    Navigator.of(context).pop(FishSpecies(
      id: _id,
      name: _name.text.trim().isEmpty ? 'Новый вид' : _name.text.trim(),
      description: _desc.text.trim(),
      family: _family.text.trim().isEmpty ? 'мирная' : _family.text.trim(),
      group: _group.text.trim(),
      habitat: _habitat,
      rarity: _rarity,
      weightMin: Weight.kilograms(minKg),
      weightMax: Weight.kilograms(maxKg < minKg ? minKg : maxKg),
      baseSilver: int.tryParse(_silver.text.trim()) ?? 10,
      baseXp: int.tryParse(_xp.text.trim()) ?? 5,
      biteProfile: profile,
      photoAsset: widget.initial?.photoAsset,
      special: widget.initial?.special ?? false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final groups = SeedContent.kFishGroups.values.toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(widget.initial == null ? 'Новый вид' : 'Правка вида',
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
          AdminImagePicker(
            imageKey: 'fish_$_id',
            asset: 'assets/fish/fish_$_id.png',
            label: 'Фото вида (бестиарий и карточка улова)',
            fallback: (_) => ColoredBox(
              color: const Color(0xFF0B1016),
              child:
                  Center(child: FishIcon(_id, discovered: true, size: 60)),
            ),
          ),
          const SizedBox(height: 12),
          _text(_name, 'Название'),
          _text(_desc, 'Описание (видно в бестиарии)', lines: 3),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 260, child: _text(_group, 'Семейство (биол.)',
                pad: false)),
            SizedBox(
                width: 220,
                child: _text(_family, 'Роль: хищник/мирная/донная/морская',
                    pad: false)),
          ]),
          const SizedBox(height: 6),
          Text('Семейства в игре: ${groups.join(', ')}',
              style: const TextStyle(color: Colors.white24, fontSize: 10.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _dropdown<Habitat>('Вода', _habitat, Habitat.values, (h) {
              setState(() => _habitat = h);
            }, (h) => switch (h) {
              Habitat.fresh => 'Пресная',
              Habitat.salt => 'Морская',
              Habitat.brackish => 'Солоноватая',
            }),
            _dropdown<Rarity>('Редкость', _rarity, Rarity.values, (r) {
              setState(() => _rarity = r);
            }, rarityRu),
            _num(_minKg, 'Вес мин, кг'),
            _num(_maxKg, 'Вес макс, кг'),
            _num(_silver, 'Серебро за шт.'),
            _num(_xp, 'Опыт за шт.'),
          ]),
          const SizedBox(height: 16),
          const Text('Шансы клёва (в %, влияют на алгоритм поклёвки)',
              style: TextStyle(
                  color: _gold, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          _pctSection('Наживки и приманки', {
            for (final l in LureType.all) l.label: _lure[l.code]!,
          }),
          _pctSection('Время суток', {
            'Утро': _time[TimeOfDay.morning]!,
            'День': _time[TimeOfDay.day]!,
            'Вечер': _time[TimeOfDay.evening]!,
            'Ночь': _time[TimeOfDay.night]!,
          }),
          _pctSection('Погода', {
            'Ясно': _weather[Weather.clear]!,
            'Пасмурно': _weather[Weather.cloudy]!,
            'Дождь': _weather[Weather.rain]!,
          }),
          _pctSection('Глубина', {
            'Мелко': _depth[DepthZone.shallow]!,
            'Средне': _depth[DepthZone.mid]!,
            'Свал': _depth[DepthZone.dropOff]!,
            'Яма': _depth[DepthZone.pit]!,
          }),
          _pctSection('Размер приманки', {
            'Мелкая': _size[LureSize.small]!,
            'Средняя': _size[LureSize.medium]!,
            'Крупная': _size[LureSize.large]!,
          }),
          _pctSection('Цвет приманки', {
            'Яркая': _color[LureColor.bright]!,
            'Натуральная': _color[LureColor.natural]!,
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _pctSection(String title, Map<String, TextEditingController> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final e in rows.entries)
              SizedBox(
                width: 120,
                child: TextField(
                  controller: e.value,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: e.key,
                    suffixText: '%',
                    isDense: true,
                    labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12))),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _gold)),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, List<T> values,
      ValueChanged<T> onChanged, String Function(T) labelOf) {
    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: _dec(label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: _panel,
            style: const TextStyle(color: Colors.white),
            items: [
              for (final v in values)
                DropdownMenuItem(value: v, child: Text(labelOf(v))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _text(TextEditingController c, String label,
      {int lines = 1, bool pad = true}) {
    final field = TextField(
      controller: c,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: _dec(label),
    );
    return pad
        ? Padding(padding: const EdgeInsets.only(bottom: 12), child: field)
        : field;
  }

  Widget _num(TextEditingController c, String label) => SizedBox(
        width: 160,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _dec(label),
        ),
      );

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
