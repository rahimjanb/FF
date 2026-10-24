import 'dart:convert';

import 'package:fitness_formulasi/ui/client/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fake_backend.dart';
import 'screen_harness.dart';

void main() {
  const screen = Scaffold(body: ProfileScreen());

  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Fitness Formula',
      packageName: 'uz.ff',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  FakeBackend backend() {
    final b = FakeBackend();
    var profile = {...profileJson(withTrainer: false), 'memberSince': '2026-04-02T10:00:00Z'};
    b.routes['/api/me/profile'] = (req) {
      if (req.method == 'PUT') profile = {...profile, ...jsonDecode(req.body) as Map<String, dynamic>};
      return profile;
    };
    return b;
  }

  testWidgets('shows the card, real stats, read-only data and the build version', (tester) async {
    await pumpScreen(tester, screen, backend: backend());

    expect(find.text('Aziz Karimov'), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    expect(find.text('Не подтверждён'), findsOneWidget);
    expect(find.text('Gold 30'), findsOneWidget); // current membership from the dashboard
    expect(find.text('17'), findsOneWidget); // total visits
    expect(find.text('апр. 2026'), findsOneWidget);
    expect(find.text('2 из 5 заполнено'), findsOneWidget);
    expect(find.text('Добавить email'), findsOneWidget);
    expect(find.text('Сохранить'), findsNothing); // no save button in view mode

    await tester.scrollUntilVisible(find.text('Fitness Formula · версия 1.0.0'), 300);
    expect(find.byKey(const Key('profile-logout')), findsOneWidget);
  });

  testWidgets('editing: invalid email blocks Done, valid change is saved and shown', (tester) async {
    final b = backend();
    await pumpScreen(tester, screen, backend: b);

    await tester.tap(find.text('Добавить email'));
    await tester.pumpAndSettle();
    expect(find.text('Редактирование'), findsOneWidget);
    Finder done() => find.byKey(const Key('profile-edit-done'));
    expect(tester.widget<TextButton>(done()).onPressed, isNull); // nothing changed yet

    await tester.enterText(find.byKey(const Key('profile-edit-email')), 'not-an-email');
    await tester.pump();
    expect(find.text('Неверный email'), findsOneWidget);
    expect(tester.widget<TextButton>(done()).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('profile-edit-email')), ' aziz@example.uz ');
    await tester.pump();
    await tester.tap(done());
    await settle(tester);

    final put = b.requests.lastWhere((r) => r.method == 'PUT' && r.url.path == '/api/me/profile');
    expect(jsonDecode(put.body)['email'], 'aziz@example.uz');
    expect(find.text('Редактирование'), findsNothing);
    expect(find.text('aziz@example.uz'), findsOneWidget);
    expect(find.text('3 из 5 заполнено'), findsOneWidget);
  });

  testWidgets('clearing the email saves it as empty', (tester) async {
    final b = backend();
    await pumpScreen(tester, screen, backend: b);
    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-edit-email')), 'a@b.uz');
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-edit-done')));
    await settle(tester);
    expect(find.text('a@b.uz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-edit-email')), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-edit-done')));
    await settle(tester);
    final put = b.requests.lastWhere((r) => r.method == 'PUT');
    expect(jsonDecode(put.body)['email'], isNull);
    expect(find.text('Добавить email'), findsOneWidget);
  });

  testWidgets('logout asks for confirmation', (tester) async {
    await pumpScreen(tester, screen, backend: backend());
    await tester.scrollUntilVisible(find.text('Fitness Formula · версия 1.0.0'), 300);
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsNothing);
  });
}
