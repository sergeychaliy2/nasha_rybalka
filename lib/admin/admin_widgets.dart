import 'package:flutter/material.dart';

import '../features/map/region_store.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Значок-подсказка: наведи (или тапни) — появится пояснение, что это за поле
/// и зачем. Используется по всей админке рядом с полями и заголовками.
class InfoDot extends StatelessWidget {
  const InfoDot(this.message, {super.key, this.size = 18});
  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 8),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(10),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1016),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Icon(Icons.info_outline, size: size, color: const Color(0xFF7FB3D5)),
    );
  }
}

/// Заголовок раздела админки: иконка + название + краткое описание, а справа —
/// значок-подсказка с подробностями.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle = '',
      this.info = '',
      this.color = _gold});
  final IconData icon;
  final String title;
  final String subtitle;
  final String info;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.5)),
            ],
          ),
        ),
        if (info.isNotEmpty) InfoDot(info),
      ],
    );
  }
}

/// Строка фильтра списка по региону: «Найти → регион» + счётчик и сброс.
class RegionFilterBar extends StatelessWidget {
  const RegionFilterBar({
    super.key,
    required this.regions,
    required this.selected,
    required this.shownCount,
    required this.word,
    required this.onChanged,
  });
  final List<RuRegion> regions;
  final RuRegion? selected;
  final int shownCount;
  final String word;
  final ValueChanged<RuRegion?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: (selected != null ? _gold : Colors.white24)
                  .withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(Icons.search,
              color: selected != null ? _gold : Colors.white54, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RuRegion?>(
                value: selected,
                isExpanded: true,
                menuMaxHeight: 340,
                hint: const Text('Фильтр по региону — найти',
                    style: TextStyle(color: Colors.white54)),
                dropdownColor: _panel,
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— все регионы —')),
                  for (final r in regions)
                    DropdownMenuItem(value: r, child: Text(r.nameRu)),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
          if (selected != null) ...[
            Text('$shownCount $word',
                style: const TextStyle(color: _gold, fontSize: 12.5)),
            IconButton(
              tooltip: 'Сбросить',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ]),
      ),
    );
  }
}
