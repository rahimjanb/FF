import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fitness_formulasi/core/config.dart';
import 'package:fitness_formulasi/ui/client/face_access_screen.dart';
import 'package:fitness_formulasi/ui/client/home_screen.dart';
import 'package:fitness_formulasi/ui/client/membership_screen.dart';
import 'package:fitness_formulasi/ui/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'fake_backend.dart';
import 'screen_harness.dart';

final testJpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 300, height: 400)));

Map<String, dynamic> faceJson(String status, {bool hasAccess = true}) => {
  'status': status,
  'version': status == 'None' ? 0 : 1,
  'uploadedAt': status == 'None' ? null : '2026-11-06T10:00:00Z',
  'hasAccess': hasAccess,
  'accessFrom': hasAccess ? '2026-11-05' : null,
  'accessTo': hasAccess ? '2027-11-04' : null,
  'terminals': 1,
};

/// Face entry on the fake backend: GET answers [json], PUT keeps the upload and answers Pending, DELETE clears.
class FaceState {
  FaceState(FakeBackend b, String status, {this.photo}) : json = faceJson(status) {
    b.routes['/api/me/face'] = (req) {
      switch (req.method) {
        case 'PUT':
          uploads.add(req);
          final error = uploadError;
          if (error != null) {
            return http.Response(
              jsonEncode({'title': error, 'status': 400, 'code': error}),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          photo = testJpeg;
          return json = faceJson('Pending');
        case 'DELETE':
          deletes++;
          photo = null;
          return json = faceJson('None', hasAccess: json['hasAccess'] as bool);
        default:
          return json;
      }
    };
    b.routes['/api/me/face/photo'] = (_) => photo == null
        ? http.Response('', 404)
        : http.Response.bytes(photo!, 200, headers: {'content-type': 'image/jpeg'});
  }

  Map<String, dynamic> json;
  Uint8List? photo;
  String? uploadError;
  final uploads = <http.Request>[];
  int deletes = 0;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
}

void main() {
  group('photo preparation', () {
    (Uint8List?, FacePhotoProblem?) prepare(img.Image image) => prepareFacePhoto(img.encodeJpg(image, quality: 95));

    test('a large photo is scaled to 720 px on the longer side and stays a JPEG within 200 KB', () {
      final (jpeg, problem) = prepare(img.Image(width: 1600, height: 1200));
      expect(problem, isNull);
      expect(jpeg!.length, lessThanOrEqualTo(faceMaxBytes));
      final back = img.decodeJpg(jpeg)!;
      expect((back.width, back.height), (720, 540));
    });

    test('a detailed photo is compressed harder, then made smaller, until it fits 200 KB', () {
      final random = Random(1);
      final noise = img.Image(width: 720, height: 720);
      for (final p in noise) {
        p
          ..r = random.nextInt(256)
          ..g = random.nextInt(256)
          ..b = random.nextInt(256);
      }
      expect(img.encodeJpg(noise, quality: 85).length, greaterThan(faceMaxBytes));
      final (jpeg, problem) = prepare(noise);
      expect(problem, isNull);
      expect(jpeg!.length, lessThanOrEqualTo(faceMaxBytes));
    });

    test('the camera orientation is applied to the pixels, since terminals ignore it', () {
      final sideways = img.Image(width: 400, height: 300);
      sideways.exif.imageIfd.orientation = 6; // rotated 90° clockwise
      final (jpeg, _) = prepare(sideways);
      final back = img.decodeJpg(jpeg!)!;
      expect((back.width, back.height), (300, 400));
    });

    test('a too small or unreadable photo is refused', () {
      expect(prepare(img.Image(width: 200, height: 300)).$2, FacePhotoProblem.tooSmall);
      // Scaling a very long panorama would leave its short side below the minimum.
      expect(prepare(img.Image(width: 4000, height: 260)).$2, FacePhotoProblem.tooSmall);
      expect(prepareFacePhoto(Uint8List.fromList([1, 2, 3, 4])).$2, FacePhotoProblem.unreadable);
    });
  });

  group('face entry screen', () {
    testWidgets('no photo: consent, selfie, upload; the screen follows the photo to the terminal', (tester) async {
      final b = FakeBackend();
      final face = FaceState(b, 'None');
      final sources = <FacePhotoSource>[];
      await pumpScreen(
        tester,
        FaceAccessScreen(
          picker: (s) async {
            sources.add(s);
            return testJpeg;
          },
        ),
        backend: b,
      );

      expect(find.text('Вход по лицу'), findsOneWidget);
      expect(find.byKey(const Key('face-status-none')), findsOneWidget);
      expect(find.text('Лицо анфас и целиком в кадре'), findsOneWidget);
      expect(find.text('Без очков, маски и головного убора'), findsOneWidget);
      expect(find.text('Ровный свет, без засветки сзади'), findsOneWidget);
      expect(find.byKey(const Key('face-delete')), findsNothing);

      await tapKey(tester, 'face-camera');
      expect(sources, [FacePhotoSource.camera]);
      expect(find.byKey(const Key('face-draft')), findsOneWidget);
      // Nothing is sent without consent.
      expect(tester.widget<GradientPillButton>(find.byKey(const Key('face-send'))).onPressed, isNull);
      await tapKey(tester, 'face-consent');
      expect(find.text('Согласен на обработку фото лица для прохода через турникет клуба'), findsOneWidget);
      await tapKey(tester, 'face-send');

      final upload = face.uploads.single;
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(upload.bodyBytes);
      expect(body, contains('name="consent"\r\n\r\ntrue'));
      expect(body, contains('name="file"; filename="face.jpg"'));
      expect(body, contains('image/jpeg'));
      expect(find.text('Фото отправлено'), findsOneWidget);
      expect(find.byKey(const Key('face-status-pending')), findsOneWidget);
      expect(find.text('Отправляем на турникет…'), findsOneWidget);
      expect(find.byKey(const Key('face-photo')), findsOneWidget);

      // The terminal took it: the next check shows that entry by face works and for which days.
      face.json = faceJson('Ready');
      await tester.pump(FaceAccessScreen.pollInterval);
      await settle(tester);
      expect(find.byKey(const Key('face-status-ready')), findsOneWidget);
      expect(find.text('Проходите в клуб по лицу'), findsOneWidget);
      expect(find.textContaining('Турникет пропустит вас с 5 ноября 2026'), findsOneWidget);
      expect(find.text('Заменить фото'), findsOneWidget);
    });

    testWidgets('a photo the terminal refused asks for a new one, with the tips', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'Rejected', photo: testJpeg);
      await pumpScreen(tester, FaceAccessScreen(picker: (_) async => testJpeg), backend: b);

      expect(find.byKey(const Key('face-status-rejected')), findsOneWidget);
      expect(find.text('Терминал не распознал лицо на фото — сделайте новое'), findsOneWidget);
      expect(find.text('Лицо анфас и целиком в кадре'), findsOneWidget);
      expect(find.byKey(const Key('face-photo')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('face-camera')), 200);
      expect(find.text('Сделать селфи'), findsOneWidget);
    });

    testWidgets('saved photo without a membership explains when entry by face starts', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'Waiting', photo: testJpeg).json = faceJson('Waiting', hasAccess: false);
      await pumpScreen(tester, FaceAccessScreen(picker: (_) async => testJpeg), backend: b);

      expect(find.byKey(const Key('face-status-waiting')), findsOneWidget);
      expect(find.text('Фото сохранено. Вход по лицу заработает, когда абонемент будет активен.'), findsOneWidget);
    });

