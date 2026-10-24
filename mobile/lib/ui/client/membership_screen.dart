import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../widgets/common.dart';
import '../widgets/membership_view.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<ClientRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(t.membership)),
      body: AsyncView<List<Membership>>(
        load: repo.memberships,
        builder: (context, list, reload) {
          // The membership in effect today is shown on top; the rest form the history.
          const inEffect = [
            MembershipEffectiveStatus.active,
            MembershipEffectiveStatus.frozen,
            MembershipEffectiveStatus.exhausted,
          ];
          final current = list.where((m) => inEffect.contains(m.effectiveStatus)).firstOrNull;
          final upcoming = list.where((m) => m.effectiveStatus == MembershipEffectiveStatus.upcoming).toList();
          final history = list.where((m) => m != current && !upcoming.contains(m)).toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                MembershipHeroCard(membership: current),
                if (current != null) ...[const SizedBox(height: 12), _Details(m: current)],
                if (upcoming.isNotEmpty) ...[
                  SectionTitle(t.nextMembership),
                  for (final m in upcoming) ...[_HistoryTile(m: m), const SizedBox(height: 8)],
                ],
                if (history.isNotEmpty) ...[
                  SectionTitle(t.membershipHistory),
                  for (final m in history) ...[_HistoryTile(m: m), const SizedBox(height: 8)],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.m});
  final Membership m;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Flexible(
            child: Text(v, textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
    return AppCard(
      child: Column(
        children: [
          row(t.type, m.isUnlimited ? t.unlimited : t.limitedVisits),
          const Divider(),
          row(t.period, '${fmt.date(m.startDate)} — ${fmt.date(m.endDate)}'),
          if (m.visitLimit != null) ...[const Divider(), row(t.visits, t.visitsUsed(m.visitsUsed, m.visitLimit!))],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.m});
  final Membership m;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.planName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${fmt.date(m.startDate)} — ${fmt.date(m.endDate)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          StatusPill(membershipStatusText(t, m.effectiveStatus), color: membershipColor(m.effectiveStatus)),
        ],
      ),
    );
  }
}
