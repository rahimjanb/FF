import 'dart:convert';

import 'package:fitness_formulasi/ui/client/membership_screen.dart';
import 'package:fitness_formulasi/ui/client/qr_pass_sheet.dart';
import 'package:fitness_formulasi/ui/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart';
import 'screen_harness.dart';

/// Money as rendered: thousands separated by a no-break space.
String sum(String digits) => '${digits.replaceAll(' ', ' ')} сум';

void main() {
  const screen = Scaffold(body: MembershipScreen());

  FakeBackend backendWith({required List<Map<String, dynamic>> memberships, List<Map<String, dynamic>>? plans}) {
    final b = FakeBackend();
    b.routes['/api/me/memberships'] = (_) => memberships;
    if (plans != null) b.routes['/api/me/plans'] = (_) => plans;
    return b;
  }

  /// Membership requests kept by the fake backend: POST adds a pending one, cancel withdraws it.
  List<Map<String, dynamic>> withRequests(FakeBackend b, List<Map<String, dynamic>> plans) {
    final requests = <Map<String, dynamic>>[];
    b.routes['/api/me/membership-requests'] = (req) {
      if (req.method != 'POST') return requests;
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final r = {
        'id': 'r${requests.length + 1}',
        'kind': body['kind'],
        'status': 'Pending',
        'responseComment': null,
        'createdAt': '2026-10-28T10:00:00Z',
        'plan': plans.firstWhere((p) => p['id'] == body['planId']),
      };
      requests.add(r);
      return r;
    };
    b.routes['/api/me/membership-requests/r1/cancel'] = (_) {
      requests.first['status'] = 'Cancelled';
      return requests.first;
    };
    return requests;
  }

  group('without a membership: plans', () {
    final plans = [
      FakeBackend.plan('p1', 'Безлимит', days: 30, price: 350000),
      FakeBackend.plan('p2', 'Пакет 8', days: 30, price: 250000, visitLimit: 8),
      FakeBackend.plan('p3', 'Безлимит 3', days: 90, price: 900000),
    ];

    testWidgets('lists real plans by duration, recalculates the total and sends a request paid at the desk', (
      tester,
    ) async {
      final b = backendWith(memberships: [], plans: plans);
      final requests = withRequests(b, plans);
      await pumpScreen(tester, screen, backend: b);

      expect(find.text('Нет действующего абонемента'), findsOneWidget);
      expect(find.text('1 мес'), findsOneWidget);
      expect(find.text('3 мес'), findsOneWidget);
      expect(find.text('Безлимит'), findsWidgets);
      expect(find.text('Пакет 8'), findsOneWidget);
      expect(find.text('Итого за 1 месяц'), findsOneWidget);

      await tester.tap(find.text('Пакет 8'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Оформить «Пакет 8»'), 200);
      expect(find.text(sum('250 000')), findsNWidgets(2)); // card and total

      await tester.scrollUntilVisible(find.text('3 мес'), -200);
      await tester.tap(find.text('3 мес'));
      await tester.pumpAndSettle();
      expect(find.text('Пакет 8'), findsNothing);
      await tester.scrollUntilVisible(find.text('Оформить «Безлимит 3»'), 200);
      expect(find.text('Итого за 3 месяца'), findsOneWidget);
      expect(find.text(sum('900 000')), findsNWidgets(2));

      expect(find.text('Оплата на ресепшене'), findsOneWidget);
      await tester.tap(find.text('Оформить «Безлимит 3»'));
      await settle(tester);
      expect(requests.single['kind'], 'New');
      expect(requests.single['plan']['id'], 'p3');
      expect(find.text('Заявка отправлена. Оплатите абонемент на ресепшене клуба.'), findsOneWidget);

      // The pending request replaces the checkout and can be withdrawn.
      await tester.scrollUntilVisible(find.byKey(const Key('pending-membership-request')), -200);
      expect(find.text('Новый абонемент «Безлимит 3»'), findsOneWidget);
      expect(find.text('Ожидает оплаты на ресепшене'), findsOneWidget);
      expect(find.byKey(const Key('checkout-plan')), findsNothing);
      await tester.tap(find.byKey(const Key('cancel-membership-request')));
      await settle(tester);
      expect(find.byKey(const Key('pending-membership-request')), findsNothing);
    });

    testWidgets('no plans on sale explains where to ask', (tester) async {
      await pumpScreen(
        tester,
        screen,
        backend: backendWith(memberships: [], plans: []),
      );
      expect(find.text('Тарифы пока не опубликованы'), findsOneWidget);
    });
  });

  group('with a membership: management', () {
    testWidgets('shows the pass, terms and empty history; guest visits are stage 2', (tester) async {
      await pumpScreen(tester, screen, backend: backendWith(memberships: [FakeBackend.membership()]));

      expect(find.text('Gold 30'), findsOneWidget);
      expect(find.text('Активен'), findsOneWidget);
      expect(find.text('Осталось 12 дней'), findsOneWidget);
      expect(find.text('из 30'), findsOneWidget);
      expect(find.text('03.11.2026'), findsOneWidget);
      expect(find.text('Aziz'), findsOneWidget);
      expect(find.text('Показать QR-пропуск'), findsOneWidget);
      expect(find.bySemanticsLabel('Гость, скоро'), findsOneWidget);
      expect(find.bySemanticsLabel('Заморозить, скоро'), findsNothing);

      await tester.scrollUntilVisible(find.text('Здесь появятся прошлые абонементы'), 200);
      expect(find.text('05.10.2026'), findsOneWidget); // start date in the terms
    });

    testWidgets('a week or less left is shown as expiring; past memberships form the history', (tester) async {
      final old = FakeBackend.membership(status: 'Expired', daysLeft: 0)
        ..['id'] = 'm0'
        ..['planName'] = 'Старый тариф';
      await pumpScreen(tester, screen, backend: backendWith(memberships: [FakeBackend.membership(daysLeft: 5), old]));
      expect(find.text('Скоро истекает'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Старый тариф'), 200);
      expect(find.text('Истёк'), findsOneWidget);
    });

    testWidgets('QR pass: a code to scan, and the desk accepting it is confirmed on the phone', (tester) async {
      final b = backendWith(memberships: [FakeBackend.membership()]);
      String? lastVisit;
      b.routes['/api/me/pass'] = (_) => FakeBackend.pass(lastVisitAt: lastVisit);
      await pumpScreen(tester, screen, backend: b);

      await tester.tap(find.byKey(const Key('show-qr-pass')));
      await settle(tester);
      expect(find.byKey(const Key('qr-pass')), findsOneWidget);
      expect(find.textContaining('Код обновится через'), findsOneWidget);
      expect(find.text('Код меняется каждые 30 секунд — скриншот не подойдёт'), findsOneWidget);

      lastVisit = '2026-10-28T10:00:10Z';
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(QrPassSheet.pollEvery);
      await settle(tester);
      expect(find.text('Вход отмечен'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await settle(tester);
    });

    testWidgets('renew preselects the current plan; there is no plan change', (tester) async {
      final plans = [FakeBackend.plan('p1', 'Gold 30'), FakeBackend.plan('p2', 'Silver 30', price: 250000)];
      final b = backendWith(memberships: [FakeBackend.membership()], plans: plans);
      final requests = withRequests(b, plans);
      await pumpScreen(tester, screen, backend: b);
      expect(find.byKey(const Key('action-change')), findsNothing);
      expect(find.text('Сменить'), findsNothing);

      await tester.tap(find.byKey(const Key('action-renew')));
      await settle(tester);
      expect(find.text('Продление абонемента'), findsOneWidget);
      expect(find.text('Текущий'), findsOneWidget);
      await tester.tap(find.byKey(const Key('send-membership-request')));
      await settle(tester);
      expect(requests.single['kind'], 'Renew');
      expect(requests.single['plan']['id'], 'p1');
      expect(find.byKey(const Key('plan-request-sheet')), findsNothing);
      expect(find.text('Продление «Gold 30»'), findsOneWidget);

      // One request at a time.
      await tester.tap(find.byKey(const Key('action-renew')));
      await tester.pumpAndSettle();
      expect(find.text('У вас уже есть заявка на абонемент'), findsOneWidget);
      expect(find.byKey(const Key('plan-request-sheet')), findsNothing);
    });

    testWidgets('a frozen membership shows the freeze, the moved end date and warns on the QR pass', (tester) async {
      final frozen = FakeBackend.membership(status: 'Frozen')
        ..['freezeStartDate'] = '2026-10-27'
        ..['freezeEndDate'] = '2026-11-05';
      await pumpScreen(tester, screen, backend: backendWith(memberships: [frozen]));
      expect(find.text('Заморожен с 27.10.2026 по 05.11.2026'), findsOneWidget);
      expect(find.text('Срок продлён до 03.11.2026'), findsOneWidget);

      // A current freeze can be ended from the sheet.
      await tester.tap(find.byKey(const Key('action-freeze')));
      await settle(tester);
      expect(find.byKey(const Key('freeze-sheet')), findsOneWidget);
      expect(find.byKey(const Key('unfreeze')), findsOneWidget);
      expect(find.text('Неиспользованные дни заморозки вычтутся из срока абонемента.'), findsOneWidget);
      await tester.tapAt(const Offset(200, 60));
      await settle(tester);

      await tester.tap(find.byKey(const Key('show-qr-pass')));
      await settle(tester);
      expect(find.text('Абонемент сейчас не действует — на ресепшене во входе откажут'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await settle(tester);
    });

    Map<String, dynamic> longMembership({int allowed = 3, int used = 0}) => FakeBackend.membership()
      ..['planName'] = 'Годовой'
      ..['startDate'] = '2026-10-05'
      ..['endDate'] = '2027-10-04'
      ..['freezesAllowed'] = allowed
      ..['freezesUsed'] = used;

    testWidgets('the client freezes a long membership: freezes left, 14 days from today by default', (tester) async {
      final b = backendWith(memberships: [longMembership(used: 1)]);
      Map<String, dynamic>? sent;
      b.routes['/api/me/memberships/m1/freeze'] = (req) {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return longMembership(used: 2);
      };
      await pumpScreen(tester, screen, backend: b);
      expect(find.bySemanticsLabel('Заморозить, 2/3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('action-freeze')));
      await settle(tester);
      expect(find.text('Осталось заморозок: 2 из 3'), findsOneWidget);
      expect(find.textContaining('до 30 дней за раз'), findsOneWidget);
      expect(find.text('14 дней'), findsWidgets);
      expect(find.text('Абонемент продлится до 18 октября 2027'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('freeze-submit')));
      await tester.tap(find.byKey(const Key('freeze-submit')));
      await settle(tester);
      final today = Fmt('ru').clubToday();
      String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      expect(sent, {'startDate': day(today), 'endDate': day(DateTime(today.year, today.month, today.day + 13))});
      expect(find.byKey(const Key('freeze-sheet')), findsNothing);
      expect(find.text('Абонемент заморожен'), findsOneWidget);
    });

    testWidgets('memberships shorter than six months cannot be frozen', (tester) async {
      await pumpScreen(tester, screen, backend: backendWith(memberships: [FakeBackend.membership()]));
      expect(find.bySemanticsLabel('Заморозить'), findsOneWidget, reason: 'no freezes counter without freezes');
      await tester.tap(find.byKey(const Key('action-freeze')));
      await settle(tester);
      expect(find.byKey(const Key('freeze-unavailable')), findsOneWidget);
      expect(find.text('Заморозка доступна только для абонементов от 6 месяцев'), findsOneWidget);
      expect(find.byKey(const Key('freeze-submit')), findsNothing);
    });

    testWidgets('once all freezes are used the sheet says so', (tester) async {
      await pumpScreen(tester, screen, backend: backendWith(memberships: [longMembership(used: 3)]));
      expect(find.bySemanticsLabel('Заморозить, 0/3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('action-freeze')));
      await settle(tester);
      expect(find.text('Вы использовали все заморозки этого абонемента'), findsOneWidget);
      expect(find.byKey(const Key('freeze-submit')), findsNothing);
    });

    testWidgets('an upcoming membership is managed, not offered again', (tester) async {
      await pumpScreen(
        tester,
        screen,
        backend: backendWith(memberships: [FakeBackend.membership(status: 'Upcoming')]),
      );
      expect(find.text('Скоро начнётся'), findsOneWidget);
      expect(find.text('Нет действующего абонемента'), findsNothing);
    });
  });

  testWidgets('load error offers a retry', (tester) async {
    final b = FakeBackend();
    var fail = true;
    b.routes['/api/me/plans'] = (_) => fail
        ? http.Response('{"title":"x","status":500,"code":"server_error"}', 500)
        : [FakeBackend.plan('p1', 'Gold 30')];
    await pumpScreen(tester, screen, backend: b);
    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.text('Gold 30'), findsOneWidget);
  });
}
