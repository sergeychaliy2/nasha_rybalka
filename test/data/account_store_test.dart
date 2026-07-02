import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nasha_rybalka/data/account_store.dart';
import 'package:nasha_rybalka/domain/entities/account.dart';
import 'package:nasha_rybalka/shared/password_hash.dart';

void main() {
  Future<AccountStore> freshStore() async {
    SharedPreferences.setMockInitialValues({});
    return AccountStore(await SharedPreferences.getInstance());
  }

  group('PasswordHash', () {
    test('пароль не хранится в открытом виде и проверяется', () {
      final salt = PasswordHash.newSalt();
      final hash = PasswordHash.hash('S3cret!', salt);
      expect(hash, isNot(contains('S3cret')));
      expect(hash.length, greaterThan(32));
      expect(PasswordHash.verify('S3cret!', salt, hash), isTrue);
      expect(PasswordHash.verify('wrong', salt, hash), isFalse);
    });

    test('одна и та же пара соль+пароль даёт один хеш; разная соль — разный',
        () {
      const pw = 'password123';
      final s1 = PasswordHash.newSalt();
      final s2 = PasswordHash.newSalt();
      expect(PasswordHash.hash(pw, s1), PasswordHash.hash(pw, s1));
      expect(PasswordHash.hash(pw, s1), isNot(PasswordHash.hash(pw, s2)));
    });
  });

  group('AccountStore', () {
    test('регистрация, вход, неверный пароль', () async {
      final store = await freshStore();
      final reg = await store.register(
          username: 'Рыбак', email: 'a@b.ru', password: 'secret1');
      expect(reg.success, isTrue);
      expect(store.isSignedIn, isTrue);
      await store.signOut();
      expect(store.isSignedIn, isFalse);

      final bad = await store.login('Рыбак', 'nope');
      expect(bad.success, isFalse);
      final ok = await store.login('a@b.ru', 'secret1');
      expect(ok.success, isTrue);
    });

    test('дубликаты имени/почты и слабый пароль отклоняются', () async {
      final store = await freshStore();
      await store.register(
          username: 'Дон', email: 'd@b.ru', password: 'secret1');
      expect(
          (await store.register(
                  username: 'Дон', email: 'x@b.ru', password: 'secret1'))
              .success,
          isFalse);
      expect(
          (await store.register(
                  username: 'Иной', email: 'd@b.ru', password: 'secret1'))
              .success,
          isFalse);
      expect(
          (await store.register(
                  username: 'Кто', email: 'k@b.ru', password: '123'))
              .success,
          isFalse);
    });

    test('блокировка запрещает вход', () async {
      final store = await freshStore();
      final reg = await store.register(
          username: 'Бан', email: 'ban@b.ru', password: 'secret1');
      await store.signOut();
      await store.update(reg.account!.copyWith(banned: true));
      final res = await store.login('Бан', 'secret1');
      expect(res.success, isFalse);
      expect(res.error, contains('заблокирован'));
    });

    test('реферал: регистрация по коду друга привязывает referredBy', () async {
      final store = await freshStore();
      final owner = await store.register(
          username: 'Хозяин', email: 'o@b.ru', password: 'secret1');
      await store.signOut();
      final code = owner.account!.referralCode;
      final invited = await store.register(
          username: 'Гость',
          email: 'g@b.ru',
          password: 'secret1',
          referral: code);
      expect(invited.success, isTrue);
      expect(invited.account!.referredBy, owner.account!.id);
    });

    test('политика: версия принимается и запоминается', () async {
      final store = await freshStore();
      expect(store.policyAccepted, isFalse);
      await store.acceptPolicy();
      expect(store.policyAccepted, isTrue);
      expect(store.acceptedPolicyVersion, kPolicyVersion);
    });
  });
}
