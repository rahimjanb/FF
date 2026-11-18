import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'ai_consent.dart';
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';

Future<void> openNutritionAnalytics(BuildContext context, {NutritionProfile? profile}) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => NutritionAnalyticsScreen(profile: profile)));

DateTime _clubToday() {
  final now = DateTime.now().toUtc().add(AppConfig.clubUtcOffset);
  return DateTime(now.year, now.month, now.day);
}

/// Calories and macros over a day, a week or a month: against the target, by meal, per day with workouts and club
/// visits marked, and an AI-written report for the day or the week.
class NutritionAnalyticsScreen extends StatefulWidget {
  const NutritionAnalyticsScreen({super.key, this.profile});
  final NutritionProfile? profile;

  @override
  State<NutritionAnalyticsScreen> createState() => _NutritionAnalyticsScreenState();
}

class _NutritionAnalyticsScreenState extends State<NutritionAnalyticsScreen> {
  int _mode = 1; // 0 day, 1 week, 2 month
  late DateTime _anchor = _clubToday();
  NutritionDaily? _daily;
  NutritionPeriod? _period;
  Object? _error;
  int _request = 0;
  late NutritionProfile? _profile = widget.profile;
  NutritionReport? _report;
  Object? _reportError;
  bool _reportLoading = false;

