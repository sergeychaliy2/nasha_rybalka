import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/app_version.dart';
import '../shell/ui_kit.dart';

const _kSeenKey = 'seen_version';

/// Показать плашку «Что нового» ОДИН раз после обновления: если сохранённая
/// версия не совпадает с текущей — показываем изменения и запоминаем версию.
Future<void> maybeShowWhatsNew(
    BuildContext context, SharedPreferences prefs) async {
  final seen = prefs.getString(_kSeenKey);
  if (seen == kAppVersion) return;
  // Первый запуск (seen == null) — не спамим changelog новичку, просто метим.
  final firstEver = seen == null;
  await prefs.setString(_kSeenKey, kAppVersion);
  if (firstEver || !context.mounted) return;

  final entry = kChangelog.firstWhere((e) => e.version == kAppVersion,
      orElse: () => kChangelog.first);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _WhatsNewDialog(entry: entry),
  );
}

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog({required this.entry});
  final ({String version, String title, List<String> points}) entry;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SingleChildScrollView(
          child: HeaderPanel(
          header: 'Что нового · ${entry.version}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: kGold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 12),
              for (final p in entry.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle,
                            color: Color(0xFF6FBF73), size: 17),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(p,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5, height: 1.3)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: GoldButton(
                  label: 'За рыбалку!',
                  icon: Icons.sailing,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
