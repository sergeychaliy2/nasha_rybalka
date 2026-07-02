import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/skill.dart';
import '../../domain/value_objects/currency.dart';
import '../shell/ui_kit.dart';

/// Древо навыков в стиле ARC Raiders: три ветки растут от **корня внизу**,
/// узлы соединены изогнутыми линиями цвета своей ветки. Полотно крупное,
/// открывается снизу (виден корень) и плавно зумится к курсору, как карта.
class SkillsTree extends ConsumerStatefulWidget {
  const SkillsTree({super.key});

  // Размер «полотна» древа (крупное — 46 узлов в три ветки).
  static const canvas = Size(1340, 1240);

  // Нормированные позиции узлов (x,y от 0 до 1; y растёт вниз). Ряды идут
  // снизу (у корня) вверх; ветки расходятся развилками.
  static const pos = <String, Offset>{
    // --- Мастерство (центр) ---
    'm_bite': Offset(0.50, 0.88),
    'm_strike': Offset(0.50, 0.80),
    'm_fight': Offset(0.44, 0.72),
    'm_trophy': Offset(0.56, 0.72),
    'm_calm': Offset(0.40, 0.64),
    'm_pump': Offset(0.48, 0.64),
    'm_master': Offset(0.58, 0.64),
    'm_steel': Offset(0.40, 0.56),
    'm_focus': Offset(0.48, 0.56),
    'm_legend': Offset(0.58, 0.56),
    'm_zen': Offset(0.42, 0.48),
    'm_sense': Offset(0.58, 0.48),
    'm_grand': Offset(0.48, 0.40),
    'm_apex': Offset(0.52, 0.32),
    'm_god': Offset(0.50, 0.24),
    // --- Снасть (слева) ---
    't_bait': Offset(0.28, 0.88),
    't_break': Offset(0.24, 0.80),
    't_buy': Offset(0.32, 0.80),
    't_reel': Offset(0.20, 0.72),
    't_care': Offset(0.28, 0.72),
    't_slack': Offset(0.14, 0.64),
    't_smooth': Offset(0.24, 0.64),
    't_stock': Offset(0.31, 0.64),
    't_line': Offset(0.10, 0.56),
    't_drag': Offset(0.20, 0.56),
    't_thrift': Offset(0.30, 0.56),
    't_power': Offset(0.16, 0.48),
    't_cast': Offset(0.26, 0.48),
    't_master': Offset(0.20, 0.40),
    't_legend': Offset(0.18, 0.32),
    // --- Экономика (справа) ---
    'e_silver': Offset(0.72, 0.88),
    'e_xp': Offset(0.86, 0.86),
    'e_unlock': Offset(0.68, 0.80),
    'e_gold': Offset(0.76, 0.80),
    'e_shop': Offset(0.87, 0.78),
    'e_rich': Offset(0.66, 0.72),
    'e_salvage': Offset(0.74, 0.72),
    'e_keepxp': Offset(0.86, 0.70),
    'e_trade': Offset(0.68, 0.64),
    'e_jackpot': Offset(0.76, 0.64),
    'e_scholar': Offset(0.87, 0.62),
    'e_baron': Offset(0.70, 0.56),
    'e_fortune': Offset(0.79, 0.56),
    'e_sage': Offset(0.88, 0.54),
    'e_tycoon': Offset(0.78, 0.47),
    'e_mogul': Offset(0.80, 0.39),
  };
  static const root = Offset(0.5, 0.95);

  static Color branchColor(SkillBranch b) => switch (b) {
    SkillBranch.tackle => const Color(0xFF49C26A),
    SkillBranch.mastery => kGold,
    SkillBranch.economy => const Color(0xFFE5483B),
  };

  static String branchName(SkillBranch b) => switch (b) {
    SkillBranch.tackle => 'СНАСТЬ',
    SkillBranch.mastery => 'МАСТЕРСТВО',
    SkillBranch.economy => 'ЭКОНОМИКА',
  };

  @override
  ConsumerState<SkillsTree> createState() => _SkillsTreeState();
}

