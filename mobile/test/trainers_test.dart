import 'dart:convert';

import 'package:fitness_formulasi/ui/client/trainers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart';
import 'screen_harness.dart';

Map<String, dynamic> trainer(
  String id,
  String first,
  String last, {
  String? specialization,
  int? years,
  bool accepting = true,
  String? photoUrl,
}) => {
  'id': id,
  'firstName': first,
  'lastName': last,
  'specialization': specialization,
  'bio': null,
  'experienceYears': years,
  'isAcceptingClients': accepting,
  'photoUrl': photoUrl,
};

void main() {
  final club = [
    trainer('t1', 'Dilshod', 'Rashidov', specialization: 'Силовые', years: 5),
    trainer('t2', 'Alina', 'Kim', specialization: 'Йога и растяжка', years: 3),
    trainer('t3', 'Rustam', 'Yusupov', specialization: 'Бокс и ММА', years: 9, accepting: false),
  ];

  FakeBackend backendWith({bool withTrainer = true, List<Map<String, dynamic>> requests = const []}) {
    final b = FakeBackend();
    b.routes['/api/trainers'] = (_) => club;
    b.routes['/api/me/trainer-requests'] = (req) => req.method == 'POST' ? {...requests.firstOrNull ?? {}} : requests;
    b.routes['/api/me/profile'] = (_) => profileJson(withTrainer: withTrainer);
    return b;
  }

  Future<FakeBackend> pump(WidgetTester tester, FakeBackend b, {void Function(int)? onNavigate}) => pumpScreen(
    tester,
    Scaffold(body: TrainersScreen(onNavigate: onNavigate)),
    backend: b,
  );

  List<String> rowNames(WidgetTester tester) => [
    for (final name in ['Alina Kim', 'Rustam Yusupov', 'Dilshod Rashidov'])
      if (find.text(name).evaluate().isNotEmpty) name,
  ]..sort((a, b) => tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));

  testWidgets('own trainer is on top and not repeated in the list; data the API lacks is hidden', (tester) async {
    await pump(tester, backendWith());

    expect(find.text('3 тренера · выберите своего'), findsOneWidget);
    final card = find.byKey(const Key('my-trainer'));
    expect(find.descendant(of: card, matching: find.text('Dilshod Rashidov')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Ваш тренер')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('5 лет')), findsOneWidget);
    expect(find.text('Dilshod Rashidov'), findsOneWidget, reason: 'not duplicated in the list');
    // The card first, then the list sorted by name; a trainer who is not taking clients says so.
    expect(rowNames(tester), ['Dilshod Rashidov', 'Alina Kim', 'Rustam Yusupov']);
    expect(find.text('Набор закрыт'), findsOneWidget);
    // No rating, clients count, directions or availability in the API: nothing is invented.
    for (final text in ['Рейтинг', 'Клиентов', 'Свободен сегодня', 'По рейтингу', 'Все']) {
      expect(find.text(text), findsNothing);
    }
    expect(find.byKey(const Key('choose-trainer-hint')), findsNothing);
  });

  testWidgets('search filters by name or direction, can be cleared, and an empty result can be reset', (tester) async {
    await pump(tester, backendWith(withTrainer: false));
    expect(rowNames(tester), ['Alina Kim', 'Dilshod Rashidov', 'Rustam Yusupov']);

    await tester.enterText(find.byKey(const Key('trainer-search')), 'йога');
    await tester.pump(const Duration(milliseconds: 100));
    expect(rowNames(tester), hasLength(3), reason: 'debounced');
    await tester.pump(const Duration(milliseconds: 300));
    expect(rowNames(tester), ['Alina Kim']);

    await tester.tap(find.byKey(const Key('trainer-search-clear')));
    await tester.pump();
    expect(rowNames(tester), hasLength(3));

    await tester.enterText(find.byKey(const Key('trainer-search')), 'RASH');
    await tester.pump(const Duration(milliseconds: 300));
    expect(rowNames(tester), ['Dilshod Rashidov']);

    await tester.enterText(find.byKey(const Key('trainer-search')), 'пилатес');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Никого не нашли'), findsOneWidget);
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(rowNames(tester), hasLength(3));
    expect(find.text('Никого не нашли'), findsNothing);
  });

  testWidgets('filters sheet: only trainers taking clients, sorted by experience', (tester) async {
    await pump(tester, backendWith(withTrainer: false));

    await tester.tap(find.byKey(const Key('trainer-filters-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По опыту'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('only-accepting')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 60)); // close the sheet
    await tester.pumpAndSettle();

    expect(rowNames(tester), ['Dilshod Rashidov', 'Alina Kim']);
    expect(find.text('Rustam Yusupov'), findsNothing);

    // The sort menu in the header switches back to names.
    await tester.tap(find.byKey(const Key('trainer-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По имени').last);
    await tester.pumpAndSettle();
    expect(rowNames(tester), ['Alina Kim', 'Dilshod Rashidov']);
  });

  testWidgets(
    'without a trainer: hint, initials for trainers without photo, request from the profile, then the trainer contacts',
    (tester) async {
      final b = backendWith(withTrainer: false);
      String? sentTo;
      b.routes['/api/me/trainer-requests'] = (req) {
        if (req.method != 'POST') return <Object>[];
        sentTo = (jsonDecode(req.body) as Map<String, dynamic>)['trainerId'] as String?;
        return {
          'id': 'r1',
          'status': 'Pending',
          'message': null,
          'responseComment': null,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'respondedAt': null,
          'trainer': {'id': 't2', 'firstName': 'Alina', 'lastName': 'Kim'},
          'client': {'id': 'c1', 'firstName': 'Aziz', 'lastName': 'Karimov'},
          'trainerTelegram': 'alina_fit',
          'trainerInstagram': 'alina.kim',
        };
      };
      await pump(tester, b);

      expect(
        find.text('Выберите своего тренера — он составит программу и будет вести ваши тренировки'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('my-trainer')), findsNothing);
      expect(find.text('AK'), findsOneWidget); // no photo: initials on a gradient

      await tester.tap(find.text('Alina Kim'));
      await tester.pumpAndSettle();
      expect(find.byType(TrainerSheet), findsOneWidget);
      // The directory has no contacts; they come with the request, on the next screen of the sheet.
      expect(find.byKey(const Key('contact-telegram')), findsNothing);
      await tester.tap(find.byKey(const Key('choose-as-trainer')));
      await settle(tester);
      expect(sentTo, 't2');
      expect(find.byKey(const Key('request-sent')), findsOneWidget);
      expect(find.text('Заявка отправлена!'), findsOneWidget);
      expect(find.text('@alina_fit'), findsOneWidget);
      expect(find.text('@alina.kim'), findsOneWidget);

      await tester.tap(find.byKey(const Key('request-sent-done')));
      await settle(tester);
      expect(find.byType(TrainerSheet), findsNothing);
    },
  );

  testWidgets('a request without trainer contacts says the trainer will answer in the app', (tester) async {
    final b = backendWith(withTrainer: false);
    b.routes['/api/me/trainer-requests'] = (req) => req.method != 'POST'
        ? <Object>[]
        : {
            'id': 'r1',
            'status': 'Pending',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'trainer': {'id': 't2', 'firstName': 'Alina', 'lastName': 'Kim'},
            'client': {'id': 'c1', 'firstName': 'Aziz', 'lastName': 'Karimov'},
          };
    await pump(tester, b);
    await tester.tap(find.text('Alina Kim'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-as-trainer')));
    await settle(tester);
    expect(find.text('Alina Kim получит заявку и ответит в приложении — мы пришлём уведомление.'), findsOneWidget);
    expect(find.byKey(const Key('contact-telegram')), findsNothing);
  });

  testWidgets('training without a trainer: confirm, the pending request is withdrawn, the choice is shown', (
    tester,
  ) async {
    final pendingRequest = {
      'id': 'r1',
      'status': 'Pending',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'trainer': {'id': 't2', 'firstName': 'Alina', 'lastName': 'Kim'},
      'client': {'id': 'c1', 'firstName': 'Aziz', 'lastName': 'Karimov'},
    };
    final b = backendWith(withTrainer: false, requests: [pendingRequest]);
    var solo = false;
    b.routes['/api/me/profile'] = (_) => {...profileJson(withTrainer: false), 'withoutTrainer': solo};
    b.routes['/api/me/without-trainer'] = (req) {
      solo = true;
      pendingRequest['status'] = 'Cancelled';
      return {...profileJson(withTrainer: false), 'withoutTrainer': true};
    };
    await pump(tester, b);
    expect(find.text('Заявка тренеру Alina Kim на рассмотрении'), findsOneWidget);

    await tester.tap(find.byKey(const Key('without-trainer-option')));
    await settle(tester);
    expect(find.text('Заявка тренеру Alina Kim будет отменена.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('without-trainer-confirm')));
    await settle(tester);

    expect(b.calls['/api/me/without-trainer'], 1);
    expect(find.byKey(const Key('without-trainer-selected')), findsOneWidget);
    expect(find.text('Вы занимаетесь без тренера'), findsOneWidget);
    expect(find.byKey(const Key('without-trainer-option')), findsNothing);
    expect(find.byKey(const Key('choose-trainer-hint')), findsNothing);
  });

  testWidgets('own trainer shows Telegram and Instagram in the profile sheet', (tester) async {
    final b = backendWith();
    b.routes['/api/me/profile'] = (_) => {
      ...profileJson(),
      'assignedTrainer': {...trainerJson(), 'telegram': 'dilshod_coach', 'instagram': null},
    };
    await pump(tester, b);
    await tester.tap(find.descendant(of: find.byKey(const Key('my-trainer')), matching: find.text('Dilshod Rashidov')));
    await tester.pumpAndSettle();
    expect(find.text('Связаться с тренером'), findsOneWidget);
    expect(find.text('@dilshod_coach'), findsOneWidget);
    expect(find.byKey(const Key('contact-instagram')), findsNothing);
  });

  testWidgets('own trainer card: book opens workouts, chat explains it is coming', (tester) async {
    int? navigatedTo;
    await pump(tester, backendWith(), onNavigate: (i) => navigatedTo = i);

    await tester.tap(find.byKey(const Key('my-trainer-book')));
    expect(navigatedTo, TrainersScreen.workoutsTab);
    await tester.tap(find.byKey(const Key('my-trainer-chat')));
    await tester.pump();
    expect(find.text('Чат с тренером скоро будет доступен'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const Key('my-trainer')), matching: find.text('Dilshod Rashidov')));
    await tester.pumpAndSettle();
    expect(find.byType(TrainerSheet), findsOneWidget);
  });

  testWidgets('long names and directions are cut with an ellipsis instead of overflowing', (tester) async {
    final b = backendWith(withTrainer: false);
    b.routes['/api/trainers'] = (_) => [
      trainer(
        'tx',
        'Александра-Виктория',
        'Константинопольская-Длиннофамильная',
        specialization: 'Функциональный тренинг, реабилитация после травм и подготовка к соревнованиям',
        years: 12,
      ),
    ];
    await pump(tester, b);
    tester.view.physicalSize = const Size(960, 2556); // 320 pt wide
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('API error shows retry, retry loads the trainers', (tester) async {
    final b = backendWith();
    b.routes['/api/trainers'] = (_) => http.Response('{"code":"internal_error","title":"x"}', 500);
    await pump(tester, b);
    expect(find.text('Повторить'), findsOneWidget);

    b.routes['/api/trainers'] = (_) => club;
    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.byKey(const Key('my-trainer')), findsOneWidget);
  });
}
