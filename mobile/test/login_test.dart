import 'package:fitness_formulasi/app.dart';
import 'package:fitness_formulasi/core/api_client.dart';
import 'package:fitness_formulasi/core/config.dart';
import 'package:fitness_formulasi/core/token_storage.dart';
import 'package:fitness_formulasi/data/nutrition_repository.dart';
import 'package:fitness_formulasi/data/repositories.dart';
import 'package:fitness_formulasi/state/locale_controller.dart';
import 'package:fitness_formulasi/state/login_history.dart';
import 'package:fitness_formulasi/state/session.dart';
import 'package:fitness_formulasi/ui/auth/login_screen.dart';
import 'package:fitness_formulasi/ui/auth/register_screen.dart';
import 'package:fitness_formulasi/ui/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_backend.dart';
import 'screen_harness.dart' show captureLaunchedUrls;

const _phone = Key('login-phone');
const _password = Key('login-password');
const _submit = Key('login-submit');

/// Signed-out app on an iPhone 15 sized screen (or [size] / [dpr]) with the home indicator inset.
Future<FakeBackend> pumpLogin(WidgetTester tester, {Size size = const Size(1179, 2556), double dpr = 3}) async {
  final backend = FakeBackend();
  final api = ApiClient(baseUrl: 'http://test', tokens: MemoryTokenStorage(), httpClient: backend.client);
  final session = SessionController(AuthRepository(api), api);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(top: 47 * dpr, bottom: 34 * dpr);
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
  await tester.runAsync(session.restore);
  await tester.pumpAndSettle();
  return backend;
}

String fieldText(WidgetTester tester, Key key) => tester.widget<TextField>(find.byKey(key)).controller!.text;

bool submitEnabled(WidgetTester tester) => tester.widget<GradientPillButton>(find.byKey(_submit)).onPressed != null;

