import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/gen/app_localizations.dart';
import 'state/locale_controller.dart';
import 'state/session.dart';
import 'ui/auth/change_password_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/client/client_shell.dart';
import 'ui/theme.dart';
import 'ui/trainer/trainer_shell.dart';
import 'ui/widgets/common.dart';

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    return MaterialApp(
      title: 'Fitness Formulasi',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

/// Routes by session state and role: clients and trainers get different apps.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final Widget child = switch (session.status) {
      SessionStatus.unknown => const Scaffold(body: LoadingView()),
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.signedIn when session.user!.mustChangePassword => const ChangePasswordScreen(forced: true),
      SessionStatus.signedIn => session.user!.role == 'Trainer' ? const TrainerShell() : const ClientShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: KeyedSubtree(
        key: ValueKey('${session.status}-${session.user?.id}-${session.user?.mustChangePassword}'),
        child: child,
      ),
    );
  }
}
