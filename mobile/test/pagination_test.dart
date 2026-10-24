import 'package:fitness_formulasi/ui/client/notifications_screen.dart';
import 'package:fitness_formulasi/ui/client/workouts_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_clients_screen.dart';
import 'package:fitness_formulasi/ui/trainer/trainer_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart';
import 'screen_harness.dart';

/// Serves [all] in offset pages like the API. [shift] simulates rows added between requests,
/// which moves later pages by that many items (offset paging), so the client must skip duplicates.
Object Function(http.Request) pagedRoute(List<Map<String, dynamic>> all, {int shift = 0}) => (req) {
  final page = int.parse(req.url.queryParameters['page'] ?? '1');
  final size = int.parse(req.url.queryParameters['pageSize'] ?? '20');
  final from = ((page - 1) * size - (page > 1 ? shift : 0)).clamp(0, all.length);
  final items = all.sublist(from, (from + size).clamp(0, all.length));
  return {
    'items': items,
    'page': page,
    'pageSize': size,
    'totalCount': all.length,
    'totalPages': (all.length / size).ceil(),
  };
};

Future<void> tapLoadMore(WidgetTester tester) async {
  await tester.dragUntilVisible(find.byKey(const Key('load-more')), find.byType(ListView).first, const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('load-more')));
  await settle(tester);
}

void main() {
  final now = DateTime.now();

  group('Client session history', () {
    final history = [
      for (var i = 0; i < 25; i++) session('h$i', now.subtract(Duration(days: i + 1)), status: 'Completed'),
    ];

    FakeBackend backend(Object Function(http.Request) historyRoute) {
      final b = FakeBackend();
      b.routes['/api/me/training-sessions'] = (req) =>
          req.url.queryParameters['scope'] == 'History' ? historyRoute(req) : paged(const []);
      b.routes['/api/me/profile'] = (_) => profileJson();
      return b;
    }

    testWidgets('loads older pages on demand without duplicates', (tester) async {
      final b = backend(pagedRoute(history, shift: 2));
      await pumpScreen(tester, const WorkoutsScreen(), backend: b);
      expect(find.byType(SessionTile), findsNWidgets(20));

      await tapLoadMore(tester);
      // Page 2 overlaps page 1 by two rows (7 items returned); duplicates are skipped, so 25, not 27.
      expect(find.byType(SessionTile), findsNWidgets(25));
      final pages = b.requests
          .where((r) => r.url.queryParameters['scope'] == 'History')
          .map((r) => r.url.queryParameters['page'])
          .toList();
      expect(pages, ['1', '2']);
      expect(find.byKey(const Key('load-more')), findsNothing);
    });

    testWidgets('a failed page keeps loaded items and can be retried', (tester) async {
      var fail = true;
      final ok = pagedRoute(history);
      final b = backend(
        (req) => req.url.queryParameters['page'] == '2' && fail
            ? http.Response('{"code":"internal_error","title":"x"}', 500)
            : ok(req),
      );
      await pumpScreen(tester, const WorkoutsScreen(), backend: b);

      await tapLoadMore(tester);
      expect(find.byType(SessionTile), findsNWidgets(20));
      expect(find.text('Повторить'), findsOneWidget);

      fail = false;
      await tapLoadMore(tester);
      expect(find.byType(SessionTile), findsNWidgets(25));
      expect(find.byKey(const Key('load-more')), findsNothing);
    });
  });

  testWidgets('notifications page through the full list', (tester) async {
    final b = FakeBackend();
    b.routes['/api/notifications'] = pagedRoute([
      for (var i = 0; i < 35; i++)
        {
          'id': 'n$i',
          'type': 'TrainingSessionScheduled',
          'relatedEntityId': null,
          'payload': null,
          'isRead': true,
          'createdAt': now.subtract(Duration(hours: i)).toUtc().toIso8601String(),
        },
    ]);
    await pumpScreen(tester, const NotificationsScreen(), backend: b);
    expect(find.text('Назначена новая тренировка'), findsNWidgets(30));

    await tapLoadMore(tester);
    expect(find.text('Назначена новая тренировка'), findsNWidgets(35));
    expect(find.byKey(const Key('load-more')), findsNothing);
  });

  testWidgets('trainer clients page through the full list', (tester) async {
    final b = FakeBackend();
    b.routes['/api/trainer/clients'] = pagedRoute([
      for (var i = 0; i < 32; i++)
        {
          'id': 'c$i',
          'firstName': 'Client',
          'lastName': '$i',
          'phone': '+99890123${i.toString().padLeft(4, '0')}',
          'birthDate': null,
          'currentMembership': null,
          'lastVisitAt': null,
        },
    ]);
    await pumpScreen(tester, const TrainerClientsScreen(), role: 'Trainer', backend: b);
    expect(find.textContaining('Client '), findsNWidgets(30));

    await tapLoadMore(tester);
    expect(find.textContaining('Client '), findsNWidgets(32));
    expect(find.text('Client 31'), findsOneWidget);
  });

  testWidgets('an old pending request is shown even behind many newer processed ones', (tester) async {
    Map<String, dynamic> request(int i, String status) => {
      'id': 'r$i',
      'status': status,
      'message': null,
      'responseComment': null,
      'createdAt': now.subtract(Duration(days: i)).toUtc().toIso8601String(),
      'respondedAt': null,
      'trainer': {'id': 't1', 'firstName': 'Dilshod', 'lastName': 'Rashidov'},
      'client': {'id': 'c$i', 'firstName': 'Client', 'lastName': '$i'},
    };
    // 40 processed requests are newer than the pending one, so it is not on the first mixed page.
    final all = [for (var i = 0; i < 40; i++) request(i, 'Rejected'), request(40, 'Pending')];
    final b = FakeBackend();
    final mixed = pagedRoute(all);
    b.routes['/api/trainer/requests'] = (req) => req.url.queryParameters['status'] == 'pending'
        ? pagedRoute(all.where((r) => r['status'] == 'Pending').toList())(req)
        : mixed(req);
    await pumpScreen(tester, const TrainerRequestsScreen(), role: 'Trainer', backend: b);

    expect(find.text('Client 40'), findsOneWidget);
    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Client 29'), findsOneWidget);
    expect(find.text('Client 30'), findsNothing);

    await tapLoadMore(tester);
    expect(find.text('Client 39'), findsOneWidget);
    // The last page also contains the pending request; history skips it, so it appears once (at the top).
    await tester.fling(find.byType(ListView).first, const Offset(0, 20000), 5000);
    await tester.pumpAndSettle();
    expect(find.text('Client 40'), findsOneWidget);
    expect(find.text('На рассмотрении'), findsOneWidget);
  });
}