void main() {
  setUp(() {
    LoginHistory.lastLogin = () async => null;
    LoginHistory.biometricsAvailable = () async => false;
  });

  testWidgets('first visit: logo, club caption, +998 field; no Face ID; sign in is off until both fields are filled', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Клубное приложение'), findsOneWidget);
    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.text('+998'), findsOneWidget);
    expect(find.text('Нет аккаунта?'), findsOneWidget);
    expect(find.byKey(const Key('face-id')), findsNothing, reason: 'nobody has signed in on this device yet');
    expect(find.text('или'), findsNothing);

    expect(submitEnabled(tester), isFalse);
    await tester.enterText(find.byKey(_phone), '90 123 45 67');
    await tester.pump();
    expect(submitEnabled(tester), isFalse);
    await tester.enterText(find.byKey(_password), 'Secret123');
    await tester.pump();
    expect(submitEnabled(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone mask: groups digits, drops an autofilled +998, a full number moves on to the password', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(_phone), '+998 90 123 45 67');
    await tester.pump();
    expect(fieldText(tester, _phone), '90 123 45 67');
    expect(tester.widget<TextField>(find.byKey(_password)).focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byKey(_phone), '9012345678999');
    await tester.pump();
    expect(fieldText(tester, _phone), '90 123 45 67', reason: 'at most 9 local digits');

    // Backspace right after a space deletes the digit before it instead of getting stuck.
    final edited = UzPhoneFormatter().formatEditUpdate(
      const TextEditingValue(text: '90 123', selection: TextSelection.collapsed(offset: 3)),
      const TextEditingValue(text: '90123', selection: TextSelection.collapsed(offset: 2)),
    );
    expect(edited.text, '91 23');
    expect(edited.selection.baseOffset, 1);
  });

  testWidgets('invalid phone and wrong password show errors under the fields; editing clears them', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(_phone), '123');
    await tester.enterText(find.byKey(_password), 'x');
    await tester.pump();
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(find.text('Введите номер в формате +998 90 123 45 67'), findsOneWidget);

    await tester.enterText(find.byKey(_phone), '901234567');
    await tester.enterText(find.byKey(_password), 'Wrong1234');
    await tester.pump();
    expect(find.text('Введите номер в формате +998 90 123 45 67'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(_submit));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final shaking = tester.getTopLeft(find.text('С возвращением')).dx;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('С возвращением')).dx, isNot(shaking), reason: 'the form shakes and settles');
    expect(find.text('Неверный номер или пароль'), findsOneWidget);

    await tester.enterText(find.byKey(_password), 'Secret12');
    await tester.pump();
    expect(find.text('Неверный номер или пароль'), findsNothing);
  });

  testWidgets('returning user: the last phone is prefilled and Face ID is offered when biometrics are set up', (
    tester,
  ) async {
    LoginHistory.lastLogin = () async => '+998901234567';
    LoginHistory.biometricsAvailable = () async => true;
    await pumpLogin(tester);

    expect(fieldText(tester, _phone), '90 123 45 67');
    expect(find.text('или'), findsOneWidget);
    await tester.tap(find.byKey(const Key('face-id')));
    await tester.pump();
    expect(find.text('Вход по Face ID скоро будет доступен'), findsOneWidget);
  });

  testWidgets('returning user without biometrics gets no Face ID button', (tester) async {
    LoginHistory.lastLogin = () async => '+998901234567';
    await pumpLogin(tester);
    expect(fieldText(tester, _phone), '90 123 45 67');
    expect(find.byKey(const Key('face-id')), findsNothing);
  });

  testWidgets('forgot password explains the reception flow; register opens registration', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot-password-sheet')), findsOneWidget);
    expect(find.textContaining('ресепшн'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-register')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('store build: no Face ID button even with biometrics, it is not built yet', (tester) async {
    AppConfig.showUpcomingOverride = false;
    addTearDown(() => AppConfig.showUpcomingOverride = null);
    LoginHistory.lastLogin = () async => '+998901234567';
    LoginHistory.biometricsAvailable = () async => true;
    await pumpLogin(tester);

    expect(fieldText(tester, _phone), '90 123 45 67');
    expect(find.byKey(const Key('face-id')), findsNothing);
    expect(find.text('или'), findsNothing);
  });

  testWidgets('registration states that signing up accepts the privacy policy, which opens in the browser', (
    tester,
  ) async {
    final urls = captureLaunchedUrls(tester);
    await pumpLogin(tester);
    await tester.tap(find.byKey(const Key('open-register')));
    await tester.pumpAndSettle();

    final consent = find.byKey(const Key('register-privacy-consent'));
    await tester.ensureVisible(consent);
    await tester.pumpAndSettle();
    expect(
      find.text('Регистрируясь, вы соглашаетесь с Политикой конфиденциальности', findRichText: true),
      findsOneWidget,
    );
    await tester.tapOnText(find.textRange.ofSubstring('Политикой конфиденциальности'));
    await tester.pumpAndSettle();
    expect(urls, [AppConfig.privacyPolicyUrl]);
  });

  testWidgets('password eye toggles visibility', (tester) async {
    await pumpLogin(tester);
    bool obscured() => tester.widget<TextField>(find.byKey(_password)).obscureText;
    expect(obscured(), isTrue);
    await tester.tap(find.byKey(const Key('toggle-password')));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('Uzbek on iPhone SE with Face ID and an open keyboard: nothing overflows, fields stay visible', (
    tester,
  ) async {
    LoginHistory.lastLogin = () async => '+998901234567';
    LoginHistory.biometricsAvailable = () async => true;
    await pumpLogin(tester, size: const Size(750, 1334), dpr: 2);
    tester.view.padding = const FakeViewPadding(top: 40);

    await tester.tap(find.text('UZ'));
    await tester.pumpAndSettle();
    expect(find.text('Xush kelibsiz'), findsOneWidget);
    expect(find.text('Ro‘yxatdan o‘ting'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Keyboard (216 pt) is open: the form rises, the hero gives way, the button stays reachable.
    await tester.tap(find.byKey(_password));
    tester.view.viewInsets = const FakeViewPadding(bottom: 216 * 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('open-register')), findsNothing);
    final keyboardTop = 667 - 216.0;

    for (final key in [_phone, _password, _submit]) {
      expect(tester.getRect(find.byKey(key)).bottom, lessThanOrEqualTo(keyboardTop), reason: '$key');
    }

    // Tapping outside the fields hides the keyboard.
    await tester.tapAt(const Offset(40, 120));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.widget is EditableText, isFalse);
  });
}
