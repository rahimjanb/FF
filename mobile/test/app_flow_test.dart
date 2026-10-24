import 'package:fitness_formulasi/app.dart';
import 'package:fitness_formulasi/core/api_client.dart';
import 'package:fitness_formulasi/core/token_storage.dart';
import 'package:fitness_formulasi/data/repositories.dart';
import 'package:fitness_formulasi/state/locale_controller.dart';
import 'package:fitness_formulasi/state/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_backend.dart';

Future<FakeBackend> pumpApp(WidgetTester tester, {String role = 'Client', bool mustChangePassword = false}) async {
  final backend = FakeBackend()
    ..role = role
    ..mustChangePassword = mustChangePassword;
  final api = ApiClient(baseUrl: 'http://test', tokens: MemoryTokenStorage(), httpClient: backend.client);
  final session = SessionController(AuthRepository(api), api);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController()),
        ChangeNotifierProvider.value(value: session),
        Provider.value(value: ClientRepository(api)),
        Provider.value(value: TrainerRepository(api)),
        Provider.value(value: NotificationRepository(api)),
      ],
      child: const FitnessApp(),
    ),
  );
  await tester.runAsync(session.restore);
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  testWidgets('shows login when there is no session and validates the form', (tester) async {
    await pumpApp(tester);
    expect(find.text('С возвращением'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Введите номер в формате +998 90 123 45 67'), findsOneWidget);
    expect(find.text('Обязательное поле'), findsOneWidget);
  });

  testWidgets('wrong password shows a localized error', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '+998901234567');
    await tester.enterText(find.byType(TextFormField).at(1), 'Wrong1234');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Неверный номер или пароль'), findsOneWidget);
  });

  testWidgets('client logs in and sees real dashboard data', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '90 123 45 67');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aziz'), findsWidgets);
    expect(find.text('Gold 30'), findsOneWidget);
    expect(find.text('Активен'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('17'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('17'), findsOneWidget); // total visits
    expect(find.text('Главная'), findsOneWidget); // bottom navigation
  });

  testWidgets('switching to Uzbek translates the login screen', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('UZ'));
    await tester.pumpAndSettle();
    expect(find.text('Xush kelibsiz'), findsOneWidget);
  });

  testWidgets('temporary password: forced change screen, then dashboard', (tester) async {
    final backend = await pumpApp(tester, mustChangePassword: true);
    await tester.enterText(find.byType(TextFormField).at(0), '+998901234567');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Придумайте свой пароль'), findsOneWidget);

    // Same password as the temporary one is rejected on the client before any request.
    await tester.enterText(find.byType(TextFormField).at(0), 'Secret123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.enterText(find.byType(TextFormField).at(2), 'Secret123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Новый пароль должен отличаться от текущего'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'MyOwn12345');
    await tester.enterText(find.byType(TextFormField).at(2), 'MyOwn12345');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(backend.password, 'MyOwn12345');
    expect(find.text('Gold 30'), findsOneWidget);
  });
}
