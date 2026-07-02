import 'package:flutter/material.dart';

const _gold = Color(0xFFE4B857);

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