  NutritionRepository get _repo => context.read<NutritionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _error = null;
      _report = null;
      _reportError = null;
    });
    try {
      if (_mode == 0) {
        final d = await _repo.daily(_anchor);
        if (mounted && request == _request) setState(() => _daily = d);
      } else {
        final p = _mode == 1 ? await _repo.weekly(_anchor) : await _repo.monthly(_anchor);
        if (mounted && request == _request) setState(() => _period = p);
      }
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    }
  }

  void _setMode(int mode) {
    setState(() {
      _mode = mode;
      _anchor = _clubToday();
      _daily = null;
      _period = null;
    });
    _load();
  }

  void _shift(int direction) {
    final today = _clubToday();
    final DateTime next;
    switch (_mode) {
      case 0:
        next = _anchor.add(Duration(days: direction));
      case 1:
        next = _anchor.add(Duration(days: 7 * direction));
      default:
        next = DateTime(_anchor.year, _anchor.month + direction, 1);
    }
    if (next.isAfter(today)) return;
    setState(() {
      _anchor = DateTime(next.year, next.month, next.day);
      _daily = null;
      _period = null;
    });
    _load();
  }

  bool get _atLatest {
    final today = _clubToday();
    return switch (_mode) {
      0 || 1 => !_anchor.isBefore(today),
      _ => _anchor.year == today.year && _anchor.month == today.month,
    };
  }

  String _periodLabel(AppLocalizations t, String lang) {
    final today = _clubToday();
    switch (_mode) {
      case 0:
        return _anchor == today ? t.todayLabel : DateFormat('d MMMM', lang).format(_anchor);
      case 1:
        final from = _anchor.subtract(const Duration(days: 6));
        return '${DateFormat('d MMM', lang).format(from)} – ${DateFormat('d MMM', lang).format(_anchor)}';
      default:
        final s = DateFormat('LLLL y', lang).format(_anchor);
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  Future<void> _loadReport() async {
    final lang = Localizations.localeOf(context).languageCode;
    final agreed = await ensureAiConsent(context, _profile);
    if (agreed == null || !mounted) return;
    _profile = agreed;
    setState(() {
      _reportLoading = true;
      _reportError = null;
    });
    try {
      final period = _mode == 0 ? NutritionReportPeriod.day : NutritionReportPeriod.week;
      final r = await withAiConsent(context, _profile, () => _repo.report(period, _anchor, lang));
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _reportError = e);
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final aiAvailable = _profile?.aiAvailable ?? false;
    final loaded = _mode == 0 ? _daily != null : _period != null;
    return NutritionPage(
      listKey: const Key('nutrition-analytics'),
      title: t.nutritionAnalytics,
      onRefresh: _load,
      children: [
        GlassSegmentedControl(
          segments: [t.periodDay, t.periodWeek, t.periodMonth],
          index: _mode,
          onChanged: _setMode,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              key: const Key('period-prev'),
              tooltip: t.previousPeriod,
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded, color: Brand.textPrimary),
            ),
            Expanded(
              child: Text(
                _periodLabel(t, lang),
                key: const Key('period-label'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              key: const Key('period-next'),
              tooltip: t.nextPeriod,
              onPressed: _atLatest ? null : () => _shift(1),
              icon: Icon(Icons.chevron_right_rounded, color: _atLatest ? Brand.textTertiary : Brand.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null && !loaded)
          ErrorView(error: _error!, onRetry: _load)
        else if (!loaded)
          const GlassSkeleton(height: 260, radius: Brand.radiusHero)
        else if (_mode == 0)
          ..._dayView(t, _daily!)
        else
          ..._periodView(t, _period!),
        if (loaded && aiAvailable && _mode != 2) ...[
          const SizedBox(height: Brand.sectionGap),
          GlassSectionHeader(t.aiReport),
          if (_report != null)
            GlassCard(
              key: const Key('ai-report'),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Brand.clock, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mode == 0 ? t.aiReportDay : t.aiReportWeek,
                          style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_report!.text, style: const TextStyle(color: Brand.textPrimary, fontSize: 14, height: 1.45)),
                  const SizedBox(height: 10),
                  Text(t.notMedicalAdvice, style: TextStyle(color: Brand.textTertiary, fontSize: 11)),
                ],
              ),
            )
          else ...[
            if (_reportError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(errorText(t, _reportError!), style: const TextStyle(color: Brand.redText, fontSize: 13)),
              ),
            GlassPillButton(
              key: const Key('ai-report-button'),
              label: _mode == 0 ? t.aiReportDayButton : t.aiReportWeekButton,
              icon: Icons.auto_awesome_rounded,
              onPressed: _reportLoading ? null : _loadReport,
            ),
            if (_reportLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator(color: Brand.clock)),
              ),
          ],
        ],
      ],
    );
  }

  List<Widget> _dayView(AppLocalizations t, NutritionDaily d) {
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final target = d.target;
    final maxMeal = d.kcalByMeal.values.fold<double>(0, math.max);
    return [
      GlassCard(
        key: const Key('analytics-day'),
        radius: Brand.radiusHero,
        glow: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                KcalRing(consumed: d.totals.kcal, target: target?.kcal, size: 110),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.eatenKcal(fmt.kcal(d.totals.kcal)),
                        style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      if (d.remainingKcal != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          d.remainingKcal! >= 0
                              ? t.remainingKcal(fmt.kcal(d.remainingKcal!))
                              : t.overKcal(fmt.kcal(-d.remainingKcal!)),
                          style: TextStyle(
                            color: d.remainingKcal! >= 0 ? Brand.successText : Brand.flame,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (d.trainingSessions > 0)
                            SoftTag(t.workoutsCount(d.trainingSessions), color: Brand.purple, icon: Icons.fitness_center_rounded),
                          if (d.visited) SoftTag(t.clubVisit, color: Brand.clock, icon: Icons.login_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MacroRow(values: d.totals.values, target: target),
          ],
        ),
      ),
      const SizedBox(height: Brand.sectionGap),
      GlassSectionHeader(t.byMeal),
      GlassCard(
        radius: 20,
        child: Column(
          children: [
            for (final m in MealType.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(mealTypeLabel(t, m), style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            children: [
                              Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.08))),
                              FractionallySizedBox(
                                widthFactor: maxMeal == 0 ? 0 : (d.kcalByMeal[m] ?? 0) / maxMeal,
                                heightFactor: 1,
                                child: const DecoratedBox(decoration: BoxDecoration(gradient: Brand.buttonGradient)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${fmt.kcal(d.kcalByMeal[m] ?? 0)} ${t.unitKcal}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Brand.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: Brand.sectionGap),
      GlassSectionHeader(t.macroSplit),
      GlassCard(radius: 20, child: _MacroSplit(values: d.totals.values)),
    ];
  }

  List<Widget> _periodView(AppLocalizations t, NutritionPeriod p) {
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final avg = p.average;
    return [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              key: const Key('stat-average'),
              icon: Icons.local_fire_department_outlined,
              color: Brand.flame,
              value: avg == null ? '—' : fmt.kcal(avg.kcal),
              label: t.averageKcal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              key: const Key('stat-logged'),
              icon: Icons.event_note_rounded,
              color: Brand.clock,
              value: '${p.daysLogged}/${p.days.length}',
              label: t.daysLogged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              key: const Key('stat-within'),
              icon: Icons.track_changes_rounded,
              color: Brand.successText,
              value: p.target == null ? '—' : '${p.daysWithinTarget}',
              label: t.daysWithinTarget,
            ),
          ),
        ],
      ),
      const SizedBox(height: Brand.sectionGap),
      GlassSectionHeader(t.caloriesPerDay),
      GlassCard(
        key: const Key('kcal-chart'),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: t.chartSemantics(p.daysLogged, avg == null ? '—' : fmt.kcal(avg.kcal)),
              excludeSemantics: true,
              child: SizedBox(
                height: 180,
                child: CustomPaint(painter: _KcalBarsPainter(days: p.days, target: p.target?.kcal)),
              ),
            ),
            const SizedBox(height: 6),
            _DayLabels(days: p.days, lang: lang),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _Legend(color: Brand.successText, label: t.legendWithin),
                _Legend(color: Brand.flame, label: t.legendOver),
                _Legend(color: Brand.clock, label: t.legendUnder),
                _Legend(color: Brand.purple, label: t.legendWorkout, dot: true),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: Brand.sectionGap),
      GlassSectionHeader(t.macrosPerDay),
      GlassCard(
        key: const Key('macro-chart'),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 140, child: CustomPaint(painter: _MacroBarsPainter(days: p.days))),
            const SizedBox(height: 6),
            _DayLabels(days: p.days, lang: lang),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                _Legend(color: MacroColors.protein, label: t.protein),
                _Legend(color: MacroColors.fat, label: t.fat),
                _Legend(color: MacroColors.carbs, label: t.carbs),
              ],
            ),
          ],
        ),
      ),
      if (avg != null) ...[
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.averagePerDay),
        GlassCard(
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MacroRow(values: avg, target: p.target),
              const SizedBox(height: 14),
              _MacroSplit(values: avg),
            ],
          ),
        ),
      ],
      if (p.trainingSessions > 0 || p.visits > 0) ...[
        const SizedBox(height: 12),
        InfoRow(
          icon: Icons.fitness_center_rounded,
          color: Brand.purple,
          text: t.periodActivity(p.trainingSessions, p.visits),
        ),
      ],
    ];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 20,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 2, style: TextStyle(color: Brand.textSecondary, fontSize: 11, height: 1.2)),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dot = false});
  final Color color;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: dot ? 7 : 10,
        height: dot ? 7 : 10,
        decoration: BoxDecoration(
          color: color,
          shape: dot ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: dot ? null : BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: Brand.textSecondary, fontSize: 11)),
    ],
  );
}

