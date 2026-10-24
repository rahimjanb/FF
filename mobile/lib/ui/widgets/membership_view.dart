import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import 'common.dart';
import 'progress_ring.dart';

Color membershipColor(MembershipEffectiveStatus s) => switch (s) {
  MembershipEffectiveStatus.active => AppColors.accent,
  MembershipEffectiveStatus.upcoming || MembershipEffectiveStatus.frozen => AppColors.blue,
  MembershipEffectiveStatus.exhausted => AppColors.orange,
  MembershipEffectiveStatus.cancelled => AppColors.red,
  MembershipEffectiveStatus.expired => AppColors.textSecondary,
};

String membershipStatusText(AppLocalizations t, MembershipEffectiveStatus s) => switch (s) {
  MembershipEffectiveStatus.active => t.statusActive,
  MembershipEffectiveStatus.upcoming => t.statusUpcoming,
  MembershipEffectiveStatus.expired => t.statusExpired,
  MembershipEffectiveStatus.exhausted => t.statusExhausted,
  MembershipEffectiveStatus.frozen => t.statusFrozen,
  MembershipEffectiveStatus.cancelled => t.statusCancelled,
};

/// Hero card for the current membership: ring with remaining days, plan, status and validity.
class MembershipHeroCard extends StatelessWidget {
  const MembershipHeroCard({super.key, required this.membership, this.onTap});
  final Membership? membership;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final m = membership;
    if (m == null) {
      return AppCard(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.credit_card_off_rounded, color: AppColors.textSecondary, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.noMembership, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(t.noMembershipHint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final color = membershipColor(m.effectiveStatus);
    final share = m.totalDays == 0 ? 0.0 : m.daysLeft / m.totalDays;
    return AppCard(
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.18), AppColors.surface],
      ),
      child: Row(
        children: [
          ProgressRing(
            value: share,
            color: color,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${m.daysLeft}', style: Theme.of(context).textTheme.headlineMedium),
                Text(t.daysShort, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(membershipStatusText(t, m.effectiveStatus), color: color),
                const SizedBox(height: 10),
                Text(
                  m.planName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  m.effectiveStatus == MembershipEffectiveStatus.upcoming
                      ? t.startsOn(fmt.date(m.startDate))
                      : t.validUntil(fmt.date(m.endDate)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (m.visitLimit != null) ...[
                  const SizedBox(height: 4),
                  Text(t.visitsUsed(m.visitsUsed, m.visitLimit!), style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
