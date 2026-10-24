import 'dart:convert';

import 'package:fitness_formulasi/ui/client/trainers_screen.dart';
import 'package:fitness_formulasi/ui/client/workouts_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_requests_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_schedule_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart';
import 'screen_harness.dart';

void main() {
  final now = DateTime.now();

  group('Client workouts screen', () {
    FakeBackend backendWith({
      List<Map<String, dynamic>> upcoming = const [],
      List<Map<String, dynamic>> history = const [],
      bool withTrainer = true,
      String membershipStatus = 'Active',
    }) {
      final b = FakeBackend();
      b.routes['/api/me/training-sessions'] = (req) =>
          paged(req.url.queryParameters['scope'] == 'History' ? history : upcoming);
      b.routes['/api/me/profile'] = (_) => profileJson(withTrainer: withTrainer);
      b.routes['/api/me/memberships'] = (_) =>
          membershipStatus.isEmpty ? <Object>[] : [FakeBackend.membership(status: membershipStatus)];
      return b;
    }

    testWidgets('shows trainer, upcoming sessions and history with statuses', (tester) async {
      final b = backendWith(
        upcoming: [session('s1', now.add(const Duration(days: 1)), notes: 'Ноги')],
        history: [
          session('s2', now.subtract(const Duration(days: 1)), status: 'Completed'),
          session('s3', now.subtract(const Duration(days: 2))), // ended, not marked
          session('s4', now.add(const Duration(days: 3)), status: 'Cancelled'),
        ],
      );
      await pumpScreen(tester, const WorkoutsScreen(), backend: b);

      expect(find.text('Dilshod Rashidov'), findsOneWidget);
      expect(find.text('Предстоящие'), findsOneWidget);
      expect(find.text('Завтра'), findsOneWidget);
      expect(find.text('Ноги'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
      expect(find.text('Проведена'), findsOneWidget);
      expect(find.text('Прошла'), findsOneWidget);
      expect(find.text('Отменена'), findsOneWidget);
      expect(find.byKey(const Key('membership-warning')), findsNothing);
      // Clients cannot act on sessions.
      expect(find.text('Нажмите, чтобы отметить результат'), findsNothing);
    });

    testWidgets('empty schedule without trainer and membership explains what to do', (tester) async {
      final b = backendWith(withTrainer: false, membershipStatus: 'Expired');
      int? navigatedTo;
      await pumpScreen(tester, WorkoutsScreen(onNavigate: (i) => navigatedTo = i), backend: b);

      expect(find.text('Запланированных тренировок нет'), findsOneWidget);
      expect(find.text('Выберите тренера — он сможет назначать вам тренировки'), findsOneWidget);
      expect(find.byKey(const Key('membership-warning')), findsOneWidget);
      expect(find.text('История'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Выбрать тренера'));
      expect(navigatedTo, WorkoutsScreen.trainersTab);
    });

    testWidgets('no membership at all shows the warning', (tester) async {
      await pumpScreen(tester, const WorkoutsScreen(), backend: backendWith(membershipStatus: ''));
      expect(find.byKey(const Key('membership-warning')), findsOneWidget);
    });

    testWidgets('API error shows retry, retry loads data', (tester) async {
      final b = backendWith(upcoming: [session('s1', now.add(const Duration(days: 1)))]);
      final ok = b.routes['/api/me/training-sessions']!;
      b.routes['/api/me/training-sessions'] = (_) => http.Response('{"code":"internal_error","title":"x"}', 500);
      await pumpScreen(tester, const WorkoutsScreen(), backend: b);

      expect(find.text('Что-то пошло не так. Попробуйте ещё раз.'), findsOneWidget);
      b.routes['/api/me/training-sessions'] = ok;
      await tester.tap(find.text('Повторить'));
      await settle(tester);
      expect(find.text('Завтра'), findsOneWidget);
    });

    testWidgets('data is reloaded when the app returns to the foreground', (tester) async {
      final upcoming = <Map<String, dynamic>>[];
      final b = backendWith();
      b.routes['/api/me/training-sessions'] = (req) =>
          paged(req.url.queryParameters['scope'] == 'History' ? [] : upcoming);
      await pumpScreen(tester, const WorkoutsScreen(), backend: b);
      expect(find.text('Запланированных тренировок нет'), findsOneWidget);

      // Trainer scheduled a session while the app was in the background.
      upcoming.add(session('s9', now.add(const Duration(days: 1))));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(find.text('Завтра'), findsOneWidget);
    });
  });

  group('Trainer schedule screen', () {
    testWidgets('splits upcoming and last week; unmarked past sessions are actionable', (tester) async {
      final b = FakeBackend();
      b.routes['/api/trainer/sessions'] = (_) => [
        session('p1', now.subtract(const Duration(days: 2)), client: 'Bobur'),
        session('u1', now.add(const Duration(days: 1)), client: 'Aziz'),
      ];
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);

      expect(find.text('Предстоящие'), findsOneWidget);
      expect(find.text('Прошедшие за 7 дней'), findsOneWidget);
      expect(find.text('Клиент: Aziz Karimov'), findsOneWidget);
      expect(find.text('Клиент: Bobur Karimov'), findsOneWidget);
      expect(find.text('Нажмите, чтобы отметить результат'), findsOneWidget);
    });

    /// Stateful fake schedule: status endpoints change the stored session, like the real API.
    FakeBackend scheduleBackend(List<Map<String, dynamic>> sessions) {
      final b = FakeBackend();
      b.routes['/api/trainer/sessions'] = (_) => sessions;
      for (final s in sessions) {
        for (final action in ['complete', 'cancel']) {
          b.routes['/api/trainer/sessions/${s['id']}/$action'] = (req) {
            expect(req.method, 'POST');
            s['status'] = action == 'complete' ? 'Completed' : 'Cancelled';
            return {...s};
          };
        }
      }
      return b;
    }

    testWidgets('marking a past session completed updates the list', (tester) async {
      final b = scheduleBackend([session('p1', now.subtract(const Duration(days: 1)), client: 'Bobur')]);
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);
      expect(find.text('Прошла'), findsOneWidget);

      await tester.tap(find.text('Клиент: Bobur Karimov'));
      await settle(tester);
      expect(find.byKey(const Key('session-complete')), findsOneWidget);
      expect(find.byKey(const Key('session-cancel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('session-complete')));
      await settle(tester);

      expect(b.calls['/api/trainer/sessions/p1/complete'], 1);
      expect(b.calls['/api/trainer/sessions'], 2, reason: 'the list is reloaded after the change');
      expect(find.text('Тренировка отмечена проведённой'), findsOneWidget);
      expect(find.text('Проведена'), findsOneWidget);
      expect(find.text('Нажмите, чтобы отметить результат'), findsNothing);

      // A marked session is final: tapping it opens no actions.
      await tester.tap(find.text('Клиент: Bobur Karimov'));
      await settle(tester);
      expect(find.byKey(const Key('session-cancel')), findsNothing);
    });

    testWidgets('cancelling asks for confirmation; future sessions cannot be completed', (tester) async {
      final b = scheduleBackend([session('u1', now.add(const Duration(days: 1)))]);
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);

      await tester.tap(find.text('Клиент: Aziz Karimov'));
      await settle(tester);
      expect(find.byKey(const Key('session-complete')), findsNothing);
      await tester.tap(find.byKey(const Key('session-cancel')));
      await settle(tester);
      expect(find.text('Отменить тренировку?'), findsOneWidget);
      await tester.tap(find.text('Не отменять'));
      await settle(tester);
      expect(b.calls['/api/trainer/sessions/u1/cancel'], isNull);

      await tester.tap(find.text('Клиент: Aziz Karimov'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('session-cancel')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('session-cancel-confirm')));
      await settle(tester);

      expect(b.calls['/api/trainer/sessions/u1/cancel'], 1);
      expect(find.text('Тренировка отменена'), findsOneWidget);
      expect(find.text('Отменена'), findsOneWidget);
    });

    testWidgets('status change errors are explained and the list is refreshed', (tester) async {
      final b = scheduleBackend([
        session('p1', now.subtract(const Duration(days: 1)), client: 'Bobur'),
        session('p2', now.subtract(const Duration(days: 2)), client: 'Kamola'),
      ]);
      Object problem(int status, String code) => http.Response(
        '{"code":"$code","title":"x","status":$status}',
        status,
        headers: {'content-type': 'application/json'},
      );
      // Already marked elsewhere (e.g. a second device), and no longer accessible (client moved to another trainer).
      b.routes['/api/trainer/sessions/p1/complete'] = (_) => problem(409, 'session_not_scheduled');
      b.routes['/api/trainer/sessions/p2/complete'] = (_) => problem(404, 'not_found');
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);

      await tester.tap(find.text('Клиент: Bobur Karimov'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('session-complete')));
      await settle(tester);
      expect(find.text('Тренировка уже отмечена или отменена'), findsOneWidget);
      expect(b.calls['/api/trainer/sessions'], 2);

      await tester.tap(find.text('Клиент: Kamola Karimov'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('session-complete')));
      await settle(tester);
      expect(find.text('Запись не найдена или недоступна'), findsOneWidget);
      expect(b.calls['/api/trainer/sessions'], 3);
    });

    testWidgets('empty schedule and error with retry', (tester) async {
      final b = FakeBackend();
      b.routes['/api/trainer/sessions'] = (_) => http.Response('{"code":"internal_error","title":"x"}', 500);
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);
      expect(find.text('Повторить'), findsOneWidget);

      b.routes['/api/trainer/sessions'] = (_) => <Object>[];
      await tester.tap(find.text('Повторить'));
      await settle(tester);
      expect(find.text('На ближайшие 30 дней тренировок нет'), findsOneWidget);
      expect(find.text('Прошедшие за 7 дней'), findsNothing);
    });

    testWidgets('new session warns when the client has no usable membership', (tester) async {
      final b = FakeBackend();
      b.routes['/api/trainer/sessions'] = (_) => <Object>[];
      b.routes['/api/trainer/clients'] = (_) => paged([
        {
          'id': 'c1',
          'firstName': 'Aziz',
          'lastName': 'Karimov',
          'phone': '+998901234567',
          'birthDate': null,
          'currentMembership': FakeBackend.membership(status: 'Expired'),
          'lastVisitAt': null,
        },
      ]);
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);

      await tester.tap(find.text('Новая тренировка'));
      await settle(tester);
      expect(find.byKey(const Key('client-membership-warning')), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aziz Karimov').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('client-membership-warning')), findsOneWidget);
      // Warning only: creating is still allowed (business rule to be agreed).
      final create = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Создать'));
      expect(create.onPressed, isNotNull);
    });

    testWidgets('schedule reloads when the app returns to the foreground', (tester) async {
      final b = FakeBackend();
      b.routes['/api/trainer/sessions'] = (_) => <Object>[];
      await pumpScreen(tester, const TrainerScheduleScreen(), role: 'Trainer', backend: b);
      expect(b.calls['/api/trainer/sessions'], 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(b.calls['/api/trainer/sessions'], 2);
    });

    testWidgets('after accepting a request the clients tab shows the new client', (tester) async {
      final b = FakeBackend();
      var accepted = false;
      final request = {
        'id': 'r1',
        'status': 'Pending',
        'message': 'Хочу заниматься',
        'responseComment': null,
        'createdAt': now.toUtc().toIso8601String(),
        'respondedAt': null,
        'trainer': {'id': 't1', 'firstName': 'Dilshod', 'lastName': 'Rashidov'},
        'client': {'id': 'c1', 'firstName': 'Aziz', 'lastName': 'Karimov'},
      };
      b.routes['/api/trainer/requests'] = (req) {
        final current = {...request, 'status': accepted ? 'Accepted' : 'Pending'};
        final filter = req.url.queryParameters['status'];
        return paged([
          if (filter == null || filter.toLowerCase() == (current['status'] as String).toLowerCase()) current,
        ]);
      };
      b.routes['/api/trainer/requests/r1/accept'] = (_) {
        accepted = true;
        return {...request, 'status': 'Accepted'};
      };
      b.routes['/api/trainer/clients'] = (_) => paged(
        accepted
            ? [
                {
                  'id': 'c1',
                  'firstName': 'Aziz',
                  'lastName': 'Karimov',
                  'phone': '+998901234567',
                  'birthDate': null,
                  'currentMembership': FakeBackend.membership(),
                  'lastVisitAt': null,
                },
              ]
            : [],
      );
      b.routes['/api/trainer/sessions'] = (_) => <Object>[];
      b.routes['/api/trainer/profile'] = (_) => {
        'id': 't1',
        'userId': 'u1',
        'phone': '+998900000002',
        'firstName': 'Dilshod',
        'lastName': 'Rashidov',
        'specialization': null,
        'bio': null,
        'experienceYears': null,
        'isAcceptingClients': true,
        'isActive': true,
        'userStatus': 'Active',
        'clientsCount': accepted ? 1 : 0,
        'createdAt': now.toUtc().toIso8601String(),
      };
      await pumpScreen(tester, const TrainerShell(), role: 'Trainer', backend: b);

      // Clients tab before accepting: empty.
      await tester.tap(find.text('Клиенты'));
      await settle(tester);
      expect(find.text('Закреплённых клиентов пока нет'), findsOneWidget);

      await tester.tap(find.text('Заявки'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Принять'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await settle(tester);
      expect(find.text('Принята'), findsWidgets);

      await tester.tap(find.text('Клиенты'));
      await settle(tester);
      expect(find.text('Aziz Karimov'), findsOneWidget);
      expect(find.text('Закреплённых клиентов пока нет'), findsNothing);
    });
  });

  testWidgets('trainer list puts the pending request on top even in a long list', (tester) async {
    final b = FakeBackend();
    b.routes['/api/trainers'] = (_) => [
      for (var i = 0; i < 30; i++) {...trainerJson(), 'id': 't$i', 'firstName': 'Trainer', 'lastName': '$i'},
    ];
    b.routes['/api/me/trainer-requests'] = (_) => [
      {
        'id': 'r1',
        'status': 'Pending',
        'message': null,
        'responseComment': null,
        'createdAt': now.toUtc().toIso8601String(),
        'respondedAt': null,
        'trainer': {'id': 't29', 'firstName': 'Trainer', 'lastName': '29'},
        'client': {'id': 'c1', 'firstName': 'Aziz', 'lastName': 'Karimov'},
      },
    ];
    b.routes['/api/me/profile'] = (_) => profileJson(withTrainer: false);
    await pumpScreen(tester, const TrainersScreen(), backend: b);

    // Visible without scrolling: the first tile is the trainer the client is waiting for.
    expect(find.text('Trainer 29').hitTestable(), findsOneWidget);
    expect(find.text('На рассмотрении').hitTestable(), findsOneWidget);
  });

  testWidgets('Android Back on another tab returns to the first tab instead of leaving the app', (tester) async {
    final b = FakeBackend();
    b.routes['/api/trainer/requests'] = (_) => paged(const []);
    b.routes['/api/trainer/sessions'] = (_) => <Object>[];
    await pumpScreen(tester, const TrainerShell(), role: 'Trainer', backend: b);

    await tester.tap(find.text('Расписание').last);
    await settle(tester);
    expect(find.text('Новая тренировка').hitTestable(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Входящие заявки').hitTestable(), findsOneWidget);
    expect(find.text('Новая тренировка').hitTestable(), findsNothing);
  });

  testWidgets('responding to a request: comment is sent and the dialog closes without errors', (tester) async {
    final b = FakeBackend();
    var status = 'Pending';
    String? sentComment;
    b.routes['/api/trainer/requests'] = (_) => paged([
      {
        'id': 'r1',
        'status': status,
        'message': 'Хочу заниматься',
        'responseComment': null,
        'createdAt': now.toUtc().toIso8601String(),
        'respondedAt': null,
        'trainer': {'id': 't1', 'firstName': 'Dilshod', 'lastName': 'Rashidov'},
        'client': {'id': 'c1', 'firstName': 'Aziz', 'lastName': 'Karimov'},
      },
    ]);
    b.routes['/api/trainer/requests/r1/reject'] = (req) {
      sentComment = (jsonDecode(req.body) as Map<String, dynamic>)['comment'] as String?;
      status = 'Rejected';
      return <String, dynamic>{};
    };
    await pumpScreen(tester, const TrainerRequestsScreen(), role: 'Trainer', backend: b);

    // Cancel: nothing is sent; step through the closing animation frame by frame.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить').first.hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'черновик');
    await tester.tap(find.text('Отмена'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(b.calls['/api/trainer/requests/r1/reject'], isNull);

    // Confirm with a comment.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить').first.hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Нет свободных мест  ');
    await tester.tap(find.text('Подтвердить'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(sentComment, 'Нет свободных мест');
    expect(find.text('Отклонена'), findsWidgets);
  });
}
