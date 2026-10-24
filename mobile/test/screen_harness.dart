import 'package:fitness_formulasi/core/api_client.dart';
import 'package:fitness_formulasi/core/token_storage.dart';
import 'package:fitness_formulasi/data/repositories.dart';
import 'package:fitness_formulasi/l10n/gen/app_localizations.dart';
import 'package:fitness_formulasi/state/locale_controller.dart';
import 'package:fitness_formulasi/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_backend.dart';

/// Pumps a single screen with a signed-in session against [FakeBackend] (TEST-ONLY data source).
Future<FakeBackend> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  String role = 'Client',
  FakeBackend? backend,
}) async {
  final b = (backend ?? FakeBackend())
    ..role = role
    ..loggedIn = true;
  final tokens = MemoryTokenStorage();
  await tokens.save(b.accessToken, 'refresh-1');
  final api = ApiClient(baseUrl: 'http://test', tokens: tokens, httpClient: b.client);
  tester.view.physicalSize = const Size(1179, 2556); // iPhone-sized viewport
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController()),
        Provider.value(value: ClientRepository(api)),
        Provider.value(value: TrainerRepository(api)),
        Provider.value(value: NotificationRepository(api)),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('uz')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );
  await settle(tester);
  return b;
}

/// Lets real HTTP futures (MockClient) complete, then settles animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

Map<String, dynamic> paged(List<Map<String, dynamic>> items) => {
  'items': items,
  'page': 1,
  'pageSize': 50,
  'totalCount': items.length,
  'totalPages': items.isEmpty ? 0 : 1,
};

Map<String, dynamic> session(
  String id,
  DateTime startsAt, {
  String status = 'Scheduled',
  int minutes = 60,
  String client = 'Aziz',
  String notes = '',
}) => {
  'id': id,
  'startsAt': startsAt.toUtc().toIso8601String(),
  'durationMinutes': minutes,
  'status': status,
  'notes': notes.isEmpty ? null : notes,
  'trainer': {'id': 't1', 'firstName': 'Dilshod', 'lastName': 'Rashidov'},
  'client': {'id': 'c1', 'firstName': client, 'lastName': 'Karimov'},
};

Map<String, dynamic> trainerJson() => {
  'id': 't1',
  'firstName': 'Dilshod',
  'lastName': 'Rashidov',
  'specialization': 'Силовые',
  'bio': null,
  'experienceYears': 5,
  'isAcceptingClients': true,
};

Map<String, dynamic> profileJson({bool withTrainer = true}) => {
  'id': 'c1',
  'phone': '+998901234567',
  'phoneConfirmed': false,
  'firstName': 'Aziz',
  'lastName': 'Karimov',
  'email': null,
  'birthDate': null,
  'gender': null,
  'assignedTrainer': withTrainer ? trainerJson() : null,
};
