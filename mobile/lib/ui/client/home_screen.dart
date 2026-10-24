import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/membership_view.dart';
import 'notifications_screen.dart';
import 'workouts_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final void Function(int tab) onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClientRepository>();
    return SafeArea(
      child: AsyncView<ClientDashboard>(
        load: repo.dashboard,
        builder: (context, d, reload) => RefreshIndicator(
          onRefresh: reload,
          child: _HomeContent(dashboard: d, onNavigate: onNavigate, reload: reload),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.dashboard, required this.onNavigate, required this.reload});
  final ClientDashboard dashboard;
  final void Function(int) onNavigate;
  final Future<void> Function() reload;

  String _greeting(AppLocalizations t, String name) {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 5)).hour;
    if (hour >= 5 && hour < 12) return t.greetingMorning(name);
    if (hour >= 12 && hour < 18) return t.greetingDay(name);
    return t.greetingEvening(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final d = dashboard;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text(_greeting(t, d.firstName), style: Theme.of(context).textTheme.headlineMedium)),
            IconButton(
              tooltip: t.notifications,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                await reload();
              },
              icon: Badge(
                isLabelVisible: d.unreadNotifications > 0,
                label: Text('${d.unreadNotifications}'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        MembershipHeroCard(membership: d.currentMembership, onTap: () => onNavigate(1)),
        if (d.currentMembership == null && d.nextMembership != null) ...[
          const SizedBox(height: 12),
          MembershipHeroCard(membership: d.nextMembership, onTap: () => onNavigate(1)),
        ],
        SectionTitle(t.nextWorkout),
        if (d.nextSession == null)
          AppCard(
            onTap: () => onNavigate(3),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: AppColors.textSecondary),
                const SizedBox(width: 14),
                Expanded(child: Text(t.noUpcomingWorkouts, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          )
        else
          SessionTile(session: d.nextSession!, fmt: fmt, showTrainer: true),
        SectionTitle(t.yourTrainer),
        _TrainerCard(dashboard: d, onNavigate: onNavigate),
        SectionTitle(t.visits),
        Row(
          children: [
            Expanded(
              child: _Stat(value: '${d.visits.thisMonth}', label: t.visitsThisMonth),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(value: '${d.visits.total}', label: t.visitsTotal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                value: d.visits.lastVisitAt == null ? '—' : fmt.shortDate(fmt.toClub(d.visits.lastVisitAt!)),
                label: t.lastVisit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.dashboard, required this.onNavigate});
  final ClientDashboard dashboard;
  final void Function(int) onNavigate;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final trainer = dashboard.trainer;
    final pending = dashboard.pendingTrainerRequest;
    return AppCard(
      onTap: () => onNavigate(2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceHigh,
            child: trainer == null
                ? const Icon(Icons.person_search_rounded, color: AppColors.textSecondary)
                : Text(
                    trainer.firstName.characters.first,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trainer?.fullName ?? t.noTrainer, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  trainer?.specialization ??
                      (pending != null ? t.pendingRequestTo(pending.trainer.fullName) : t.chooseTrainer),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
      ],
    ),
  );
}
