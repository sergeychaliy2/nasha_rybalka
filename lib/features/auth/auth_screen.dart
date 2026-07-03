import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/countries.dart';
import '../shell/ui_kit.dart';
import 'policy_screen.dart';

/// Экран входа/регистрации (локальные аккаунты). При успехе выставляет
/// [currentAccountProvider] — `RootGate` реагирует и открывает меню.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  String? _error;
  bool _obscure = true;
  String _country = 'RU';

  final _login = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();

  @override
  void dispose() {
    for (final c in [_login, _username, _email, _password, _referral]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = ref.read(accountStoreProvider);
    final res = _register
        ? await store.register(
            username: _username.text,
            email: _email.text,
            password: _password.text,
            referral: _referral.text,
            country: _country,
          )
        : await store.login(_login.text, _password.text);
    if (!mounted) return;
    if (res.success) {
      ref.read(currentAccountProvider.notifier).set(res.account);
    } else {
      setState(() {
        _busy = false;
        _error = res.error;
      });
    }
  }

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
          Container(color: Colors.black.withValues(alpha: 0.68)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: HeaderPanel(
                  header: _register ? 'Регистрация' : 'Вход',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎣  Заветная Рыбалка',
                          style: TextStyle(
                              color: kGold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('Данные хранятся на этом устройстве',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11.5)),
                      const SizedBox(height: 14),
                      _tabs(),
                      const SizedBox(height: 14),
                      if (_register) ...[
                        _field(_username, 'Имя рыбака', Icons.person),
                        _field(_email, 'E-mail', Icons.alternate_email),
                        _countryField(),
                      ] else
                        _field(_login, 'Имя или e-mail', Icons.person),
                      _field(_password, 'Пароль', Icons.lock,
                          obscure: _obscure,
                          trailing: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white38, size: 20),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          )),
                      if (_register)
                        _field(_referral, 'Код друга (необязательно)',
                            Icons.card_giftcard),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFE5726A), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Color(0xFFE5726A), fontSize: 12.5)),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: GoldButton(
                          label: _register ? 'Создать аккаунт' : 'Войти',
                          icon: _register ? Icons.person_add : Icons.login,
                          enabled: !_busy,
                          onTap: _submit,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF161C23),
                            title: const Text('Политика и условия',
                                style: TextStyle(color: kGold)),
                            content: SingleChildScrollView(
                              child: Text(kPolicyText,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                      height: 1.5)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Закрыть',
                                    style: TextStyle(color: kGold)),
                              ),
                            ],
                          ),
                        ),
                        child: Text('Политика и условия',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12)),
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

  Widget _tabs() {
    Widget tab(String label, bool reg) {
      final on = _register == reg;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _register = reg;
            _error = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? kGold.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: on ? kGold : Colors.white.withValues(alpha: 0.12)),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    color: on ? kGold : Colors.white60,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return Row(children: [
      tab('Вход', false),
      const SizedBox(width: 8),
      tab('Регистрация', true),
    ]);
  }

  Widget _countryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Страна проживания',
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(11),
            child: FlagIcon(_country),
          ),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.3),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _country,
            isExpanded: true,
            dropdownColor: const Color(0xFF161C23),
            style: const TextStyle(color: Colors.white),
            items: [
              for (final c in kCountries)
                DropdownMenuItem(
                  value: c.code,
                  child: Row(children: [
                    FlagIcon(c.code, width: 22, height: 15),
                    const SizedBox(width: 10),
                    Text(c.nameRu),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => _country = v ?? _country),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          suffixIcon: trailing,
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.3),
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
              borderSide: const BorderSide(color: kGold)),
        ),
      ),
    );
  }
}
