import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../data/seed/seed_content.dart';
import '../domain/entities/gear.dart';
import '../domain/value_objects/currency.dart';
import '../domain/value_objects/fishing_enums.dart';
import '../domain/value_objects/weight.dart';
import '../features/shop/gear_detail.dart' show capabilityInfo;
import '../shared/content_images.dart';
import '../shared/rendering/gear_icons.dart';
import 'image_picker.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

String gearCategoryRu(GearCategory c) => switch (c) {
      GearCategory.rod => 'Удилища',
      GearCategory.spinningRod => 'Спиннинги',
      GearCategory.floatReel => 'Катушки (уд.)',
      GearCategory.spinningReel => 'Катушки (сп.)',
      GearCategory.line => 'Леска',
      GearCategory.braid => 'Шнур',
      GearCategory.hook => 'Крючки',
      GearCategory.bait => 'Наживки',
      GearCategory.lure => 'Приманки',
      GearCategory.echoSounder => 'Эхолоты',
      GearCategory.groundbait => 'Прикормка',
      GearCategory.spray => 'Спреи',
      GearCategory.energy => 'Энергия',
      GearCategory.premium => 'Премиум',
    };

String gearRarityRu(GearRarity r) => switch (r) {
      GearRarity.common => 'Базовый',
      GearRarity.uncommon => 'Любительский',
      GearRarity.rare => 'Спортивный',
      GearRarity.epic => 'Профессиональный',
      GearRarity.legendary => 'Турнирный',
    };

const _consumables = [
  GearCategory.bait,
  GearCategory.lure,
  GearCategory.groundbait,
  GearCategory.spray,
  GearCategory.energy,
];

/// Светлый подиум с векторной иконкой — фолбэк, когда фото предмета нет.
Widget _iconPodium(GearItem g, double size) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9E4D8), Color(0xFFC9C2B2)],
        ),
      ),
      child: Center(child: GearIcon(g.category, size: size)),
    );

/// Редактор каталога магазина: все предметы всех категорий (или только
/// продукты-расходники), полный CRUD, цены/уровни/редкость/характеристики.
class GearEditor extends StatefulWidget {
  const GearEditor(
      {super.key, required this.overrides, this.consumablesOnly = false});
  final ContentOverrides overrides;
  final bool consumablesOnly;

  @override
  State<GearEditor> createState() => _GearEditorState();
}

class _GearEditorState extends State<GearEditor> {
  late List<GearItem> _list;
  late GearCategory _cat;
  bool _dirty = false;

  List<GearCategory> get _cats =>
      widget.consumablesOnly ? _consumables : GearCategory.values;

  @override
  void initState() {
    super.initState();
    _list = [...(widget.overrides.gear() ?? SeedContent.gear)];
    _cat = _cats.first;
  }

