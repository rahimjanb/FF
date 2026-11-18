import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'qr_pass_sheet.dart';
import 'trainers_screen.dart' show showTrainerSheet;

class _WorkoutsData {
  _WorkoutsData(this.upcoming, this.history, this.trainer, this.usableMembership, {this.withoutTrainer = false});
  final List<TrainingSession> upcoming;
  final Paged<TrainingSession> history;
  final Trainer? trainer;
  final Membership? usableMembership;

  /// The client trains on their own: «Начать тренировку» opens the QR pass instead of asking for a trainer.
  final bool withoutTrainer;

  bool get hasUsableMembership => usableMembership != null;
  bool get solo => trainer == null && withoutTrainer;
}

/// Client's training sessions in the Liquid Glass style. Sessions are created by the assigned trainer;
/// the client views them. Actions without a backend are collected in [_Stub].
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key, this.onNavigate});
  final void Function(int tab)? onNavigate;

  static const membershipTab = 1;
  static const trainersTab = 2;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClientRepository>();
    Future<_WorkoutsData> load() async {
      final r = await Future.wait([repo.upcomingSessions(), repo.sessionHistory(), repo.profile(), repo.memberships()]);
      final profile = r[2] as ClientProfile;
      return _WorkoutsData(
        r[0] as List<TrainingSession>,
        r[1] as Paged<TrainingSession>,
        profile.assignedTrainer,
        (r[3] as List<Membership>).where((m) => m.isUsable).firstOrNull,
        withoutTrainer: profile.withoutTrainer,
      );
    }

    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: AsyncView<_WorkoutsData>(
          load: load,
          loading: (_) => const _LoadingSkeleton(),
          builder: (context, d, reload) => RefreshIndicator(
            color: Brand.accent,
            onRefresh: reload,
            child: _WorkoutsContent(data: d, onNavigate: onNavigate, reload: reload),
          ),
        ),
      ),
    );
  }
}

/// Actions that have no backend or screen yet. Clients cannot book, reschedule or cancel sessions themselves
/// (the trainer schedules them; client cancellation rules are not agreed), and there is no chat or full calendar.
/// Their buttons are shown only when [AppConfig.showUpcoming].
abstract final class _Stub {
  /// Reschedule / cancel on the next session are shown disabled with the «скоро» badge.
  static const sessionActionsEnabled = false;

  static void calendar(BuildContext context) => _snack(context, AppLocalizations.of(context).calendarSoon);
  static void chat(BuildContext context) => _snack(context, AppLocalizations.of(context).chatSoon);

  /// With a membership and a trainer, booking means asking the trainer: sessions appear once they schedule one.
  static void booking(BuildContext context) => _snack(context, AppLocalizations.of(context).workoutsByTrainerHint);
}

double _listBottom(BuildContext context) => MediaQuery.paddingOf(context).bottom + Brand.tabBarReserve + 8;

void _snack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Calendar day of an instant in club time.
DateTime _clubDay(Fmt fmt, DateTime instant) {
  final c = fmt.toClub(instant);
  return DateTime(c.year, c.month, c.day);
}

/// «Сегодня», «Завтра» or «Ср, 28 окт».
String _dayLabel(AppLocalizations t, Fmt fmt, DateTime instant) {
  final day = _clubDay(fmt, instant);
  final today = fmt.clubToday();
  if (day == today) return t.todayLabel;
  if (day == DateTime(today.year, today.month, today.day + 1)) return t.tomorrowLabel;
  final club = fmt.toClub(instant);
  final weekday = _capitalize(DateFormat('EEE', fmt.locale).format(club).replaceAll('.', ''));
  final month = DateFormat('MMM', fmt.locale).format(club).replaceAll('.', '');
  return '$weekday, ${club.day} $month';
}