/// Weekday letters under a week, day numbers (every few days) under a month.
class _DayLabels extends StatelessWidget {
  const _DayLabels({required this.days, required this.lang});
  final List<NutritionDayStat> days;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final step = days.length <= 7 ? 1 : 5;
    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Text(
              days.length <= 7
                  ? DateFormat('EEEEE', lang).format(days[i].date).toUpperCase()
                  : (i % step == 0 || i == days.length - 1 ? '${days[i].date.day}' : ''),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(color: Brand.textTertiary, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

/// Share of calories from protein, fat and carbs (4 / 9 / 4 kcal per gram).
class _MacroSplit extends StatelessWidget {
  const _MacroSplit({required this.values});
  final Nutrients values;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = values.protein * 4, f = values.fat * 9, c = values.carbs * 4;
    final total = p + f + c;
    if (total <= 0) {
      return Text(t.noDataYet, style: TextStyle(color: Brand.textSecondary, fontSize: 13));
    }
    String pct(double v) => '${(v / total * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(flex: (p / total * 1000).round().clamp(1, 1000), child: const ColoredBox(color: MacroColors.protein)),
                Expanded(flex: (f / total * 1000).round().clamp(1, 1000), child: const ColoredBox(color: MacroColors.fat)),
                Expanded(flex: (c / total * 1000).round().clamp(1, 1000), child: const ColoredBox(color: MacroColors.carbs)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Wraps on narrow screens and with large text instead of overflowing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('${t.protein} ${pct(p)}', style: const TextStyle(color: MacroColors.protein, fontSize: 12)),
            Text('${t.fat} ${pct(f)}', style: const TextStyle(color: MacroColors.fat, fontSize: 12)),
            Text('${t.carbs} ${pct(c)}', style: const TextStyle(color: MacroColors.carbs, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

/// Calories per day as bars against the dashed target line; a dot over the bar marks a workout.
class _KcalBarsPainter extends CustomPainter {
  _KcalBarsPainter({required this.days, required this.target});
  final List<NutritionDayStat> days;
  final int? target;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const top = 14.0;
    final maxValue = math.max(
      days.fold<double>(0, (m, d) => math.max(m, d.kcal)),
      (target ?? 0) * 1.15,
    );
    final scale = maxValue <= 0 ? 0.0 : (size.height - top) / maxValue;
    final slot = size.width / days.length;
    final barWidth = math.min(slot * 0.62, 26.0);
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final cx = slot * i + slot / 2;
      final h = math.max(d.kcal * scale, d.entries > 0 ? 3.0 : 0.0);
      final dayTarget = d.targetKcal ?? target;
      final Color color;
      if (d.entries == 0) {
        color = Colors.white.withValues(alpha: 0.12);
      } else if (dayTarget == null) {
        color = Brand.accent;
      } else if ((d.kcal - dayTarget).abs() <= dayTarget * 0.1) {
        color = Brand.successText;
      } else if (d.kcal > dayTarget) {
        color = Brand.flame;
      } else {
        color = Brand.clock;
      }
      // Track of the slot, so empty days are visible too.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barWidth / 2, top, barWidth, size.height - top),
          const Radius.circular(6),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.04),
      );
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barWidth / 2, size.height - h, barWidth, h),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
          ),
          Paint()..color = color,
        );
      }
      if (d.trainingSessions > 0) {
        canvas.drawCircle(Offset(cx, math.max(top - 6, size.height - h - 8)), 3.2, Paint()..color = Brand.purple);
      } else if (d.visited) {
        canvas.drawCircle(
          Offset(cx, math.max(top - 6, size.height - h - 8)),
          2.4,
          Paint()..color = Brand.purple.withValues(alpha: 0.5),
        );
      }
    }
    if (target != null && scale > 0) {
      final y = size.height - target! * scale;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.2;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KcalBarsPainter old) => old.days != days || old.target != target;
}

/// Protein, fat and carbs (grams) per day as stacked bars.
class _MacroBarsPainter extends CustomPainter {
  _MacroBarsPainter({required this.days});
  final List<NutritionDayStat> days;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final maxValue = days.fold<double>(0, (m, d) => math.max(m, d.protein + d.fat + d.carbs));
    if (maxValue <= 0) return;
    final scale = size.height / maxValue;
    final slot = size.width / days.length;
    final barWidth = math.min(slot * 0.62, 26.0);
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x = slot * i + slot / 2 - barWidth / 2;
      var y = size.height;
      for (final (value, color) in [
        (d.carbs, MacroColors.carbs),
        (d.fat, MacroColors.fat),
        (d.protein, MacroColors.protein),
      ]) {
        final h = value * scale;
        if (h <= 0) continue;
        canvas.drawRect(Rect.fromLTWH(x, y - h, barWidth, h), Paint()..color = color);
        y -= h;
      }
    }
  }

  @override
  bool shouldRepaint(_MacroBarsPainter old) => old.days != days;
}
