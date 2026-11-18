import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';
import 'membership_screen.dart';
import 'profile_screen.dart';
import 'trainers_screen.dart';
import 'workouts_screen.dart';

/// Client app with bottom navigation. Tabs keep their state while switching.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key});
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;
  // Bumped to force tabs to reload after actions on another tab (e.g. a trainer request).
  int _generation = 0;

  void _go(int index) => setState(() {
    _index = index;
    _generation++;
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pages = [
      HomeScreen(key: ValueKey('home$_generation'), onNavigate: _go),
      MembershipScreen(key: ValueKey('membership$_generation')),
      TrainersScreen(key: ValueKey('trainers$_generation'), onNavigate: _go),
      WorkoutsScreen(key: ValueKey('workouts$_generation'), onNavigate: _go),
      const ProfileScreen(),
    ];
    // Android Back on another tab returns to Home first; only Back on Home leaves the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        backgroundColor: Brand.background,
        extendBody: true,
        // Every tab scrolls under the floating tab bar and pads itself.
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: GlassTabBar(
          index: _index,
          onSelected: _go,
          items: [
            GlassTabItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: t.tabHome),
            GlassTabItem(
              icon: Icons.credit_card_outlined,
              activeIcon: Icons.credit_card_rounded,
              label: t.tabMembership,
            ),
            GlassTabItem(icon: Icons.group_outlined, activeIcon: Icons.group_rounded, label: t.tabTrainers),
            GlassTabItem(
              icon: Icons.fitness_center_outlined,
              activeIcon: Icons.fitness_center_rounded,
              label: t.tabWorkouts,
            ),
            GlassTabItem(
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle_rounded,
              label: t.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