    testWidgets('deleting the photo asks first and removes the client from the turnstile', (tester) async {
      final b = FakeBackend();
      final face = FaceState(b, 'Ready', photo: testJpeg);
      await pumpScreen(tester, FaceAccessScreen(picker: (_) async => testJpeg), backend: b);
      expect(find.byKey(const Key('face-photo')), findsOneWidget);
      expect(find.byKey(const Key('face-consent')), findsNothing); // given with the photo

      await tapKey(tester, 'face-delete');
      expect(find.byKey(const Key('face-delete-sheet')), findsOneWidget);
      expect(find.textContaining('Вас уберут с турникета'), findsOneWidget);
      await tapKey(tester, 'face-delete-confirm');

      expect(face.deletes, 1);
      expect(find.text('Фото удалено'), findsOneWidget);
      expect(find.byKey(const Key('face-status-none')), findsOneWidget);
      expect(find.byKey(const Key('face-photo')), findsNothing);
    });

    testWidgets('camera and upload problems are explained; the picked photo stays for another try', (tester) async {
      final b = FakeBackend();
      final face = FaceState(b, 'None')..uploadError = 'face_too_large';
      var calls = 0;
      await pumpScreen(
        tester,
        FaceAccessScreen(
          picker: (s) async {
            calls++;
            if (s == FacePhotoSource.camera) throw const FacePhotoException(FacePhotoProblem.camera);
            return testJpeg;
          },
        ),
        backend: b,
      );

      await tapKey(tester, 'face-camera');
      expect(find.text('Камера недоступна. Выберите фото из галереи.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // the message goes away
      await tester.pumpAndSettle();
      await tapKey(tester, 'face-gallery');
      expect(calls, 2);
      await tapKey(tester, 'face-consent');
      await tapKey(tester, 'face-send');
      expect(face.uploads, hasLength(1));
      expect(find.text('Фото слишком большое: до 200 КБ'), findsOneWidget);
      expect(find.byKey(const Key('face-draft')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tapKey(tester, 'face-retake');
      expect(find.byKey(const Key('face-draft')), findsNothing);
      expect(find.byKey(const Key('face-status-none')), findsOneWidget);
    });

    testWidgets('next to the consent the privacy policy explains the photo; the link does not tick the consent', (
      tester,
    ) async {
      final b = FakeBackend();
      FaceState(b, 'None');
      final urls = captureLaunchedUrls(tester);
      await pumpScreen(tester, FaceAccessScreen(picker: (_) async => testJpeg), backend: b);
      await tapKey(tester, 'face-camera');

      await tapKey(tester, 'face-privacy-link');
      expect(urls, [AppConfig.privacyPolicyUrl]);
      expect(tester.widget<GradientPillButton>(find.byKey(const Key('face-send'))).onPressed, isNull);
    });
  });

  group('membership screen', () {
    const screen = Scaffold(body: MembershipScreen());

    testWidgets('shows entry by face with its state and opens it', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'Ready', photo: testJpeg);
      await pumpScreen(tester, screen, backend: b);

      await tester.ensureVisible(find.byKey(const Key('face-access-tile')));
      expect(find.byKey(const Key('face-badge-ready')), findsOneWidget);
      expect(find.text('Работает'), findsOneWidget);
      await tapKey(tester, 'face-access-tile');
      expect(find.byType(FaceAccessScreen), findsOneWidget);
      expect(find.byKey(const Key('face-status-ready')), findsOneWidget);
    });

    testWidgets('a photo the terminal refused is flagged on the tile', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'Rejected', photo: testJpeg);
      await pumpScreen(tester, screen, backend: b);
      expect(find.byKey(const Key('face-badge-rejected')), findsOneWidget);
      expect(find.text('Нужно новое фото'), findsOneWidget);
    });

