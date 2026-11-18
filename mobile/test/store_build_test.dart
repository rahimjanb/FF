import 'package:fitness_formulasi/core/config.dart';
import 'package:fitness_formulasi/ui/client/membership_screen.dart';
import 'package:fitness_formulasi/ui/client/profile_screen.dart';
import 'package:fitness_formulasi/ui/client/trainers_screen.dart';
import 'package:fitness_formulasi/ui/client/workouts_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fake_backend.dart';
import 'screen_harness.dart';

/// App Store and Google Play: a privacy policy link in the app, and nothing that only says «скоро».
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

  /// Signed-in client; [sessions] are the upcoming training sessions.
  FakeBackend client({bool withTrainer = true, List<Map<String, dynamic>> sessions = const []}) {
    final b = FakeBackend();
    b.routes['/api/me/profile'] = (_) => profileJson(withTrainer: withTrainer);
    b.routes['/api/me/training-sessions'] = (req) =>
        paged(req.url.queryParameters['scope'] == 'History' ? <Map<String, dynamic>>[] : sessions);
    b.routes['/api/me/trainer-requests'] = (_) => <Object>[];
    b.routes['/api/trainers'] = (_) => [
      {
        'id': 't1',
        'firstName': 'Dilshod',
        'lastName': 'Rashidov',
        'specialization': 'Силовые',
        'bio': null,
        'experienceYears': 5,
        'isAcceptingClients': true,
        'photoUrl': null,
      },
    ];
    return b;
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }

  group('privacy policy link', () {
    testWidgets('client profile opens the policy in the browser', (tester) async {
      final urls = captureLaunchedUrls(tester);
      await pumpScreen(tester, const Scaffold(body: ProfileScreen()), backend: client());
      await tapVisible(tester, find.byKey(const Key('open-privacy-policy')));
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(urls, [AppConfig.privacyPolicyUrl]);
    });

    testWidgets('trainer profile opens the policy in the browser', (tester) async {
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
      final urls = captureLaunchedUrls(tester);
      await pumpScreen(tester, const TrainerProfileScreen(), role: 'Trainer', backend: b);
      await tapVisible(tester, find.byKey(const Key('open-privacy-policy')));
      expect(urls, [AppConfig.privacyPolicyUrl]);
    });

    testWidgets('a link that cannot be opened is explained', (tester) async {
      // No url_launcher answers in tests, so nothing opens.
      await pumpScreen(tester, const Scaffold(body: ProfileScreen()), backend: client());
      await tapVisible(tester, find.byKey(const Key('open-privacy-policy')));
      expect(find.text('Не удалось открыть ссылку'), findsOneWidget);
    });
  });

  group('store build hides features that are not built yet', () {
    setUp(() => AppConfig.showUpcomingOverride = false);
    tearDown(() => AppConfig.showUpcomingOverride = null);

    testWidgets('profile: only working settings, no camera button on the avatar', (tester) async {
      await pumpScreen(tester, const Scaffold(body: ProfileScreen()), backend: client());
      await tester.scrollUntilVisible(find.byKey(const Key('profile-logout')), 300);

      for (final stub in ['Уведомления', 'Вход по Face ID', 'Поддержка', 'Правила клуба', 'скоро']) {
        expect(find.text(stub), findsNothing, reason: stub);
      }
      expect(find.byTooltip('Сменить фото'), findsNothing);
      expect(find.byKey(const Key('open-change-password')), findsOneWidget);
      expect(find.byKey(const Key('open-privacy-policy')), findsOneWidget);
    });

    testWidgets('membership: freeze and renewal only, no menu of unpublished documents', (tester) async {
      await pumpScreen(tester, const Scaffold(body: MembershipScreen()), backend: client());

      expect(find.byKey(const Key('action-freeze')), findsOneWidget);
      expect(find.byKey(const Key('action-renew')), findsOneWidget);
      expect(find.byKey(const Key('action-guest')), findsNothing);
      expect(find.byTooltip('Ещё'), findsNothing);
      expect(find.text('скоро'), findsNothing);
    });

    testWidgets('plans: payment at the desk is stated, not offered as a button', (tester) async {
      final b = client()..routes['/api/me/memberships'] = (_) => <Object>[];
      await pumpScreen(tester, const Scaffold(body: MembershipScreen()), backend: b);

      await tester.scrollUntilVisible(find.text('Оплата на ресепшене'), 200);
      await tester.tap(find.text('Оплата на ресепшене'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Онлайн-оплата скоро'), findsNothing);
    });

    testWidgets('workouts with a trainer: no chat, calendar, booking or session actions that do nothing', (
      tester,
    ) async {
      final b = client(sessions: [session('s1', DateTime.now().add(const Duration(days: 1)), notes: 'Ноги')]);
      await pumpScreen(
        tester,
        Scaffold(body: WorkoutsScreen(onNavigate: (_) {})),
        backend: b,
      );

      expect(find.text('Ваш тренер'), findsOneWidget);
      expect(find.byKey(const Key('next-session')), findsOneWidget);
      expect(find.byKey(const Key('trainer-chat')), findsNothing);
      expect(find.byTooltip('Календарь'), findsNothing);
      expect(find.byKey(const Key('next-session-reschedule')), findsNothing);
      expect(find.byKey(const Key('next-session-cancel')), findsNothing);
      expect(find.byKey(const Key('book-workout')), findsNothing); // the trainer schedules sessions
      expect(find.text('скоро'), findsNothing);
    });

    testWidgets('workouts without a trainer still lead to choosing one', (tester) async {
      int? navigatedTo;
      await pumpScreen(
        tester,
        Scaffold(body: WorkoutsScreen(onNavigate: (i) => navigatedTo = i)),
        backend: client(withTrainer: false),
      );

      await tapVisible(tester, find.byKey(const Key('book-workout')));
      expect(navigatedTo, WorkoutsScreen.trainersTab);
    });

    testWidgets('own trainer card: booking without the chat button', (tester) async {
      int? navigatedTo;
      await pumpScreen(
        tester,
        Scaffold(body: TrainersScreen(onNavigate: (i) => navigatedTo = i)),
        backend: client(),
      );

      expect(find.byKey(const Key('my-trainer')), findsOneWidget);
      expect(find.byKey(const Key('my-trainer-chat')), findsNothing);
      await tester.tap(find.byKey(const Key('my-trainer-book')));
      expect(navigatedTo, TrainersScreen.workoutsTab);
    });
  });
}