class _SkillsTreeState extends ConsumerState<SkillsTree> {
  // Свой трансформ: screen = scene * _s + _o.
  double _s = 1;
  Offset _o = Offset.zero;
  Size _viewport = Size.zero;
  double _pinchStart = 1;

  static const _resetCost = 15; // золото за сброс

  Offset _px(Offset n) =>
      Offset(n.dx * SkillsTree.canvas.width, n.dy * SkillsTree.canvas.height);

  void _clamp() {
    final sw = SkillsTree.canvas.width * _s;
    final sh = SkillsTree.canvas.height * _s;
    // Без пустоты по краям: если полотно больше вьюпорта — двигаем в его
    // пределах; если меньше — центрируем (увести в сторону нельзя).
    double axis(double o, double viewport, double content) =>
        content <= viewport
        ? (viewport - content) / 2
        : o.clamp(viewport - content, 0.0);
    _o = Offset(
      axis(_o.dx, _viewport.width, sw),
      axis(_o.dy, _viewport.height, sh),
    );
  }

  void _applyZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(0.5, 2.4);
    final k = next / _s;
    if (k == 1) return;
    _o = anchor - (anchor - _o) * k;
    _s = next;
    _clamp();
    setState(() {});
  }

  /// Начальный вид: вписать по ширине и прижать к низу (корень виден).
  void _fitBottom(Size size) {
    _viewport = size;
    _s = (size.width / SkillsTree.canvas.width).clamp(0.55, 1.15);
    final sw = SkillsTree.canvas.width * _s;
    final sh = SkillsTree.canvas.height * _s;
    _o = Offset((size.width - sw) / 2, size.height - sh);
    _clamp();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider).value;
    final skills = player?.skills ?? const <String, int>{};
    final mastery = player?.skillPoints ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(width: 4, height: 22, color: kGold),
              const SizedBox(width: 10),
              Text('ДРЕВО НАВЫКОВ', style: displayStyle(size: 20)),
              const Spacer(),
              _resetButton(skills),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Опыт мастерства — за новые уровни и трофеи',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kGold.withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.military_tech, size: 17, color: kGold),
                      const SizedBox(width: 6),
                      Text(
                        '$mastery',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, 0.4),
                  radius: 1.0,
                  colors: [Color(0xFF10151B), Color(0xFF05070A)],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  if (_viewport != size) _fitBottom(size);
                  return Listener(
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent) {
                        _applyZoom(
                          math.exp(-e.scrollDelta.dy / 350),
                          e.localPosition,
                        );
                      }
                    },
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Ловец панорамы/зума — ПОД узлами: ловит жесты только
                          // на пустом фоне, поэтому тап по узлу всегда доходит
                          // до самого узла (жест не перехватывается).
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: (_) => _pinchStart = _s,
                              onScaleUpdate: (d) {
                                if (d.scale != 1) {
                                  _applyZoom(
                                    (_pinchStart * d.scale) / _s,
                                    d.localFocalPoint,
                                  );
                                } else {
                                  setState(() {
                                    _o += d.focalPointDelta;
                                    _clamp();
                                  });
                                }
                              },
                              child: const SizedBox.expand(),
                            ),
                          ),
                          // OverflowBox снимает тайтовые констрейнты вьюпорта,
                          // чтобы полотно было настоящих 1080×920. Иначе
                          // SizedBox схлопывается до вьюпорта и hit-test
                          // отбрасывает узлы ниже его высоты (size.contains).
                          Positioned.fill(
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: 0,
                              minHeight: 0,
                              maxWidth: double.infinity,
                              maxHeight: double.infinity,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translateByDouble(_o.dx, _o.dy, 0, 1)
                                  ..scaleByDouble(_s, _s, 1, 1),
                                child: SizedBox(
                                  width: SkillsTree.canvas.width,
                                  height: SkillsTree.canvas.height,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _BranchPainter(
                                              skills: skills,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (final b in SkillBranch.values)
                                        _branchLabel(b, skills),
                                      Positioned(
                                        left: _px(SkillsTree.root).dx - 28,
                                        top: _px(SkillsTree.root).dy - 28,
                                        child: IgnorePointer(
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [kGoldLight, kGold],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: kGold.withValues(
                                                    alpha: 0.5,
                                                  ),
                                                  blurRadius: 16,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.park,
                                              color: kTextDark,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (final node in SeedSkills.nodes)
                                        _node(node, skills, mastery),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Колесо — зум к курсору · перетаскивание — двигать древо',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchLabel(SkillBranch b, Map<String, int> skills) {
    final color = SkillsTree.branchColor(b);
    final spent = SeedSkills.nodes
        .where((n) => n.branch == b)
        .fold<int>(0, (s, n) => s + (skills[n.id] ?? 0));
    // Заголовки веток — сверху над кластерами, чтобы ничего не перекрывать.
    final anchor = switch (b) {
      SkillBranch.tackle => const Offset(0.20, 0.12),
      SkillBranch.mastery => const Offset(0.50, 0.10),
      SkillBranch.economy => const Offset(0.82, 0.12),
    };
    final p = _px(anchor);
    return Positioned(
      left: p.dx - 80,
      top: p.dy,
      width: 160,
      child: IgnorePointer(
        child: Column(
          children: [
            Text(
              SkillsTree.branchName(b),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            Text(
              '$spent',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _node(SkillNode node, Map<String, int> skills, int mastery) {
    final p = _px(SkillsTree.pos[node.id]!);
    final level = skills[node.id] ?? 0;
    final prereqOk = node.prereq == null || (skills[node.prereq] ?? 0) > 0;
    final maxed = level >= node.maxLevel;
    final available = prereqOk && !maxed && mastery >= node.xpCostFor(level);
    final color = SkillsTree.branchColor(node.branch);

    final ringColor = !prereqOk
        ? Colors.white.withValues(alpha: 0.12)
        : (maxed || level > 0)
        ? color
        : available
        ? color.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.25);
    final fill = (maxed || level > 0)
        ? color.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.55);

    return Positioned(
      left: p.dx - 38,
      top: p.dy - 38,
      child: GestureDetector(
        // Вся площадь узла (76×~84) кликабельна, а не только иконка в центре.
        behavior: HitTestBehavior.opaque,
        onTap: () => _showNode(node),
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(
                    color: ringColor,
                    width: available || maxed ? 3 : 2,
                  ),
                  boxShadow: [
                    if (available)
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 14,
                      ),
                  ],
                ),
                child: Icon(
                  prereqOk ? node.icon : Icons.lock,
                  color: prereqOk ? Colors.white : Colors.white38,
                  size: 26,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0E12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ringColor),
                  ),
                  child: Text(
                    '$level/${node.maxLevel}',
                    style: TextStyle(
                      color: maxed ? color : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resetButton(Map<String, int> skills) {
    final spent = skills.values.fold<int>(0, (s, v) => s + v);
    return GestureDetector(
      onTap: spent == 0 ? null : () => _confirmReset(spent),
      child: Opacity(
        opacity: spent == 0 ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5483B).withValues(alpha: 0.7),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restart_alt, size: 15, color: Color(0xFFE5483B)),
              SizedBox(width: 6),
              Text(
                'Сброс',
                style: TextStyle(
                  color: Color(0xFFE5483B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(int spent) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: HeaderPanel(
            header: 'Сброс навыков',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Сбросить $spent прокачанных уровней? Весь накопленный '
                  'опыт мастерства сгорит безвозвратно. '
                  'Стоимость сброса: $_resetCost золота.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GoldButton(
                      label: 'Сбросить · 💎$_resetCost',
                      icon: Icons.restart_alt,
                      onTap: () async {
                        final res = await ref
                            .read(playerControllerProvider.notifier)
                            .resetSkills(const Money.gold(_resetCost));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                res == UnlockResult.ok
                                    ? 'Навыки сброшены'
                                    : 'Недостаточно золота',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 1500),
                              backgroundColor: const Color(0xFF1A1F25),
                            ),
                          );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 7),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNode(SkillNode node) {
    // Красивое появление: лёгкий «поп» (scale + fade) с пружинкой.
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: node.title,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.82, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, _) => Consumer(
        builder: (context, ref, _) {
          final player = ref.watch(playerControllerProvider).value;
          final skills = player?.skills ?? const <String, int>{};
          final mastery = player?.skillPoints ?? 0;
          final level = skills[node.id] ?? 0;
          final maxed = level >= node.maxLevel;
          final prereqOk =
              node.prereq == null || (skills[node.prereq] ?? 0) > 0;
          final color = SkillsTree.branchColor(node.branch);
          final cost = node.xpCostFor(level);
          final enough = mastery >= cost;
          final canSpend = prereqOk && !maxed && enough;
          final prereqTitle = node.prereq == null
              ? ''
              : SeedSkills.byId(node.prereq!)?.title ?? '';

          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                decoration: BoxDecoration(
                  color: kPanelBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kPanelHeader,
                        border: Border(
                          bottom: BorderSide(color: color, width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.2),
                              border: Border.all(color: color),
                            ),
                            child: Icon(
                              node.icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(node.title, style: displayStyle(size: 17)),
                                Text(
                                  '${SkillsTree.branchName(node.branch)} · $level/${node.maxLevel}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            node.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _detailRow(
                            Icons.bolt,
                            'За уровень',
                            node.perLevelText,
                            Colors.white70,
                          ),
                          _detailRow(
                            Icons.check_circle,
                            'Сейчас',
                            level == 0 ? 'не вложено' : node.valueText(level),
                            level == 0 ? Colors.white38 : color,
                          ),
                          if (!maxed)
                            _detailRow(
                              Icons.trending_up,
                              'Станет',
                              node.valueText(level + 1),
                              kGold,
                            ),
                          if (maxed)
                            _detailRow(
                              Icons.verified,
                              'Статус',
                              'максимум',
                              kGold,
                            )
                          else
                            _detailRow(
                              Icons.military_tech,
                              'Цена',
                              '$cost опыта мастерства',
                              enough ? kGold : const Color(0xFFE5483B),
                            ),
                          if (!prereqOk && prereqTitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Закрыто. Сначала откройте «$prereqTitle» — '
                                'узлы открываются по цепочке от корня.',
                                style: const TextStyle(
                                  color: Color(0xFFE5483B),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            )
                          else if (!maxed && prereqOk && !enough)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Не хватает ещё ${cost - mastery}. Опыт '
                                'мастерства капает за новые уровни и трофеи.',
                                style: const TextStyle(
                                  color: Color(0xFFE5483B),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text(
                                  'Закрыть',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GoldButton(
                                label: maxed ? 'Максимум' : 'Прокачать · $cost',
                                icon: Icons.add,
                                enabled: canSpend,
                                onTap: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .spendSkill(node),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Рисует изогнутые ветки-связи между корнем и узлами цветом ветки;
/// яркость растёт по мере прокачки.
class _BranchPainter extends CustomPainter {
  _BranchPainter({required this.skills});

  final Map<String, int> skills;

  Offset _px(Offset n) =>
      Offset(n.dx * SkillsTree.canvas.width, n.dy * SkillsTree.canvas.height);

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in SeedSkills.nodes) {
      final to = _px(SkillsTree.pos[node.id]!);
      final from = node.prereq == null
          ? _px(SkillsTree.root)
          : _px(SkillsTree.pos[node.prereq]!);
      final color = SkillsTree.branchColor(node.branch);
      final lvl = skills[node.id] ?? 0;
      final prereqOk = node.prereq == null || (skills[node.prereq] ?? 0) > 0;
      final alpha = lvl > 0 ? 0.85 : (prereqOk ? 0.4 : 0.14);
      final width = lvl > 0 ? 5.0 : 3.0;

      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          from.dx,
          (from.dy + to.dy) / 2,
          to.dx,
          (from.dy + to.dy) / 2,
          to.dx,
          to.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 3
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: alpha),
      );
      if (lvl > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color = color.withValues(alpha: 0.4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BranchPainter old) => true;
}
