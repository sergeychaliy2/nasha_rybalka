import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../domain/entities/account.dart';
import '../shared/countries.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Мониторинг и управление аккаунтами: список, поиск, создание, правка,
/// блокировка, сброс пароля, удаление. Данные — общий локальный стор с игрой.
class AccountsEditor extends StatefulWidget {
  const AccountsEditor({super.key, required this.store});
  final AccountStore store;

  @override
  State<AccountsEditor> createState() => _AccountsEditorState();
}

class _AccountsEditorState extends State<AccountsEditor> {
  String _query = '';

  void _refresh() => setState(() {});

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel));

  Future<void> _create() async {
    final res = await showDialog<AuthResult>(
      context: context,
      builder: (_) => _AccountDialog(store: widget.store),
    );
    if (res == null) return;
    if (res.success) {
      _toast('Аккаунт создан: ${res.account!.username}');
    } else {
      _toast(res.error ?? 'Ошибка');
    }
    _refresh();
  }

  Future<void> _edit(Account acc) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountDialog(store: widget.store, initial: acc),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.store.all()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all
            .where((a) =>
                a.username.toLowerCase().contains(q) ||
                a.email.toLowerCase().contains(q) ||
                a.referralCode.toLowerCase().contains(q))
            .toList();
    final players = all.where((a) => a.role == AccountRole.player).length;
    final admins = all.where((a) => a.role == AccountRole.admin).length;
    final banned = all.where((a) => a.banned).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel,
        iconTheme: const IconThemeData(color: _gold),
        title: Text('Аккаунты · ${all.length}',
            style: const TextStyle(color: _gold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        onPressed: _create,
        icon: const Icon(Icons.person_add),
        label: const Text('Аккаунт'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            _stat(Icons.group, 'Игроки', '$players', const Color(0xFF5AA9E6)),
            _stat(Icons.shield, 'Админы', '$admins', _gold),
            _stat(Icons.block, 'Заблок.', '$banned', const Color(0xFFE5726A)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Поиск по имени, e-mail или коду…',
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
          child: all.isEmpty
              ? const Center(
                  child: Text('Пока нет аккаунтов — создай первый',
                      style: TextStyle(color: Colors.white38)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(list[i]),
                ),
        ),
      ]),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _row(Account a) {
    final isAdmin = a.role == AccountRole.admin;
    return Opacity(
      opacity: a.banned ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (isAdmin ? _gold : Colors.white).withValues(alpha: 0.14)),
        ),
        child: InkWell(
          onTap: () => _edit(a),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  (isAdmin ? _gold : const Color(0xFF5AA9E6)).withValues(alpha: 0.2),
              child: Icon(isAdmin ? Icons.shield : Icons.person,
                  color: isAdmin ? _gold : const Color(0xFF5AA9E6), size: 18),
            ),
            const SizedBox(width: 8),
            Tooltip(
                message: countryByCode(a.country).nameRu,
                child: FlagIcon(a.country)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(a.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (a.banned) ...[
                      const SizedBox(width: 6),
                      _tag('БЛОК', const Color(0xFFE5726A)),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      _tag('АДМИН', _gold),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                      '${a.email} · код ${a.referralCode}'
                      '${a.referredBy != null ? ' · по рефералу' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5)),
                ],
              ),
            ),
            IconButton(
              tooltip: a.banned ? 'Разблокировать' : 'Заблокировать',
              onPressed: () async {
                await widget.store.update(a.copyWith(banned: !a.banned));
                _refresh();
              },
              icon: Icon(a.banned ? Icons.lock_open : Icons.block,
                  color: a.banned ? const Color(0xFF6FBF73) : Colors.white54,
                  size: 19),
            ),
            IconButton(
              tooltip: 'Правка',
              onPressed: () => _edit(a),
              icon: const Icon(Icons.edit, color: Colors.white54, size: 19),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.withValues(alpha: 0.6)),
        ),
        child: Text(t,
            style: TextStyle(
                color: c, fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

/// Диалог создания/правки аккаунта.
class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.store, this.initial});
  final AccountStore store;
  final Account? initial;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _note = TextEditingController();
  AccountRole _role = AccountRole.player;
  bool _banned = false;
  String _country = 'RU';
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null) {
      _username.text = a.username;
      _email.text = a.email;
      _note.text = a.note;
      _role = a.role;
      _banned = a.banned;
      _country = a.country;
    }
  }

  @override
  void dispose() {
    for (final c in [_username, _email, _password, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final store = widget.store;
    if (_isEdit) {
      final a = widget.initial!;
      await store.update(a.copyWith(
        username: _username.text.trim(),
        email: _email.text.trim(),
        role: _role,
        banned: _banned,
        country: _country,
        note: _note.text.trim(),
      ));
      if (_password.text.trim().isNotEmpty) {
        await store.setPassword(a.id, _password.text.trim());
      }
      if (mounted) Navigator.pop(context, true);
    } else {
      final res = await store.adminCreate(
        username: _username.text,
        email: _email.text,
        password: _password.text,
        country: _country,
        role: _role,
      );
      if (!mounted) return;
      if (res.success) {
        Navigator.pop(context, res);
      } else {
        setState(() => _error = res.error);
      }
    }
  }

  Future<void> _delete() async {
    await widget.store.delete(widget.initial!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: Text(_isEdit ? 'Правка аккаунта' : 'Новый аккаунт',
          style: const TextStyle(color: _gold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_username, 'Имя'),
            _field(_email, 'E-mail'),
            _field(_password, _isEdit ? 'Новый пароль (пусто — не менять)' : 'Пароль'),
            _field(_note, 'Заметка администратора', lines: 2),
            const SizedBox(height: 4),
            Row(children: [
              const Text('Страна:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              FlagIcon(_country),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _country,
                  isExpanded: true,
                  dropdownColor: _panel,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    for (final c in kCountries)
                      DropdownMenuItem(value: c.code, child: Text(c.nameRu)),
                  ],
                  onChanged: (v) => setState(() => _country = v ?? _country),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Роль:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              DropdownButton<AccountRole>(
                value: _role,
                dropdownColor: _panel,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                      value: AccountRole.player, child: Text('Игрок')),
                  DropdownMenuItem(
                      value: AccountRole.admin, child: Text('Администратор')),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const Spacer(),
              if (_isEdit)
                Row(children: [
                  const Text('Блок', style: TextStyle(color: Colors.white70)),
                  Switch(
                    value: _banned,
                    activeTrackColor: const Color(0xFFE5726A),
                    onChanged: (v) => setState(() => _banned = v),
                  ),
                ]),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFE5726A))),
              ),
          ],
        ),
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: _delete,
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE5726A))),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _gold),
          onPressed: _save,
          child: const Text('Сохранить', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: lines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12))),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: _gold)),
          ),
        ),
      );
}
