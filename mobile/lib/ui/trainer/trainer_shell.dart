import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'trainer_clients_screen.dart';
import 'trainer_profile_screen.dart';
import 'trainer_requests_screen.dart';
import 'trainer_schedule_screen.dart';

/// Trainer cabinet. All data is scoped to the signed-in trainer by the backend.
class TrainerShell extends StatefulWidget {
  const TrainerShell({super.key});
  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  int _index = 0;
  int _generation = 0;

  void _go(int index) => setState(() {
    _index = index;
    _generation++;
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Android Back on another tab returns to Requests first; only Back there leaves the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            TrainerRequestsScreen(key: ValueKey('r$_generation')),
            TrainerClientsScreen(key: ValueKey('c$_generation')),
            TrainerScheduleScreen(key: ValueKey('s$_generation')),
            TrainerProfileScreen(key: ValueKey('p$_generation')),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.inbox_outlined),
              selectedIcon: const Icon(Icons.inbox_rounded),
              label: t.tabRequests,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: t.tabClients,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: t.tabSchedule,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: t.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