/// «Сегодня · через 2 ч»: the relative part is added within the next 24 hours.
String _relativeLabel(AppLocalizations t, Fmt fmt, TrainingSession s, DateTime now) {
  if (!s.startsAt.isAfter(now) && s.endsAt.isAfter(now)) return t.happeningNow;
  final day = _dayLabel(t, fmt, s.startsAt);
  final left = s.startsAt.difference(now);
  if (left.isNegative || left >= const Duration(hours: 24)) return day;
  final rel = left.inMinutes < 60 ? t.inMinutes(math.max(1, left.inMinutes)) : t.inHours(left.inHours);
  return '$day · $rel';
}

String? _photoFor(PersonRef person, Trainer? trainer) => person.id == trainer?.id ? trainer?.photoUrl : null;

class _WorkoutsContent extends StatefulWidget {
  const _WorkoutsContent({required this.data, required this.onNavigate, required this.reload});
  final _WorkoutsData data;
  final void Function(int tab)? onNavigate;
  final Future<void> Function() reload;

  @override
  State<_WorkoutsContent> createState() => _WorkoutsContentState();
}

class _WorkoutsContentState extends State<_WorkoutsContent> {
  /// Selected club day; null shows all upcoming sessions.
  DateTime? _selected;
  int _week = 0;

  Future<void> _openTrainer(Trainer trainer) async {
    final changed = await showTrainerSheet(context, trainer: trainer, isMine: true);
    if (changed == true) await widget.reload();
  }

  /// What the main button does; null when all it could do is explain that the trainer schedules sessions.
  VoidCallback? _bookAction() {
    final go = widget.onNavigate;
    final d = widget.data;
    if (!d.hasUsableMembership && go != null) return () => go(WorkoutsScreen.membershipTab);
    if (d.solo) return () => showQrPass(context, membership: d.usableMembership);
    if (d.trainer == null && go != null) return () => go(WorkoutsScreen.trainersTab);
    return AppConfig.showUpcoming ? () => _Stub.booking(context) : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final d = widget.data;
    final go = widget.onNavigate;
    final upcoming = [...d.upcoming]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final busyDays = {
      for (final s in upcoming)
        if (s.status == TrainingSessionStatus.scheduled) _clubDay(fmt, s.startsAt),
    };
    final today = fmt.clubToday();
    final lastWeek = upcoming.isEmpty ? 0 : _clubDay(fmt, upcoming.last.startsAt).difference(today).inDays ~/ 7;
    final maxWeek = math.min(52, math.max(3, lastWeek));
    final shown = _selected == null ? upcoming : upcoming.where((s) => _clubDay(fmt, s.startsAt) == _selected).toList();
    final book = _bookAction();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
      children: [
        _Header(onCalendar: AppConfig.showUpcoming ? () => _Stub.calendar(context) : null),
        const SizedBox(height: Brand.sectionGap),
        if (!d.hasUsableMembership) ...[
          _MembershipWarning(
            key: const Key('membership-warning'),
            onGet: go == null ? null : () => go(WorkoutsScreen.membershipTab),
          ),
          const SizedBox(height: 16),
        ],
        _TrainerCard(
          trainer: d.trainer,
          solo: d.solo,
          onOpen: d.trainer == null
              ? (go == null ? null : () => go(WorkoutsScreen.trainersTab))
              : () => _openTrainer(d.trainer!),
          onChat: AppConfig.showUpcoming ? () => _Stub.chat(context) : null,
        ),
        const SizedBox(height: 16),
        _WeekStrip(
          start: DateTime(today.year, today.month, today.day + 7 * _week),
          today: today,
          selected: _selected,
          busyDays: busyDays,
          onSelect: (day) => setState(() => _selected = day == _selected ? null : day),
          onWeek: (delta) {
            final next = (_week + delta).clamp(0, maxWeek);
            if (next != _week) {
              HapticFeedback.selectionClick();
              setState(() {
                _week = next;
                _selected = null;
              });
            }
          },
        ),
        const SizedBox(height: Brand.sectionGap),
        _CountHeader(title: t.upcoming, count: shown.length),
        if (shown.isEmpty)
          _EmptyCard(
            title: _selected == null ? t.noUpcomingWorkouts : t.noWorkoutsOnDay,
            hint: d.solo
                ? t.soloWorkoutsHint
                : (d.trainer == null ? t.workoutsNoTrainerHint : t.noUpcomingWorkoutsHint),
          )
        else ...[
          _NextSessionCard(session: shown.first, trainer: d.trainer, fmt: fmt),
          if (shown.length > 1) ...[
            const SizedBox(height: 12),
            GlassList(
              dividerIndent: 78,
              children: [
                for (final s in shown.skip(1))
                  WorkoutRow(session: s, fmt: fmt, onTap: () => _showDetails(context, s, d.trainer, fmt)),
              ],
            ),
          ],
        ],
        if (book != null) ...[
          const SizedBox(height: 16),
          GradientPillButton(
            key: const Key('book-workout'),
            label: d.solo ? t.startWorkout : t.bookWorkout,
            icon: d.solo ? Icons.qr_code_2_rounded : Icons.add_rounded,
            height: 54,
            onPressed: book,
          ),
        ],
        if (d.history.items.isNotEmpty) ...[
          const SizedBox(height: Brand.sectionGap + 6),
          GlassSectionHeader(t.history),
          LoadMoreList<TrainingSession>(
            key: ObjectKey(d.history),
            first: d.history,
            loadPage: (page) => context.read<ClientRepository>().sessionHistory(page: page),
            idOf: (s) => s.id,
            itemBuilder: (context, s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 20,
                padding: EdgeInsets.zero,
                child: WorkoutRow(
                  session: s,
                  fmt: fmt,
                  showStatus: true,
                  onTap: () => _showDetails(context, s, d.trainer, fmt),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onCalendar});

  /// Null hides the calendar button.
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.workoutsTitle,
                style: const TextStyle(
                  color: Brand.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(t.workoutsSubtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
            ],
          ),
        ),
        if (onCalendar != null) ...[
          const SizedBox(width: 12),
          GlassCircleButton(icon: Icons.calendar_month_outlined, tooltip: t.openCalendar, onTap: onCalendar!),
        ],
      ],
    );
  }
}

