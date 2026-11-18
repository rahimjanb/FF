import 'dart:convert';

import 'package:fitness_formulasi/app.dart';
import 'package:fitness_formulasi/core/api_client.dart';
import 'package:fitness_formulasi/core/token_storage.dart';
import 'package:fitness_formulasi/data/nutrition_repository.dart';
import 'package:fitness_formulasi/data/repositories.dart';
import 'package:fitness_formulasi/state/locale_controller.dart';
import 'package:fitness_formulasi/state/session.dart';
import 'package:fitness_formulasi/ui/client/profile_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'fake_backend.dart';
import 'screen_harness.dart';

const _deleteButton = Key('profile-delete-account');
const _password = Key('delete-account-password');
const _confirm = Key('delete-account-confirm');

FakeBackend _backend() =>
    FakeBackend()..routes['/api/me/profile'] = (_) => {...profileJson(withTrainer: false), 'memberSince': null};

/// The whole app signed in as a client and opened on the Profile tab.
Future<FakeBackend> _pumpAppOnProfile(WidgetTester tester) async {
  final backend = _backend();
  final api = ApiClient(baseUrl: 'http://test', tokens: MemoryTokenStorage(), httpClient: backend.client);
  final session = SessionController(AuthRepository(api), api);
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController()),
        ChangeNotifierProvider.value(value: session),
        Provider.value(value: ClientRepository(api)),
        Provider.value(value: TrainerRepository(api)),
        Provider.value(value: NotificationRepository(api)),
        Provider.value(value: NutritionRepository(api)),
      ],
      child: const FitnessApp(),
    ),
  );
  await tester.runAsync(() => session.login('+998901234567', 'Secret123'));
  await settle(tester);
  await tester.tap(find.text('Профиль'));
  await settle(tester);
  return backend;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(_deleteButton), 300, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.byKey(_deleteButton));
  await tester.pumpAndSettle();
}

bool _confirmEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(_confirm)).onPressed != null;

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Fitness Formula',
      packageName: 'uz.ff',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  testWidgets('client profile offers deletion; the sheet explains it and needs the password', (tester) async {
    await pumpScreen(tester, const Scaffold(body: ProfileScreen()), backend: _backend());
    await _openSheet(tester);

    expect(find.text('Удалить аккаунт?'), findsOneWidget);
    expect(find.textContaining('фото лица будут удалены'), findsOneWidget);
    expect(find.textContaining('сгорят'), findsOneWidget);
    expect(find.textContaining('без вашего имени'), findsOneWidget);
    expect(find.textContaining('Отменить удаление нельзя'), findsOneWidget);
    expect(_confirmEnabled(tester), isFalse);

    await tester.enterText(find.byKey(_password), 'x');
    await tester.pump();
    expect(_confirmEnabled(tester), isTrue);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить аккаунт?'), findsNothing);
  });

  testWidgets('trainer profile has no account deletion: the club manages trainer accounts', (tester) async {
    final b = FakeBackend()
      ..routes['/api/trainer/profile'] = (_) => {
        'firstName': 'Dilshod',
        'lastName': 'Rakhimov',
        'phone': '+998901112233',
        'specialization': null,
        'bio': null,
        'experienceYears': null,
        'isAcceptingClients': true,
        'clientsCount': 0,
        'photoUrl': null,
      };
    await pumpScreen(tester, const TrainerProfileScreen(), role: 'Trainer', backend: b);
    expect(find.text('Dilshod Rakhimov'), findsWidgets);
    expect(find.byKey(_deleteButton), findsNothing);
    expect(find.text('Удалить аккаунт'), findsNothing);
  });

  testWidgets('wrong password keeps the sheet open with an inline error', (tester) async {
    final b = await _pumpAppOnProfile(tester);
    await _openSheet(tester);

    await tester.enterText(find.byKey(_password), 'Wrong1234');
    await tester.pump();
    await tester.tap(find.byKey(_confirm));
    await settle(tester);

    expect(find.text('Неверный пароль'), findsOneWidget);
    expect(find.text('Удалить аккаунт?'), findsOneWidget);
    expect(b.accountDeleted, isFalse);

    // Typing again clears the error.
    await tester.enterText(find.byKey(_password), 'Wrong12345');
    await tester.pump();
    expect(find.text('Неверный пароль'), findsNothing);
  });

  testWidgets('deleting the account signs out to the login screen with a confirmation', (tester) async {
    final b = await _pumpAppOnProfile(tester);
    await _openSheet(tester);

    await tester.enterText(find.byKey(_password), 'Secret123');
    await tester.pump();
    await tester.tap(find.byKey(_confirm));
    await settle(tester);

    final call = b.requests.singleWhere((r) => r.url.path == '/api/me/delete-account');
    expect(call.method, 'POST');
    expect(jsonDecode(call.body), {'password': 'Secret123'});
    expect(b.accountDeleted, isTrue);
    // Sessions are revoked by the server; the app does not call logout.
    expect(b.requests.where((r) => r.url.path == '/api/auth/logout'), isEmpty);

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.text('Удалить аккаунт?'), findsNothing);
    expect(find.text('Аккаунт удалён'), findsOneWidget);
  });
}
