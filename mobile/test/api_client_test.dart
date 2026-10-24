import 'package:fitness_formulasi/core/api_client.dart';
import 'package:fitness_formulasi/core/token_storage.dart';
import 'package:fitness_formulasi/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage tokens;
  late ApiClient api;

  setUp(() {
    backend = FakeBackend();
    tokens = MemoryTokenStorage();
    api = ApiClient(baseUrl: 'http://test', tokens: tokens, httpClient: backend.client);
  });

  test('login stores tokens and returns the user', () async {
    final user = await AuthRepository(api).login('+998901234567', 'Secret123');
    expect(user.role, 'Client');
    expect(await tokens.accessToken(), 'access-1');
    expect(await tokens.refreshToken(), 'refresh-1');
  });

  test('backend error codes are surfaced as ApiException', () async {
    expect(
      () => AuthRepository(api).login('+998901234567', 'wrong'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials').having((e) => e.status, 'status', 401),
      ),
    );
  });

  test('expired access token is refreshed once and the request retried', () async {
    await AuthRepository(api).login('+998901234567', 'Secret123');
    backend.expireNextAccess = true;
    final dashboard = await ClientRepository(api).dashboard();
    expect(dashboard.firstName, 'Aziz');
    expect(await tokens.accessToken(), 'access-2');
    expect(backend.requests.where((r) => r.url.path == '/api/auth/refresh').length, 1);
  });

  test('failed refresh clears tokens and signals session end', () async {
    var expired = false;
    api.onSessionExpired = () => expired = true;
    await tokens.save('stale', 'revoked');
    await expectLater(ClientRepository(api).dashboard(), throwsA(isA<ApiException>()));
    expect(expired, isTrue);
    expect(await tokens.refreshToken(), isNull);
  });
}