    testWidgets('if the face state cannot be loaded the tile still leads to it', (tester) async {
      await pumpScreen(tester, screen, backend: FakeBackend()); // /api/me/face answers 404
      expect(find.byKey(const Key('face-access-tile')), findsOneWidget);
      expect(find.byKey(const Key('face-badge-none')), findsNothing);
      expect(find.text('Gold 30'), findsOneWidget);
    });

    /// Plans on sale and membership requests kept by the fake backend.
    void withPlans(FakeBackend b, List<Map<String, dynamic>> memberships) {
      final plans = [FakeBackend.plan('p1', 'Gold 30')];
      final requests = <Map<String, dynamic>>[];
      b.routes['/api/me/memberships'] = (_) => memberships;
      b.routes['/api/me/plans'] = (_) => plans;
      b.routes['/api/me/membership-requests'] = (req) {
        if (req.method != 'POST') return requests;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final r = {
          'id': 'r1',
          'kind': body['kind'],
          'status': 'Pending',
          'responseComment': null,
          'createdAt': '2026-10-28T10:00:00Z',
          'plan': plans.single,
        };
        requests.add(r);
        return r;
      };
    }

    testWidgets('after buying a membership in the app the client is offered to add a face photo', (tester) async {
      final b = FakeBackend();
      withPlans(b, []);
      FaceState(b, 'None');
      await pumpScreen(tester, screen, backend: b);

      await tapKey(tester, 'checkout-plan');
      expect(find.byKey(const Key('face-offer')), findsOneWidget);
      expect(find.text('Добавьте фото для входа по лицу'), findsOneWidget);
      await tapKey(tester, 'face-offer-add');
      expect(find.byType(FaceAccessScreen), findsOneWidget);
      expect(find.byKey(const Key('face-status-none')), findsOneWidget);
    });

