import 'package:fitness_formulasi/ui/client/membership_screen.dart';
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

  group('without a membership: plans', () {
    final plans = [
      FakeBackend.plan('p1', 'Безлимит', days: 30, price: 350000),
      FakeBackend.plan('p2', 'Пакет 8', days: 30, price: 250000, visitLimit: 8),
      FakeBackend.plan('p3', 'Безлимит 3', days: 90, price: 900000),
    ];

    testWidgets('lists real plans by duration, recalculates the total', (tester) async {
      await pumpScreen(
        tester,
        screen,
        backend: backendWith(memberships: [], plans: plans),
      );

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

      await tester.tap(find.text('Оформить «Безлимит 3»'));
      await tester.pump();
      expect(find.textContaining('Онлайн-оплата скоро будет доступна'), findsOneWidget);
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
    testWidgets('shows the pass, terms and empty history; stage 2 actions are disabled', (tester) async {
      await pumpScreen(tester, screen, backend: backendWith(memberships: [FakeBackend.membership()]));

      expect(find.text('Gold 30'), findsOneWidget);
      expect(find.text('Активен'), findsOneWidget);
      expect(find.text('Осталось 12 дней'), findsOneWidget);
      expect(find.text('из 30'), findsOneWidget);
      expect(find.text('03.11.2026'), findsOneWidget);
      expect(find.text('Aziz'), findsOneWidget);
      expect(find.text('Показать QR-пропуск'), findsOneWidget);
      expect(find.bySemanticsLabel('Заморозить, скоро'), findsOneWidget);

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
