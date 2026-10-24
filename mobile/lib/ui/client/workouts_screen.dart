import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'trainers_screen.dart' show TrainerAvatar;

class _WorkoutsData {
  _WorkoutsData(this.upcoming, this.history, this.trainer, this.hasUsableMembership);
  final List<TrainingSession> upcoming;
  final Paged<TrainingSession> history;
  final Trainer? trainer;
  final bool hasUsableMembership;
}

/// Client's training sessions. Sessions are created by the assigned trainer; the client only views them.
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key, this.onNavigate});
  final void Function(int tab)? onNavigate;

  static const trainersTab = 2;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<ClientRepository>();
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    Future<_WorkoutsData> load() async {
      final r = await Future.wait([repo.upcomingSessions(), repo.sessionHistory(), repo.profile(), repo.memberships()]);
      return _WorkoutsData(
        r[0] as List<TrainingSession>,
        r[1] as Paged<TrainingSession>,
        (r[2] as ClientProfile).assignedTrainer,
        (r[3] as List<Membership>).any((m) => m.isUsable),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.workoutsTitle)),
      body: AsyncView<_WorkoutsData>(
        load: load,
        builder: (context, d, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (!d.hasUsableMembership) ...[
                _Banner(key: const Key('membership-warning'), text: t.membershipInactiveWarning),
                const SizedBox(height: 12),
              ],
              _TrainerCard(trainer: d.trainer, onChoose: onNavigate == null ? null : () => onNavigate!(trainersTab)),
              SectionTitle(t.upcoming),
              if (d.upcoming.isEmpty)
                MessageView(
                  icon: Icons.event_available_rounded,
                  title: t.noUpcomingWorkouts,
                  subtitle: d.trainer == null ? t.workoutsNoTrainerHint : t.noUpcomingWorkoutsHint,
                )
              else
                for (final s in d.upcoming) ...[
                  SessionTile(session: s, fmt: fmt, showTrainer: true),
                  const SizedBox(height: 10),
                ],
              if (d.history.items.isNotEmpty) ...[
                SectionTitle(t.history),
                LoadMoreList<TrainingSession>(
                  key: ObjectKey(d.history),
                  first: d.history,
                  loadPage: (page) => repo.sessionHistory(page: page),
                  idOf: (s) => s.id,
                  itemBuilder: (context, s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SessionTile(session: s, fmt: fmt, showTrainer: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.trainer, required this.onChoose});
  final Trainer? trainer;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tr = trainer;
    return AppCard(
      onTap: tr == null ? onChoose : null,
      child: Row(
        children: [
          tr == null
              ? const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceHigh,
                  child: Icon(Icons.person_search_rounded, color: AppColors.textSecondary),
                )
              : TrainerAvatar(name: tr.firstName, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.yourTrainer, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(tr?.fullName ?? t.noTrainer, style: Theme.of(context).textTheme.titleMedium),
                if (tr?.specialization != null) Text(tr!.specialization!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (tr == null && onChoose != null) TextButton(onPressed: onChoose, child: Text(t.chooseTrainer)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.orange)),
        ),
      ],
    ),
  );
}

/// Session card shared by client and trainer screens.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.fmt,
    this.showTrainer = false,
    this.onTap,
    this.now,
  });
  final TrainingSession session;
  final Fmt fmt;
  final bool showTrainer;
  final VoidCallback? onTap;

  /// Injected in tests; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = session;
    final ended = s.hasEndedUnmarked(now ?? DateTime.now());
    final (String? label, Color color) = switch (s.status) {
      TrainingSessionStatus.scheduled when ended => (t.sessionEnded, AppColors.textSecondary),
      TrainingSessionStatus.scheduled => (null, AppColors.accent),
      TrainingSessionStatus.completed => (t.sessionCompleted, AppColors.blue),
      TrainingSessionStatus.cancelled => (t.sessionCancelled, AppColors.red),
    };
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text(fmt.time(s.startsAt), style: Theme.of(context).textTheme.titleMedium),
                Text(
                  t.minutes(s.durationMinutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(t, s.startsAt), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  showTrainer ? t.withTrainer(s.trainer.fullName) : t.withClient(s.client.fullName),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (s.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    s.notes!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (ended && onTap != null) ...[
                  const SizedBox(height: 4),
                  Text(t.markResultHint, style: const TextStyle(color: AppColors.orange, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (label != null) StatusPill(label, color: color),
        ],
      ),
    );
  }

  String _dayLabel(AppLocalizations t, DateTime instant) {
    final club = fmt.toClub(instant);
    final day = DateTime(club.year, club.month, club.day);
    final today = fmt.clubToday();
    if (day == today) return t.todayLabel;
    if (day == today.add(const Duration(days: 1))) return t.tomorrowLabel;
    return fmt.weekdayDate(instant);
  }
}
