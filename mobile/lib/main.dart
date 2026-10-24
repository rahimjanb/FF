import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/token_storage.dart';
import 'data/repositories.dart';
import 'state/locale_controller.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl, tokens: SecureTokenStorage());
  final locale = LocaleController();
  await locale.load();
  final session = SessionController(AuthRepository(api), api);
  session.restore();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: locale),
        ChangeNotifierProvider.value(value: session),
        Provider.value(value: ClientRepository(api)),
        Provider.value(value: TrainerRepository(api)),
        Provider.value(value: NotificationRepository(api)),
      ],
      child: const FitnessApp(),
    ),
  );
}
