import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../menu/main_menu_screen.dart';
import 'auth_screen.dart';
import 'policy_screen.dart';
import 'whats_new.dart';

/// Корневой шлюз после сплэша:
/// 1) политика не принята → экран принятия;
/// 2) не выполнен вход → экран входа/регистрации;
/// 3) иначе → главное меню (+ разовая плашка «Что нового»).
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  late bool _policyAccepted;
  bool _whatsNewChecked = false;

  @override
  void initState() {
    super.initState();
    _policyAccepted = ref.read(accountStoreProvider).policyAccepted;
  }

  @override
  Widget build(BuildContext context) {
    if (!_policyAccepted) {
      return PolicyScreen(onAccept: () async {
        await ref.read(accountStoreProvider).acceptPolicy();
        if (mounted) setState(() => _policyAccepted = true);
      });
    }
    final account = ref.watch(currentAccountProvider);
    if (account == null) return const AuthScreen();

    // Вошли — покажем «Что нового» один раз, затем меню.
    if (!_whatsNewChecked) {
      _whatsNewChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          maybeShowWhatsNew(context, ref.read(sharedPreferencesProvider));
        }
      });
    }
    return const MainMenuScreen();
  }
}
