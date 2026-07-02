import 'package:flutter/material.dart';

import '../shell/ui_kit.dart';

/// Текст политики/условий (офлайн-версия). При появлении бэкенда сюда добавятся
/// пункты о передаче данных на сервер и обработке ПД.
const String kPolicyText = '''
«Наша Рыбалка» — рыболовный симулятor. Играя, вы соглашаетесь с условиями ниже.

1. Данные и приватность
• Игра работает офлайн. Аккаунт (имя, e-mail, прогресс) хранится ЛОКАЛЬНО на
  этом устройстве и не передаётся на сторонние серверы.
• Пароль не сохраняется в открытом виде — только защищённый хеш.
• Если позже появится онлайн-режим, отдельно запросим согласие на передачу
  данных.

2. Возраст
• Рекомендуется 12+. Игра не содержит реальных ставок и азартных механик.

3. Внутриигровые ценности
• Серебро, золото и «премиум» — виртуальные и не имеют денежной стоимости.
  Реальные платежи не используются.

4. Честная игра
• Запрещено вмешательство в файлы сохранений ради нечестного преимущества в
  соревновательных режимах.

5. Ответственность
• Игра предоставляется «как есть». Разработчик не несёт ответственности за
  возможные перерывы в работе или потерю локальных данных.

Продолжая, вы подтверждаете, что прочли и принимаете эти условия и политику
конфиденциальности.
''';

/// Экран принятия политики (первый запуск / повышение версии политики).
class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key, required this.onAccept});
  final VoidCallback onAccept;

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/art/menu_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF0C1116))),
          Container(color: Colors.black.withValues(alpha: 0.72)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 620,
                    maxHeight: MediaQuery.of(context).size.height - 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: kPanelBody,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.45)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Шапка.
                      Container(
                        width: double.infinity,
                        color: kPanelHeader,
                        padding: const EdgeInsets.symmetric(
                            vertical: 9, horizontal: 12),
                        child: const Text('ПОЛИТИКА И УСЛОВИЯ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8)),
                      ),
                      // Текст — гибко ужимается и скроллится.
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                          child: Text(kPolicyText,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13,
                                  height: 1.5)),
                        ),
                      ),
                      // Согласие + кнопка — всегда закреплены снизу.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _agree = !_agree),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Row(children: [
                                  Icon(
                                      _agree
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: kGold),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                        'Я прочитал(а) и принимаю условия и '
                                        'политику конфиденциальности',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 13)),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: GoldButton(
                                label: 'Принять и продолжить',
                                icon: Icons.verified_user,
                                enabled: _agree,
                                onTap: widget.onAccept,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
