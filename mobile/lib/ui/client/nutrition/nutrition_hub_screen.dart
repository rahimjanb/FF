import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models.dart' show Paged;
import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../formatters.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'ai_consent.dart';
import 'analytics_screen.dart';
import 'barcode_screen.dart';
import 'consultant_screen.dart';
import 'diary_screen.dart';
import 'food_photo.dart';
import 'food_search_sheet.dart';
import 'nutrition_format.dart';
import 'nutrition_profile_screen.dart';
import 'nutrition_widgets.dart';
import 'scan_flow.dart';
import 'scan_result_screen.dart';

/// Opens the AI Food Scanner.
Future<void> openNutritionHub(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const NutritionHubScreen()));

/// AI Food Scanner: camera, gallery, barcode and label; today's calories against the target; recent scans;
/// the way to the diary, analytics and the AI consultant.
class NutritionHubScreen extends StatefulWidget {
  const NutritionHubScreen({super.key, this.picker = pickFoodPhoto, this.useCamera = true});

  /// Photo source; replaced in tests.
  final FoodPhotoPicker picker;

  /// Live camera for barcodes; tests use the manual entry.
  final bool useCamera;

  @override
  State<NutritionHubScreen> createState() => _NutritionHubScreenState();
}

class _NutritionHubScreenState extends State<NutritionHubScreen> {
  NutritionProfile? _profile;
  NutritionDaily? _today;
  Paged<FoodScanSummary>? _history;
  Object? _error;
  bool _loading = true;

  NutritionRepository get _repo => context.read<NutritionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait<Object>([_repo.profile(), _repo.daily(), _repo.history(pageSize: 10)]);
      if (!mounted) return;
      setState(() {
        _profile = r[0] as NutritionProfile;
        _today = r[1] as NutritionDaily;
        _history = r[2] as Paged<FoodScanSummary>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    if (mounted) _load();
  }

  Future<void> _scan(FoodPhotoSource source, {ScanMode mode = ScanMode.dish}) async {
    final agreed = await ensureAiConsent(context, _profile);
    if (agreed == null || !mounted) return;
    setState(() => _profile = agreed);
    await startPhotoScan(
      context,
      source: source,
      profile: agreed,
      picker: widget.picker,
      mode: mode,
      onChanged: _changed,
    );
  }

  Future<void> _barcode() =>
      openBarcodeScanner(context, profile: _profile, picker: widget.picker, onChanged: _changed, useCamera: widget.useCamera);

  Future<void> _manual() async {
    final t = AppLocalizations.of(context);
    final pick = await showFoodSearch(context, title: t.addManually);
    if (pick == null || !mounted) return;
    final saved = await saveFoodPick(context, pick);
    if (saved) _changed();
  }

  Future<void> _openProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await openNutritionProfile(context, profile);
    if (saved != null) _load();
  }

  Future<void> _openDiary() async {
    await openFoodDiary(context, profile: _profile, picker: widget.picker, useCamera: widget.useCamera);
    _changed();
  }