/// Orange glass banner shown only without a usable membership; the title wraps instead of running under the button.
class _MembershipWarning extends StatelessWidget {
  const _MembershipWarning({super.key, required this.onGet});
  final VoidCallback? onGet;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.warning.withValues(alpha: 0.15), Brand.warning.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: Brand.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Brand.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Brand.warningIcon, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.noActiveMembership,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Brand.warningText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.renewAtReception,
                  style: TextStyle(color: Brand.warningText.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          if (onGet != null) ...[
            const SizedBox(width: 12),
            PressScale(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onGet!();
                  },
                  borderRadius: BorderRadius.circular(16),
                  // 44 high touch target around the 32 high capsule.
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Brand.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          t.getMembership,
                          style: const TextStyle(color: Brand.warningText, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _initials(String first, String last) =>
    [first, last].where((s) => s.isNotEmpty).map((s) => s.characters.first.toUpperCase()).join();

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.trainer, required this.onOpen, this.onChat, this.solo = false});
  final Trainer? trainer;
  final bool solo;
  final VoidCallback? onOpen;

  /// Null hides the chat button; the card itself still opens the trainer.
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tr = trainer;
    return PressScale(
      enabled: onOpen != null,
      child: GlassCard(
        radius: 24,
        onTap: onOpen == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onOpen!();
              },
        child: Row(
          children: [
            GlassRingAvatar(
              size: 60,
              photoUrl: tr?.photoUrl,
              initials: tr == null ? '' : _initials(tr.firstName, tr.lastName),
              icon: tr == null ? (solo ? Icons.directions_run_rounded : Icons.person_search_rounded) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tr != null) ...[
                    Text(t.yourTrainer, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    tr?.fullName ?? (solo ? t.withoutTrainerTitle : t.noTrainer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Brand.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (tr == null) ...[
                    const SizedBox(height: 3),
                    Text(
                      t.chooseTrainer,
                      style: const TextStyle(color: Brand.accent, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ] else if (tr.specialization != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      tr.specialization!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (tr != null && onChat != null)
              GlassCircleButton(
                key: const Key('trainer-chat'),
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: Brand.accent,
                iconSize: 20,
                tooltip: t.chatWithTrainer,
                onTap: onChat!,
              )
            else
              Icon(Icons.chevron_right_rounded, color: Brand.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Seven days from [start] in a glass capsule; a dot marks days with a session. Swipe changes the week.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.start,
    required this.today,
    required this.selected,
    required this.busyDays,
    required this.onSelect,
    required this.onWeek,
  });
  final DateTime start, today;
  final DateTime? selected;
  final Set<DateTime> busyDays;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onWeek;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final days = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
    return GestureDetector(
      key: const Key('week-strip'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (e) {
        final v = e.primaryVelocity ?? 0;
        if (v.abs() > 150) onWeek(v < 0 ? 1 : -1);
      },
      child: GlassCard(
        radius: 28,
        padding: const EdgeInsets.all(6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Row(
            key: ValueKey(start),
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _DayCell(
                    day: days[i],
                    weekday: _capitalize(DateFormat('EEE', locale).format(days[i]).replaceAll('.', '')),
                    isToday: days[i] == today,
                    selected: days[i] == selected,
                    busy: busyDays.contains(days[i]),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(days[i]);
                    },
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.weekday,
    required this.isToday,
    required this.selected,
    required this.busy,
    required this.onTap,
  });
  final DateTime day;
  final String weekday;
  final bool isToday, selected, busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      key: Key('day-${day.year}-${day.month}-${day.day}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected ? Brand.buttonGradient : null,
          boxShadow: selected
              ? [BoxShadow(color: Brand.accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))]
              : const [],
        ),
        child: Column(
          children: [
            Text(
              weekday,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : Brand.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                color: selected ? Colors.white : (isToday ? Brand.accent : Brand.textPrimary),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: busy ? (selected ? Colors.white : Brand.accent) : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Brand.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          key: const Key('upcoming-count'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Brand.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Brand.accent, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.hint});
  final String title, hint;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 24,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      children: [
        const IconPlate(icon: Icons.event_available_rounded, color: Brand.accent, iconColor: Brand.accent, size: 52),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35),
        ),
      ],
    ),
  );
}

/// Highlighted next session: time block, relative day, trainer, note and (stubbed) reschedule / cancel.
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.session, required this.trainer, required this.fmt});
  final TrainingSession session;
  final Trainer? trainer;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = session;
    final photo = _photoFor(s.trainer, trainer);
    return PressScale(
      child: GlassCard(
        key: const Key('next-session'),
        radius: 24,
        glow: true,
        glowCenter: const Alignment(-1.1, -1.1),
        borderColor: Brand.accent.withValues(alpha: 0.4),
        onTap: () {
          HapticFeedback.selectionClick();
          _showDetails(context, s, trainer, fmt);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Brand.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Brand.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fmt.time(s.startsAt),
                          maxLines: 1,
                          style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t.minutes(s.durationMinutes),
                          maxLines: 1,
                          style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Brand.accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _relativeLabel(t, fmt, s, DateTime.now()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Brand.accent, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        t.personalWorkout,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Brand.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GlassRingAvatar(
                            size: 20,
                            photoUrl: photo,
                            initials: s.trainer.firstName.isEmpty ? '' : s.trainer.firstName.characters.first,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.trainer.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (s.notes != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 18, color: Brand.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.notes!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Brand.textPrimary, fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_Stub.sessionActionsEnabled || AppConfig.showUpcoming) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SessionActionButton(
                      key: const Key('next-session-reschedule'),
                      label: t.reschedule,
                      icon: Icons.edit_calendar_outlined,
                      color: Brand.textPrimary,
                      enabled: _Stub.sessionActionsEnabled,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SessionActionButton(
                      key: const Key('next-session-cancel'),
                      label: t.cancelShort,
                      icon: Icons.close_rounded,
                      color: Brand.redText,
                      tint: Brand.red,
                      enabled: _Stub.sessionActionsEnabled,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 42 high capsule; [tint] gives the reddish cancel style. Disabled actions carry the «скоро» badge.
class _SessionActionButton extends StatelessWidget {
  const _SessionActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    this.tint,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color? tint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fg = enabled ? color : color.withValues(alpha: 0.45);
    final button = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        color: tint?.withValues(alpha: 0.08) ?? Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: tint?.withValues(alpha: 0.2) ?? Brand.glassStroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? label : '$label, ${t.soon}',
      excludeSemantics: true,
      child: enabled
          ? button
          : Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                button,
                Positioned(top: -8, right: 8, child: SoonBadge(t.soon)),
              ],
            ),
    );
  }
}

/// Session row: date block, title, «time · duration · trainer» and a chevron; history rows add the status.
class WorkoutRow extends StatelessWidget {
  const WorkoutRow({super.key, required this.session, required this.fmt, this.onTap, this.showStatus = false});
  final TrainingSession session;
  final Fmt fmt;
  final VoidCallback? onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = session;
    final club = fmt.toClub(s.startsAt);
    final status = showStatus ? _statusStyle(t, s) : null;
    return PressScale(
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE', fmt.locale).format(club).replaceAll('.', '').toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(color: Brand.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${club.day}',
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.personalWorkout,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    // History rows lead with the status so the title is not squeezed by a trailing label.
                    Text.rich(
                      TextSpan(
                        children: [
                          if (status != null)
                            TextSpan(
                              text: '${status.$1} · ',
                              style: TextStyle(color: status.$2, fontWeight: FontWeight.w600),
                            ),
                          TextSpan(
                            text: '${fmt.time(s.startsAt)} · ${t.minutes(s.durationMinutes)} · ${s.trainer.fullName}',
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Brand.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

(String, Color)? _statusStyle(AppLocalizations t, TrainingSession s) => switch (s.status) {
  TrainingSessionStatus.scheduled when s.hasEndedUnmarked(DateTime.now()) => (t.sessionEnded, Brand.textSecondary),
  TrainingSessionStatus.scheduled => null,
  TrainingSessionStatus.completed => (t.sessionCompleted, Brand.successText),
  TrainingSessionStatus.cancelled => (t.sessionCancelled, Brand.redText),
};

/// Read-only session details.
void _showDetails(BuildContext context, TrainingSession s, Trainer? trainer, Fmt fmt) {
  final t = AppLocalizations.of(context);
  final status = _statusStyle(t, s);
  Widget line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Brand.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Brand.textPrimary, fontSize: 15, height: 1.35)),
        ),
      ],
    ),
  );
  showGlassSheet<void>(
    context,
    builder: (_) => Column(
      key: const Key('session-details'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.personalWorkout,
                style: const TextStyle(
                  color: Brand.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (status != null) StatusChip(label: status.$1, color: status.$2),
          ],
        ),
        const SizedBox(height: 18),
        line(Icons.event_rounded, _capitalize(fmt.weekdayDate(s.startsAt))),
        line(
          Icons.schedule_rounded,
          '${fmt.time(s.startsAt)} – ${fmt.time(s.endsAt)} · ${t.minutes(s.durationMinutes)}',
        ),
        line(Icons.person_outline_rounded, s.trainer.fullName),
        if (s.notes != null) line(Icons.sticky_note_2_outlined, s.notes!),
      ],
    ),
  );
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
    children: const [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassSkeleton(height: 34, width: 190, radius: 10),
                SizedBox(height: 8),
                GlassSkeleton(height: 16, width: 220, radius: 8),
              ],
            ),
          ),
          GlassSkeleton(height: 44, width: 44, radius: 22),
        ],
      ),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 92, radius: 24),
      SizedBox(height: 16),
      GlassSkeleton(height: 76, radius: 28),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 24, width: 150, radius: 8),
      SizedBox(height: 12),
      GlassSkeleton(height: 210, radius: 24),
      SizedBox(height: 16),
      GlassSkeleton(height: 54, radius: 27),
    ],
  );
}

/// Session card shared by the trainer schedule.
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
