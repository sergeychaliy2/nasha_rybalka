import 'package:flutter/material.dart';

import '../data/content_overrides.dart';
import '../domain/services/tuning.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Редактор глобальных коэффициентов: прокачка, энергия, клёв, погода.
/// Значения применяются игрой на старте (после перезапуска).
class TuningEditor extends StatefulWidget {
  const TuningEditor({super.key, required this.overrides});
  final ContentOverrides overrides;

  @override
  State<TuningEditor> createState() => _TuningEditorState();
}

class _TuningEditorState extends State<TuningEditor> {
  late final Map<String, TextEditingController> _c;
  double _precipBias = Tuning.precipBias;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // Оверрайды уже применены к Tuning при старте админки.
    _c = {
      'levelBase': _ctrl(Tuning.levelBase.toStringAsFixed(0)),
      'levelExponent': _ctrl('${Tuning.levelExponent}'),
      'maxEnergy': _ctrl('${Tuning.maxEnergy}'),
      'energyRegenSeconds': _ctrl('${Tuning.energyRegenSeconds}'),
      'energyPerCast': _ctrl('${Tuning.energyPerCast}'),
      'chumBoost': _ctrl('${Tuning.chumBoost}'),
      'rarityCommon': _ctrl('${Tuning.rarityCommon}'),
      'rarityUncommon': _ctrl('${Tuning.rarityUncommon}'),
      'rarityRare': _ctrl('${Tuning.rarityRare}'),
      'rarityTrophy': _ctrl('${Tuning.rarityTrophy}'),
      'rarityLegendary': _ctrl('${Tuning.rarityLegendary}'),
      'preRainBiteBonus': _ctrl('${Tuning.preRainBiteBonus}'),
    };
  }

  TextEditingController _ctrl(String v) {
    final c = TextEditingController(text: v);
    c.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
    return c;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(String k, double def) =>
      double.tryParse(_c[k]!.text.trim().replaceAll(',', '.')) ?? def;
  int _i(String k, int def) => int.tryParse(_c[k]!.text.trim()) ?? def;

  Future<void> _save() async {
    final j = <String, dynamic>{
      'levelBase': _d('levelBase', 3000),
      'levelExponent': _d('levelExponent', 1.25),
      'maxEnergy': _i('maxEnergy', 100),
      'energyRegenSeconds': _i('energyRegenSeconds', 300),
      'energyPerCast': _i('energyPerCast', 3),
      'chumBoost': _d('chumBoost', 2.6),
      'rarityCommon': _d('rarityCommon', 1.0),
      'rarityUncommon': _d('rarityUncommon', 0.7),
      'rarityRare': _d('rarityRare', 0.45),
      'rarityTrophy': _d('rarityTrophy', 0.28),
      'rarityLegendary': _d('rarityLegendary', 0.15),
      'preRainBiteBonus': _d('preRainBiteBonus', 1.25),
      'precipBias': _precipBias,
    };
    widget.overrides.setTuning(j);
    await widget.overrides.save();
    widget.overrides.applyToGame();
    setState(() => _dirty = false);
    _toast('Сохранено · перезапусти игру');
  }

  Future<void> _reset() async {
    widget.overrides.clearTuning();
    await widget.overrides.save();
    Tuning.reset();
    setState(() {
      _c['levelBase']!.text = Tuning.levelBase.toStringAsFixed(0);
      _c['levelExponent']!.text = '${Tuning.levelExponent}';
      _c['maxEnergy']!.text = '${Tuning.maxEnergy}';
      _c['energyRegenSeconds']!.text = '${Tuning.energyRegenSeconds}';
      _c['energyPerCast']!.text = '${Tuning.energyPerCast}';
      _c['chumBoost']!.text = '${Tuning.chumBoost}';
      _c['rarityCommon']!.text = '${Tuning.rarityCommon}';
      _c['rarityUncommon']!.text = '${Tuning.rarityUncommon}';
      _c['rarityRare']!.text = '${Tuning.rarityRare}';
      _c['rarityTrophy']!.text = '${Tuning.rarityTrophy}';
      _c['rarityLegendary']!.text = '${Tuning.rarityLegendary}';
      _c['preRainBiteBonus']!.text = '${Tuning.preRainBiteBonus}';
      _precipBias = Tuning.precipBias;
      _dirty = false;
    });
    _toast('Дефолтные коэффициенты восстановлены');
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
        title: const Text('Погода и коэффициенты',
            style: TextStyle(color: _gold)),
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
          _section('Прокачка', 'Кривая уровней: требуется base·(уровень−1)^exp',
              [
                _num('levelBase', 'База, грамм'),
                _num('levelExponent', 'Экспонента'),
              ]),
          _section('Энергия', 'Лимит, восстановление и расход на заброс', [
            _num('maxEnergy', 'Максимум'),
            _num('energyRegenSeconds', '+1 каждые, сек'),
            _num('energyPerCast', 'Расход на заброс'),
          ]),
          _section('Клёв', 'Бонусы и множители по редкости вида', [
            _num('chumBoost', 'Бонус прикормки, ×'),
            _num('preRainBiteBonus', 'Перед дождём, ×'),
            _num('rarityCommon', 'Обычная, ×'),
            _num('rarityUncommon', 'Необычная, ×'),
            _num('rarityRare', 'Редкая, ×'),
            _num('rarityTrophy', 'Трофейная, ×'),
            _num('rarityLegendary', 'Легендарная, ×'),
          ]),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Погода',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Сдвиг вероятности осадков в прогнозе (влево — реже, вправо — чаще)',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.5)),
                Row(children: [
                  const Text('Реже', style: TextStyle(color: Colors.white38)),
                  Expanded(
                    child: Slider(
                      value: _precipBias,
                      min: -0.15,
                      max: 0.2,
                      activeColor: _gold,
                      label: _precipBias.toStringAsFixed(2),
                      onChanged: (v) => setState(() {
                        _precipBias = v;
                        _dirty = true;
                      }),
                    ),
                  ),
                  const Text('Чаще', style: TextStyle(color: Colors.white38)),
                ]),
              ],
            ),
          ),
          Text(
            'Дефолты: база 3000 г, экспонента 1.25, энергия 100 / +1 за 300 с / '
            '3 за заброс, прикормка ×2.6, редкости ×1/0.7/0.45/0.28/0.15.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String sub, List<Widget> fields) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 11.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: fields),
        ],
      ),
    );
  }

  Widget _num(String key, String label) => SizedBox(
        width: 170,
        child: TextField(
          controller: _c[key],
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.25),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _gold)),
          ),
        ),
      );
}
