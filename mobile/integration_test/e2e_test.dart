// End-to-end check against a REAL running backend (no fakes).
// Run on a simulator/emulator with dev accounts passed via --dart-define, see docs/TESTING.md:
//   flutter test integration_test -d <device> \
//     --dart-define=E2E_CLIENT_PHONE=... --dart-define=E2E_CLIENT_PASSWORD=... \
//     --dart-define=E2E_TRAINER_PHONE=... --dart-define=E2E_TRAINER_PASSWORD=...
import 'package:fitness_formulasi/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const clientPhone = String.fromEnvironment('E2E_CLIENT_PHONE');
const clientPassword = String.fromEnvironment('E2E_CLIENT_PASSWORD');
const trainerPhone = String.fromEnvironment('E2E_TRAINER_PHONE');
const trainerPassword = String.fromEnvironment('E2E_TRAINER_PASSWORD');
const pauseSeconds = int.fromEnvironment('E2E_PAUSE_SECONDS', defaultValue: 0);
// Used when an account still has a temporary password set by staff (forced change screen).
const newPassword = String.fromEnvironment('E2E_NEW_PASSWORD', defaultValue: 'MyOwn12345');

Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [found] holds or [seconds] pass; slow first runs (e.g. a fresh emulator) need more than a fixed delay.
Future<void> waitFor(WidgetTester tester, bool Function() found, {int seconds = 15}) async {
  for (var i = 0; i < seconds * 10 && !found(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pause(WidgetTester tester) => settle(tester, pauseSeconds);

Future<void> login(WidgetTester tester, String phone, String password) async {
  await tester.enterText(find.byType(TextFormField).at(0), phone);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
  await settle(tester, 4);
  if (find.text('Придумайте свой пароль').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextFormField).at(0), password);
    await tester.enterText(find.byType(TextFormField).at(1), newPassword);
    await tester.enterText(find.byType(TextFormField).at(2), newPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await settle(tester, 4);
  }
}

Future<void> logout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('appbar-logout')).hitTestable());
  await settle(tester);
  await tester.tap(find.byKey(const Key('logout-confirm')));
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client sees membership; trainer accepts request and sees the client', (tester) async {
    expect(clientPhone, isNotEmpty, reason: 'Pass E2E_* values via --dart-define');
    app.main();
    await settle(tester, 4);

    // Signed out from a previous run if a session exists.
    if (find.text('С возвращением').evaluate().isEmpty) {
      await tester.tap(find.text('Профиль').last);
      await settle(tester);
      await logout(tester);
    }

    await login(tester, clientPhone, clientPassword);
    expect(find.text('Активен'), findsWidgets);
    await pause(tester);

    await tester.tap(find.text('Тренеры').last);
    // Repeatable: first run shows the pending request, later runs show the assigned trainer.
    bool requestOrTrainer() =>
        find.text('На рассмотрении').evaluate().isNotEmpty || find.text('Ваш тренер').evaluate().isNotEmpty;
    await waitFor(tester, requestOrTrainer);
    expect(requestOrTrainer(), isTrue);
    await pause(tester);

    await tester.tap(find.text('Профиль').last);
    await settle(tester, 3);
    await logout(tester);

    await login(tester, trainerPhone, trainerPassword);
    expect(find.text('Входящие заявки'), findsOneWidget);
    await pause(tester);
    await waitFor(tester, () => find.text('Принять').evaluate().isNotEmpty || find.text('Принята').evaluate().isNotEmpty);
    if (find.widgetWithText(FilledButton, 'Принять').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(FilledButton, 'Принять').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await settle(tester, 3);
    }
    expect(find.text('Принята'), findsWidgets);

    await tester.tap(find.text('Клиенты').last);
    await settle(tester, 3);
    expect(find.text('Тест Клиент'), findsOneWidget);
    await pause(tester);

    // Trainer schedules a session for tomorrow (default date/time of the form) for the new client.
    await tester.tap(find.text('Расписание').last);
    await settle(tester, 3);
    await tester.tap(find.text('Новая тренировка'));
    await settle(tester, 3);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Тест Клиент').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await settle(tester, 4);
    expect(find.text('Завтра'), findsWidgets);
    await pause(tester);

    await tester.tap(find.text('Профиль').last);
    await settle(tester, 3);
    await logout(tester);

    // Client sees the session and the assigned trainer on the Workouts tab.
    await login(tester, clientPhone, clientPassword);
    await tester.tap(find.text('Тренировки').last);
    await settle(tester, 4);
    expect(find.text('Завтра'), findsWidgets);
    expect(find.text('Ваш тренер'), findsWidgets);
    expect(find.byKey(const Key('membership-warning')), findsNothing);
    await pause(tester);

    await tester.tap(find.text('Профиль').last);
    await settle(tester, 3);
    await logout(tester);
  });
}
