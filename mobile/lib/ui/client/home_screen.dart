import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/membership_view.dart';
import 'notifications_screen.dart';

class _HomeData {
  _HomeData(this.dashboard, this.visitTimes);
  final ClientDashboard dashboard;
  final List<DateTime> visitTimes;
}

/// Client home in the Liquid Glass style. Tabs: 1 membership, 2 trainers, 3 workouts.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final void Function(int tab) onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClientRepository>();
    Future<_HomeData> load() async {
      final r = await Future.wait<Object>([repo.dashboard(), repo.recentVisitTimes()]);
      return _HomeData(r[0] as ClientDashboard, r[1] as List<DateTime>);
    }

    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: AsyncView<_HomeData>(
          load: load,
          builder: (context, d, reload) => RefreshIndicator(
            color: Brand.accent,
            onRefresh: reload,
            child: _HomeContent(data: d, onNavigate: onNavigate, reload: reload),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.onNavigate, required this.reload});
  final _HomeData data;
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
    final locale = Localizations.localeOf(context).languageCode;
    final fmt = Fmt(locale);
    final d = data.dashboard;
    // Bottom padding keeps the last block above the floating tab bar.
    final bottom = MediaQuery.paddingOf(context).bottom + Brand.tabBarReserve + 8;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, bottom),
      children: [
        Row(
          children: [
            Semantics(
              label: 'Fitness Formula',
              image: true,
              child: Image.asset('assets/images/ff-logo-white.png', height: 33, fit: BoxFit.contain),
            ),
            const Spacer(),
            GlassCircleButton(
              icon: Icons.notifications_none_rounded,
              tooltip: t.notifications,
              dot: d.unreadNotifications > 0,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                await reload();
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          _capitalize(DateFormat('EEEE, d MMMM', locale).format(fmt.clubToday())),
          style: TextStyle(color: Brand.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          _greeting(t, d.firstName),
          style: const TextStyle(
            color: Brand.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: Brand.sectionGap),
        _MembershipCard(membership: d.currentMembership ?? d.nextMembership, onOpen: () => onNavigate(1)),
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.nextWorkout, action: t.schedule, onAction: () => onNavigate(3)),
        _NextWorkoutCard(dashboard: d, fmt: fmt, onNavigate: onNavigate),
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.yourTrainer),
        _TrainerCard(dashboard: d, onTap: () => onNavigate(2)),
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.visits, action: _capitalize(DateFormat('LLLL', locale).format(fmt.clubToday()))),
        _VisitsBlock(stats: d.visits, visitTimes: data.visitTimes, fmt: fmt, locale: locale),
      ],
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

(Color, Color) _statusColors(MembershipEffectiveStatus? s) => switch (s) {
  MembershipEffectiveStatus.active => (Brand.accent, const Color(0xFF7FD6F2)),
  MembershipEffectiveStatus.upcoming || MembershipEffectiveStatus.frozen => (Brand.blue, Brand.blueIcon),
  MembershipEffectiveStatus.exhausted => (Brand.flame, Brand.flame),
  _ => (Brand.red, Brand.redText),
};

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.membership, required this.onOpen});
  final Membership? membership;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final m = membership;
    final (color, textColor) = _statusColors(m?.effectiveStatus);
    const titleStyle = TextStyle(
      color: Brand.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    );
    final subtitleStyle = TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35);
    return GlassCard(
      radius: Brand.radiusHero,
      padding: const EdgeInsets.all(20),
      glow: true,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: StatusChip(
                  label: m == null ? t.statusInactive : membershipStatusText(t, m.effectiveStatus),
                  color: color,
                  textColor: textColor,
                ),
              ),
              const Spacer(),
              const GlassCircleButton(icon: Icons.credit_card_rounded, size: 40, iconSize: 20),
            ],
          ),
          const SizedBox(height: 18),
          if (m == null) ...[
            Text(t.noMembership, style: titleStyle),
            const SizedBox(height: 6),
            Text(t.noMembershipHint, style: subtitleStyle),
          ] else ...[
            Text(m.planName, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(
              m.effectiveStatus == MembershipEffectiveStatus.upcoming
                  ? t.startsOn(fmt.date(m.startDate))
                  : t.validUntil(fmt.date(m.endDate)),
              style: subtitleStyle,
            ),
            const SizedBox(height: 14),
            _Progress(value: m.totalDays == 0 ? 0 : 1 - m.daysLeft / m.totalDays, color: color),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(t.daysLeft(m.daysLeft), style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
                ),
                if (m.visitLimit != null)
                  Text(
                    t.visitsUsed(m.visitsUsed, m.visitLimit!),
                    style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GradientPillButton(label: t.myMembership, icon: Icons.north_east_rounded, onPressed: onOpen),
              ),
              const SizedBox(width: 10),
              // QR entry needs the turnstile integration (stage 2); shown disabled until then.
              GlassPillButton(label: t.qrEntry, icon: Icons.qr_code_2_rounded, badge: t.soon),
            ],
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox(
      height: 6,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.1))),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            widthFactor: value.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color])),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard({required this.dashboard, required this.fmt, required this.onNavigate});
  final ClientDashboard dashboard;
  final Fmt fmt;
  final void Function(int) onNavigate;

  String _day(AppLocalizations t, DateTime instant) {
    final club = fmt.toClub(instant);
    final day = DateTime(club.year, club.month, club.day);
    final today = fmt.clubToday();
    if (day == today) return t.todayLabel;
    if (day == today.add(const Duration(days: 1))) return t.tomorrowLabel;
    return _capitalize(fmt.weekdayDate(instant));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = dashboard.nextSession;
    final noTrainer = dashboard.trainer == null;
    final title = s == null ? t.noWorkoutsYet : '${_day(t, s.startsAt)}, ${fmt.time(s.startsAt)}';
    final subtitle = s != null
        ? t.withTrainerShort(s.trainer.fullName)
        : (noTrainer ? t.chooseTrainerForWorkoutsHint : t.workoutsByTrainerHint);
    return GlassCard(
      onTap: () => onNavigate(3),
      child: Row(
        children: [
          IconPlate(icon: s == null ? Icons.event_available_rounded : Icons.event_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          if (s == null) ...[
            const SizedBox(width: 10),
            // Without a trainer the next step is choosing one; with a trainer it is the schedule.
            _RoundGradientButton(
              icon: noTrainer ? Icons.add_rounded : Icons.chevron_right_rounded,
              tooltip: noTrainer ? t.chooseTrainer : t.schedule,
              onTap: () => onNavigate(noTrainer ? 2 : 3),
            ),
          ],
        ],
      ),
    );
  }
}

