import 'package:fitness_formulasi/ui/client/banners.dart';
import 'package:fitness_formulasi/ui/client/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';
import 'screen_harness.dart';

Map<String, dynamic> banner(
  String id,
  String title, {
  String? description,
  List<Map<String, dynamic>> media = const [],
}) => {
  'id': id,
  'title': title,
  'description': description,
  'coverUrl': media.where((m) => m['kind'] == 'Image').map((m) => m['url']).firstOrNull,
  'media': media,
};

Map<String, dynamic> photo(String id) => {
  'id': id,
  'kind': 'Image',
  'contentType': 'image/jpeg',
  'sizeBytes': 1000,
  'url': '/api/banners/media/$id.jpg',
};

void main() {
  Future<FakeBackend> pumpHome(WidgetTester tester, FakeBackend b) => pumpScreen(
    tester,
    Scaffold(body: HomeScreen(onNavigate: (_) {})),
    backend: b,
  );

  testWidgets('banners appear under the greeting and open their text and photos', (tester) async {
    final b = FakeBackend();
    b.routes['/api/banners'] = (_) => [
      banner(
        'b1',
        'Скидка 20% на годовой',
        description: 'До конца ноября.\nПодробности на ресепшене.',
        media: [photo('p1'), photo('p2')],
      ),
      banner('b2', 'Новый зал единоборств'),
    ];
    await pumpHome(tester, b);

    expect(find.byKey(const Key('home-banners')), findsOneWidget);
    expect(find.text('Скидка 20% на годовой'), findsOneWidget);
    // Below the greeting, above the membership card.
    final greeting = tester.getTopLeft(find.textContaining('Aziz')).dy;
    final bannerTop = tester.getTopLeft(find.byKey(const Key('home-banners'))).dy;
    expect(bannerTop, greaterThan(greeting));
    expect(bannerTop, lessThan(tester.getTopLeft(find.text('Мой абонемент')).dy));

    await tester.tap(find.text('Скидка 20% на годовой'));
    await settle(tester);
    expect(find.byType(BannerDetailScreen), findsOneWidget);
    expect(find.text('До конца ноября.\nПодробности на ресепшене.'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await settle(tester);
    expect(find.byType(BannerDetailScreen), findsNothing);

    // The second banner is one swipe away.
    await tester.drag(find.byKey(const Key('home-banners')), const Offset(-400, 0));
    await settle(tester);
    expect(find.text('Новый зал единоборств'), findsOneWidget);
  });

  testWidgets('home works without banners and when they fail to load', (tester) async {
    await pumpHome(tester, FakeBackend()); // the fake answers 404 for banners
    expect(find.byKey(const Key('home-banners')), findsNothing);
    expect(find.text('Мой абонемент'), findsOneWidget);

    final empty = FakeBackend()..routes['/api/banners'] = (_) => <Object>[];
    await pumpHome(tester, empty);
    expect(find.byKey(const Key('home-banners')), findsNothing);
  });

  testWidgets('training without a trainer: home says so and offers the QR pass', (tester) async {
    final b = FakeBackend();
    b.routes['/api/me/dashboard'] = (_) => {...FakeBackend.dashboard(), 'withoutTrainer': true};
    await pumpHome(tester, b);
    // The nutrition card sits above the trainer card, so it may be below the first screen.
    await tester.scrollUntilVisible(find.text('Без тренера'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Без тренера'), findsOneWidget);
    expect(find.text('Самостоятельные тренировки'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('home-solo-qr')));
    await tester.tap(find.byKey(const Key('home-solo-qr')));
    await settle(tester);
    expect(find.byKey(const Key('qr-pass')), findsOneWidget);
  });
}