    testWidgets('renewal: "later" closes the offer and leaves the pending request', (tester) async {
      final b = FakeBackend();
      withPlans(b, [FakeBackend.membership()]);
      FaceState(b, 'None');
      await pumpScreen(tester, screen, backend: b);

      await tapKey(tester, 'action-renew');
      await tapKey(tester, 'send-membership-request');
      expect(find.byKey(const Key('face-offer')), findsOneWidget);
      await tapKey(tester, 'face-offer-later');
      expect(find.byKey(const Key('face-offer')), findsNothing);
      expect(find.byKey(const Key('pending-membership-request')), findsOneWidget);
    });

    testWidgets('renewal: no offer when the client already has a face photo', (tester) async {
      final b = FakeBackend();
      withPlans(b, [FakeBackend.membership()]);
      FaceState(b, 'Ready', photo: testJpeg);
      await pumpScreen(tester, screen, backend: b);

      await tapKey(tester, 'action-renew');
      await tapKey(tester, 'send-membership-request');
      expect(find.byKey(const Key('face-offer')), findsNothing);
      expect(find.text('Заявка отправлена. Оплатите абонемент на ресепшене клуба.'), findsOneWidget);
    });
  });

  group('home screen', () {
    Future<void> pumpHome(WidgetTester tester, FakeBackend b) => pumpScreen(
      tester,
      Scaffold(body: HomeScreen(onNavigate: (_) {})),
      backend: b,
    );

    testWidgets('invites a client with a membership to add a face photo', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'None');
      await pumpHome(tester, b);

      expect(find.byKey(const Key('home-face-prompt')), findsOneWidget);
      expect(find.text('Вход в клуб по лицу'), findsOneWidget);
      // Under the greeting, above the membership card.
      final prompt = tester.getTopLeft(find.byKey(const Key('home-face-prompt'))).dy;
      expect(prompt, greaterThan(tester.getTopLeft(find.textContaining('Aziz')).dy));
      expect(prompt, lessThan(tester.getTopLeft(find.text('Мой абонемент')).dy));

      await tapKey(tester, 'home-face-prompt');
      expect(find.byType(FaceAccessScreen), findsOneWidget);
    });

    testWidgets('no prompt once the photo is added', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'Pending', photo: testJpeg);
      await pumpHome(tester, b);
      expect(find.byKey(const Key('home-face-prompt')), findsNothing);
    });

    testWidgets('no prompt without a membership', (tester) async {
      final b = FakeBackend();
      FaceState(b, 'None');
      b.routes['/api/me/dashboard'] = (_) => {...FakeBackend.dashboard(), 'currentMembership': null};
      await pumpHome(tester, b);
      expect(find.byKey(const Key('home-face-prompt')), findsNothing);
    });

    testWidgets('home still loads when the face state fails', (tester) async {
      await pumpHome(tester, FakeBackend()); // /api/me/face answers 404
      expect(find.textContaining('Aziz'), findsOneWidget);
      expect(find.byKey(const Key('home-face-prompt')), findsNothing);
    });
  });
}