  Future<void> _openConsultant() async {
    final agreed = await ensureAiConsent(context, _profile);
    if (agreed == null || !mounted) return;
    setState(() => _profile = agreed);
    await openConsultant(context, profile: agreed);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final profile = _profile;
    return NutritionPage(
      listKey: const Key('nutrition-hub'),
      title: t.nutritionTitle,
      subtitle: t.nutritionSubtitle,
      onRefresh: _load,
      actions: [
        if (profile != null)
          GlassCircleButton(
            key: const Key('hub-settings'),
            icon: Icons.tune_rounded,
            iconSize: 20,
            tooltip: t.nutritionProfileTitle,
            onTap: _openProfile,
          ),
      ],
      children: [
        if (_error != null && profile == null)
          ErrorView(error: _error!, onRetry: _load)
        else if (_loading && profile == null) ...[
          const GlassSkeleton(height: 190, radius: Brand.radiusHero),
          const SizedBox(height: 16),
          const GlassSkeleton(height: 120),
        ] else if (profile != null) ...[
          _TodayCard(daily: _today, profile: profile, onOpenDiary: _openDiary, onSetup: _openProfile),
          const SizedBox(height: Brand.sectionGap),
          if (profile.aiAvailable) ...[
            _CameraButton(onTap: () => _scan(FoodPhotoSource.camera)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GlassActionTile(
                    key: const Key('hub-gallery'),
                    icon: Icons.photo_library_outlined,
                    color: Brand.clock,
                    label: t.fromGallery,
                    onTap: () => _scan(FoodPhotoSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassActionTile(
                    key: const Key('hub-barcode'),
                    icon: Icons.qr_code_scanner_rounded,
                    color: Brand.successText,
                    label: t.barcodeTitle,
                    onTap: _barcode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassActionTile(
                    key: const Key('hub-label'),
                    icon: Icons.document_scanner_outlined,
                    color: Brand.warningText,
                    label: t.labelShort,
                    onTap: () => _scan(FoodPhotoSource.camera, mode: ScanMode.label),
                  ),
                ),
              ],
            ),
            if (profile.scansPerDay > 0) ...[
              const SizedBox(height: 8),
              Text(
                t.scansLeft(
                  (profile.scansPerDay - profile.scansToday).clamp(0, profile.scansPerDay),
                  profile.scansPerDay,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.textTertiary, fontSize: 12),
              ),
            ],
          ] else ...[
            GlassCard(
              key: const Key('hub-ai-off'),
              radius: 20,
              child: InfoRow(icon: Icons.auto_awesome_outlined, text: t.aiOffInfo, color: Brand.clock),
            ),
            const SizedBox(height: 10),
            GlassActionTile(
              key: const Key('hub-barcode'),
              icon: Icons.qr_code_scanner_rounded,
              color: Brand.successText,
              label: t.barcodeTitle,
              onTap: _barcode,
            ),
          ],
          const SizedBox(height: 10),
          GlassPillButton(
            key: const Key('hub-manual'),
            label: t.addManually,
            icon: Icons.edit_note_rounded,
            onPressed: _manual,
          ),
          const SizedBox(height: Brand.sectionGap),
          GlassList(
            dividerIndent: 68,
            children: [
              _LinkRow(
                key: const Key('hub-diary'),
                icon: Icons.menu_book_rounded,
                color: Brand.accent,
                title: t.foodDiary,
                subtitle: t.foodDiaryHint,
                onTap: _openDiary,
              ),
              _LinkRow(
                key: const Key('hub-analytics'),
                icon: Icons.insights_rounded,
                color: Brand.purple,
                title: t.nutritionAnalytics,
                subtitle: t.nutritionAnalyticsHint,
                onTap: () => openNutritionAnalytics(context, profile: _profile),
              ),
              if (profile.aiAvailable)
                _LinkRow(
                  key: const Key('hub-consultant'),
                  icon: Icons.forum_rounded,
                  color: Brand.clock,
                  title: t.consultantTitle,
                  subtitle: t.consultantHint,
                  onTap: _openConsultant,
                ),
            ],
          ),
          const SizedBox(height: Brand.sectionGap),
          GlassSectionHeader(t.recentScans),
          _History(history: _history, profile: profile, picker: widget.picker, onChanged: _changed),
        ],
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.daily, required this.profile, required this.onOpenDiary, required this.onSetup});
  final NutritionDaily? daily;
  final NutritionProfile profile;
  final VoidCallback onOpenDiary, onSetup;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final d = daily;
    final target = d?.target ?? profile.target;
    final consumed = d?.totals.kcal ?? 0;
    final remaining = target == null ? null : target.kcal - consumed;
    return GlassCard(
      key: const Key('hub-today'),
      radius: Brand.radiusHero,
      glow: true,
      padding: const EdgeInsets.all(20),
      onTap: onOpenDiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KcalRing(consumed: consumed, target: target?.kcal, size: 116),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.todayLabel, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      t.eatenKcal(fmt.kcal(consumed)),
                      key: const Key('hub-eaten'),
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (remaining != null)
                      Text(
                        remaining >= 0 ? t.remainingKcal(fmt.kcal(remaining)) : t.overKcal(fmt.kcal(-remaining)),
                        key: const Key('hub-remaining'),
                        style: TextStyle(
                          color: remaining >= 0 ? Brand.successText : Brand.flame,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(t.noTargetYet, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
                    if (d != null && d.totals.incomplete) ...[
                      const SizedBox(height: 6),
                      SoftTag(t.incompleteData, color: Brand.warningText),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          MacroRow(values: d?.totals.values ?? Nutrients.zero, target: target),
          if (target == null) ...[
            const SizedBox(height: 16),
            GlassPillButton(
              key: const Key('hub-setup-target'),
              label: t.setupTarget,
              icon: Icons.flag_outlined,
              onPressed: onSetup,
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PressScale(
      child: Semantics(
        button: true,
        label: t.scanFood,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: Brand.buttonGradient,
            borderRadius: BorderRadius.circular(Brand.radiusHero),
            boxShadow: [
              BoxShadow(color: Brand.accent.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('hub-camera'),
              borderRadius: BorderRadius.circular(Brand.radiusHero),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.scanFood,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.scanFoodHint,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          IconPlate(icon: icon, color: color, iconColor: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
        ],
      ),
    ),
  );
}

class _History extends StatelessWidget {
  const _History({required this.history, required this.profile, required this.picker, required this.onChanged});
  final Paged<FoodScanSummary>? history;
  final NutritionProfile? profile;
  final FoodPhotoPicker picker;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final items = history?.items ?? const <FoodScanSummary>[];
    if (items.isEmpty) {
      return GlassCard(
        radius: 20,
        child: InfoRow(icon: Icons.history_rounded, text: t.noScansYet, color: Brand.textSecondary),
      );
    }
    return GlassList(
      key: const Key('hub-history'),
      dividerIndent: 80,
      children: [
        for (final s in items) _HistoryRow(scan: s, profile: profile, picker: picker, onChanged: onChanged),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.scan, required this.profile, required this.picker, required this.onChanged});
  final FoodScanSummary scan;
  final NutritionProfile? profile;
  final FoodPhotoPicker picker;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final when = Fmt(lang).dateTime(scan.createdAt);
    final (statusText, statusColor) = switch (scan.status) {
      FoodScanStatus.needsClarification => (t.statusNeedsClarification, Brand.warningText),
      FoodScanStatus.notFood => (t.statusNotFood, Brand.textSecondary),
      FoodScanStatus.failed => (t.statusFailed, Brand.redText),
      FoodScanStatus.recognized => (null, Brand.textSecondary),
    };
    final kindIcon = switch (scan.kind) {
      FoodScanKind.barcode => Icons.qr_code_2_rounded,
      FoodScanKind.label => Icons.document_scanner_outlined,
      FoodScanKind.photo => Icons.restaurant_rounded,
    };
    return InkWell(
      key: Key('history-${scan.id}'),
      onTap: () => openScanResult(context, scan.id, profile: profile, onChanged: onChanged, picker: picker),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            scan.hasPhoto
                ? ScanPhoto(scanId: scan.id, size: 52)
                : SizedBox.square(
                    dimension: 52,
                    child: IconPlate(icon: kindIcon, size: 52, color: Brand.accent, iconColor: Brand.clock),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.title.isEmpty ? t.unknownDish : scan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      when,
                      if (scan.kcal != null) '≈ ${fmt.kcal(scan.kcal!)} ${t.unitKcal}',
                      ?statusText,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (scan.addedToDiaryAt != null)
              Tooltip(
                message: t.inDiary,
                child: const Icon(Icons.check_circle_rounded, color: Brand.successText, size: 20),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Today's calories on the home screen; opens the AI Food Scanner. [daily] null: not loaded (offline or no access).
class NutritionHomeCard extends StatelessWidget {
  const NutritionHomeCard({super.key, required this.daily, required this.onOpen});
  final NutritionDaily? daily;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final d = daily;
    final target = d?.target;
    final consumed = d?.totals.kcal ?? 0;
    final remaining = target == null ? null : target.kcal - consumed;
    return GlassCard(
      key: const Key('home-nutrition'),
      radius: Brand.radiusHero,
      padding: const EdgeInsets.all(18),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KcalRing(consumed: consumed, target: target?.kcal, size: 84),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.nutritionTitle,
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d == null
                          ? t.nutritionHomeHint
                          : remaining == null
                          ? t.eatenKcal(fmt.kcal(consumed))
                          : remaining >= 0
                          ? t.remainingKcal(fmt.kcal(remaining))
                          : t.overKcal(fmt.kcal(-remaining)),
                      style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (d != null) ...[
            const SizedBox(height: 14),
            MacroRow(values: d.totals.values, target: target),
          ],
          const SizedBox(height: 14),
          GradientPillButton(
            key: const Key('home-scan-food'),
            label: t.scanFood,
            icon: Icons.photo_camera_rounded,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