  Future<void> _openForm(GearItem? g) async {
    final res = await Navigator.of(context).push<GearItem>(MaterialPageRoute(
        builder: (_) => _GearForm(initial: g, category: g?.category ?? _cat)));
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
    widget.overrides.setGear(_list);
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() => _dirty = false);
    _toast('Сохранено · перезапусти игру');
  }

  Future<void> _resetSeed() async {
    widget.overrides.clearGear();
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() {
      _list = [...SeedContent.gear];
      _dirty = false;
    });
    _toast('Возврат к сид-каталогу');
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel));

  @override
  Widget build(BuildContext context) {
    final items = _list.where((g) => g.category == _cat).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(
            widget.consumablesOnly ? 'Продукты и прикормки' : 'Магазин и снасти',
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
        label: Text(gearCategoryRu(_cat)),
      ),
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in _cats)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: ChoiceChip(
                    label: Text(
                        '${gearCategoryRu(c)} · ${_list.where((g) => g.category == c).length}'),
                    selected: c == _cat,
                    selectedColor: _gold.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                        color: c == _cat ? _gold : Colors.white70,
                        fontSize: 12),
                    onSelected: (_) => setState(() => _cat = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _row(items[i]),
          ),
        ),
      ]),
    );
  }

  String _statLine(GearItem g) => switch (g) {
        RodItem(:final maxWeight) =>
          'до ${(maxWeight.grams / 1000).toStringAsFixed(0)} кг',
        ReelItem(:final maxWeight, :final smoothness) =>
          'до ${(maxWeight.grams / 1000).toStringAsFixed(0)} кг · мягкость ${(smoothness * 100).round()}%',
        LineItem(:final maxWeight, :final lengthMeters) =>
          '${(maxWeight.grams / 1000).toStringAsFixed(0)} кг · $lengthMeters м',
        HookItem(:final escapeChance) =>
          'сход ${(escapeChance * 100).round()}%',
        LureItem(:final lureType, :final targetGroups) => targetGroups.isEmpty
            ? lureType.label
            : '${lureType.label} · ${targetGroups.join('/')}',
        EchoSounderItem(:final rangeMeters, :final capabilities) =>
          'до $rangeMeters м · ${capabilities.length} функц.',
        PremiumItem(:final days, :final tier) => '$days дн · ур. $tier',
      };

  Widget _row(GearItem g) {
    final priceIcon = g.price.type == CurrencyType.gold ? '💎' : '🪙';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        onTap: () => _openForm(g),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 40,
              child: contentImage(
                'item_${g.id}',
                'assets/art/items/${g.id}.png',
                fallback: (_) => _iconPodium(g, 30),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    '${gearRarityRu(g.rarity)} · ур.${g.requiredLevel} · '
                    '$priceIcon${g.price.amount} · ${_statLine(g)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Правка',
            onPressed: () => _openForm(g),
            icon: const Icon(Icons.edit, color: Colors.white54, size: 19),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => setState(() {
              _list.removeWhere((e) => e.id == g.id);
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

// --- Форма предмета -------------------------------------------------------------

class _GearForm extends StatefulWidget {
  const _GearForm({this.initial, required this.category});
  final GearItem? initial;
  final GearCategory category;

  @override
  State<_GearForm> createState() => _GearFormState();
}

class _GearFormState extends State<_GearForm> {
  late final String _id = widget.initial?.id ??
      'item_${DateTime.now().millisecondsSinceEpoch}';
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _level = TextEditingController();
  CurrencyType _currency = CurrencyType.silver;
  GearRarity _rarity = GearRarity.common;

  // Типоспецифичные поля.
  final _maxKg = TextEditingController();
  final _smooth = TextEditingController();
  final _length = TextEditingController();
  final _escape = TextEditingController();
  final _chum = TextEditingController();
  final _range = TextEditingController();
  final _days = TextEditingController();
  final _tier = TextEditingController();
  LureType _lureType = LureType.worm;
  LureSize _lureSize = LureSize.medium;
  LureColor _lureColor = LureColor.natural;
  final Set<String> _targetGroups = {};
  final Set<SounderCapability> _caps = {};

  GearCategory get _cat => widget.category;

  bool get _isRod =>
      _cat == GearCategory.rod || _cat == GearCategory.spinningRod;
  bool get _isReel =>
      _cat == GearCategory.floatReel || _cat == GearCategory.spinningReel;
  bool get _isLine => _cat == GearCategory.line || _cat == GearCategory.braid;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    _level.text = '${g?.requiredLevel ?? 1}';
    _price.text = '${g?.price.amount ?? 100}';
    _maxKg.text = '3';
    _smooth.text = '50';
    _length.text = '100';
    _escape.text = '15';
    _chum.text = '45';
    _range.text = '10';
    _days.text = '7';
    _tier.text = '1';
    if (g != null) {
      _name.text = g.name;
      _desc.text = g.description;
      _currency = g.price.type;
      _rarity = g.rarity;
      switch (g) {
        case RodItem(:final maxWeight):
          _maxKg.text = (maxWeight.grams / 1000).toStringAsFixed(1);
        case ReelItem(:final maxWeight, :final smoothness):
          _maxKg.text = (maxWeight.grams / 1000).toStringAsFixed(1);
          _smooth.text = '${(smoothness * 100).round()}';
        case LineItem(:final maxWeight, :final lengthMeters):
          _maxKg.text = (maxWeight.grams / 1000).toStringAsFixed(1);
          _length.text = '$lengthMeters';
        case HookItem(:final escapeChance):
          _escape.text = '${(escapeChance * 100).round()}';
        case LureItem(
            :final lureType,
            :final size,
            :final color,
            :final targetGroups,
            :final chumSeconds
          ):
          _lureType = lureType;
          _lureSize = size;
          _lureColor = color;
          _targetGroups.addAll(targetGroups);
          _chum.text = '$chumSeconds';
        case EchoSounderItem(:final capabilities, :final rangeMeters):
          _caps.addAll(capabilities);
          _range.text = '$rangeMeters';
        case PremiumItem(:final days, :final tier):
          _days.text = '$days';
          _tier.text = '$tier';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _desc, _price, _level, _maxKg, _smooth, _length, _escape,
      _chum, _range, _days, _tier,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _i(TextEditingController c, int d) => int.tryParse(c.text.trim()) ?? d;
  double _kg(TextEditingController c, double d) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? d;

  void _save() {
    final id = _id;
    final name =
        _name.text.trim().isEmpty ? 'Новый предмет' : _name.text.trim();
    final desc = _desc.text.trim();
    final price = Money(_currency, _i(_price, 100));
    final level = _i(_level, 1);
    final GearItem item;
    if (_isRod) {
      item = RodItem(
          id: id, name: name, description: desc, category: _cat,
          price: price, requiredLevel: level, rarity: _rarity,
          maxWeight: Weight.kilograms(_kg(_maxKg, 3)));
    } else if (_isReel) {
      item = ReelItem(
          id: id, name: name, description: desc, category: _cat,
          price: price, requiredLevel: level, rarity: _rarity,
          maxWeight: Weight.kilograms(_kg(_maxKg, 3)),
          smoothness: (_i(_smooth, 50) / 100).clamp(0.0, 1.0));
    } else if (_isLine) {
      item = LineItem(
          id: id, name: name, description: desc, category: _cat,
          price: price, requiredLevel: level, rarity: _rarity,
          lengthMeters: _i(_length, 100),
          maxWeight: Weight.kilograms(_kg(_maxKg, 3)));
    } else if (_cat == GearCategory.hook) {
      item = HookItem(
          id: id, name: name, description: desc,
          price: price, requiredLevel: level, rarity: _rarity,
          escapeChance: (_i(_escape, 15) / 100).clamp(0.0, 1.0));
    } else if (_cat == GearCategory.echoSounder) {
      item = EchoSounderItem(
          id: id, name: name, description: desc,
          price: price, requiredLevel: level, rarity: _rarity,
          capabilities: {..._caps},
          rangeMeters: _i(_range, 10));
    } else if (_cat == GearCategory.premium) {
      item = PremiumItem(
          id: id, name: name, description: desc,
          price: price, requiredLevel: level, rarity: _rarity,
          days: _i(_days, 7), tier: _i(_tier, 1));
    } else {
      item = LureItem(
          id: id, name: name, description: desc, category: _cat,
          price: price, requiredLevel: level, rarity: _rarity,
          lureType: _lureType, size: _lureSize, color: _lureColor,
          targetGroups: _targetGroups.toList()..sort(),
          chumSeconds: _i(_chum, 45));
    }
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final groups = SeedContent.kFishGroups.values.toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(
            '${widget.initial == null ? 'Новый' : 'Правка'} · ${gearCategoryRu(_cat)}',
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
            imageKey: 'item_$_id',
            asset: 'assets/art/items/$_id.png',
            label: 'Фото предмета (витрина магазина)',
            fallback: (_) => widget.initial != null
                ? _iconPodium(widget.initial!, 44)
                : const ColoredBox(
                    color: Color(0xFF0B1016),
                    child: Icon(Icons.image_outlined,
                        color: Colors.white24, size: 30)),
          ),
          const SizedBox(height: 12),
          _text(_name, 'Название'),
          _text(_desc, 'Описание (видно в магазине)', lines: 3),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _num(_price, 'Цена'),
            _dropdown<CurrencyType>(
                'Валюта',
                _currency,
                const [CurrencyType.silver, CurrencyType.gold],
                (v) => setState(() => _currency = v),
                (v) => v == CurrencyType.gold ? 'Золото' : 'Серебро'),
            _num(_level, 'Треб. уровень'),
            _dropdown<GearRarity>('Класс', _rarity, GearRarity.values,
                (v) => setState(() => _rarity = v), gearRarityRu),
          ]),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          ..._specific(groups),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _specific(List<String> groups) {
    if (_isRod) {
      return [_num(_maxKg, 'Тест (нагрузка), кг')];
    }
    if (_isReel) {
      return [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _num(_maxKg, 'Нагрузка, кг'),
          _num(_smooth, 'Мягкость, %'),
        ])
      ];
    }
    if (_isLine) {
      return [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _num(_maxKg, 'Разрывная, кг'),
          _num(_length, 'Длина, м'),
        ])
      ];
    }
    if (_cat == GearCategory.hook) {
      return [_num(_escape, 'Шанс схода, %')];
    }
    if (_cat == GearCategory.echoSounder) {
      return [
        _num(_range, 'Луч (глубина), м'),
        const SizedBox(height: 10),
        const Text('Возможности',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in SounderCapability.values)
            FilterChip(
              label: Text(capabilityInfo(c).$2,
                  style: const TextStyle(fontSize: 11)),
              selected: _caps.contains(c),
              selectedColor: _gold.withValues(alpha: 0.25),
              onSelected: (on) => setState(() {
                if (on) {
                  _caps.add(c);
                } else {
                  _caps.remove(c);
                }
              }),
            ),
        ]),
      ];
    }
    if (_cat == GearCategory.premium) {
      return [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _num(_days, 'Дней действия'),
          _num(_tier, 'Уровень (1–3)'),
        ])
      ];
    }
    // Расходники: наживки/приманки/прикормка/спреи/энергия.
    return [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _dropdown<LureType>('Тип', _lureType, LureType.all,
            (v) => setState(() => _lureType = v), (v) => v.label),
        _dropdown<LureSize>(
            'Размер',
            _lureSize,
            LureSize.values,
            (v) => setState(() => _lureSize = v),
            (v) => switch (v) {
                  LureSize.small => 'Мелкий',
                  LureSize.medium => 'Средний',
                  LureSize.large => 'Крупный',
                }),
        _dropdown<LureColor>(
            'Цвет',
            _lureColor,
            LureColor.values,
            (v) => setState(() => _lureColor = v),
            (v) => v == LureColor.bright ? 'Яркий' : 'Натуральный'),
        if (_cat == GearCategory.groundbait) _num(_chum, 'Действие, сек'),
      ]),
      if (_cat == GearCategory.groundbait) ...[
        const SizedBox(height: 12),
        const Text('Приманивает семейства (пусто — универсальная)',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in groups)
            FilterChip(
              label: Text(g, style: const TextStyle(fontSize: 11)),
              selected: _targetGroups.contains(g),
              selectedColor: _gold.withValues(alpha: 0.25),
              onSelected: (on) => setState(() {
                if (on) {
                  _targetGroups.add(g);
                } else {
                  _targetGroups.remove(g);
                }
              }),
            ),
        ]),
      ],
    ];
  }

  Widget _dropdown<T>(String label, T value, List<T> values,
      ValueChanged<T> onChanged, String Function(T) labelOf) {
    return SizedBox(
      width: 200,
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