/// 36×36 gradient circle inside a 44×44 touch target.
class _RoundGradientButton extends StatelessWidget {
  const _RoundGradientButton({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: Brand.buttonGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Brand.accent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    ),
  );
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.dashboard, required this.onTap});
  final ClientDashboard dashboard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final trainer = dashboard.trainer;
    final pending = dashboard.pendingTrainerRequest;
    // With an assigned trainer only their specialization is shown; a pending request matters only without one.
    final String? subtitle = trainer != null
        ? trainer.specialization
        : (pending != null ? t.pendingRequestTo(pending.trainer.fullName) : t.findYourTrainer);
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Brand.accent, Brand.glowBlue],
              ),
              image: trainer?.photoUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(AppConfig.resolve(trainer!.photoUrl!)),
                      fit: BoxFit.cover,
                      onError: (_, _) {},
                    ),
            ),
            alignment: Alignment.center,
            child: trainer == null
                ? const Icon(Icons.person_search_rounded, color: Colors.white, size: 24)
                : trainer.photoUrl != null
                ? null
                : Text(
                    trainer.firstName.characters.first,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainer?.fullName ?? t.noTrainer,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) const SizedBox(height: 3),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Brand.textSecondary, fontSize: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Brand.glassStroke),
            ),
            child: Icon(Icons.chevron_right_rounded, color: Brand.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _VisitsBlock extends StatelessWidget {
  const _VisitsBlock({required this.stats, required this.visitTimes, required this.fmt, required this.locale});
  final VisitStats stats;
  final List<DateTime> visitTimes;
  final Fmt fmt;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Current week Monday..Sunday in club time; a day is lit if there was at least one visit.
    final today = fmt.clubToday();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final visited = List.filled(7, false);
    for (final v in visitTimes) {
      final c = fmt.toClub(v);
      final i = DateTime(c.year, c.month, c.day).difference(monday).inDays;
      if (i >= 0 && i < 7) visited[i] = true;
    }
    final last = stats.lastVisitAt == null ? '—' : fmt.shortDate(fmt.toClub(stats.lastVisitAt!));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.visitsThisMonth, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
                      ),
                      const Icon(Icons.local_fire_department_outlined, color: Brand.flame, size: 20),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${stats.thisMonth}',
                    style: const TextStyle(
                      color: Brand.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 26,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  gradient: visited[i] ? Brand.buttonGradient : null,
                                  color: visited[i] ? null : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('EEEEE', locale).format(monday.add(Duration(days: i))).toUpperCase(),
                                style: TextStyle(color: Brand.textTertiary, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 128,
            child: Column(
              children: [
                _MiniStat(
                  icon: Icons.emoji_events_outlined,
                  color: Brand.trophy,
                  value: '${stats.total}',
                  label: t.visitsTotal,
                ),
                const SizedBox(height: 10),
                _MiniStat(icon: Icons.history_rounded, color: Brand.clock, value: last, label: t.lastVisit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Brand.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
        ],
      ),
    ),
  );
}
