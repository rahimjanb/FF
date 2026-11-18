import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../formatters.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'barcode_screen.dart';
import 'food_photo.dart';
import 'food_search_sheet.dart';
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';
import 'scan_result_screen.dart';

/// Opens the food diary on [date] (today by default).
Future<void> openFoodDiary(
  BuildContext context, {
  NutritionProfile? profile,
  FoodPhotoPicker picker = pickFoodPhoto,
  bool useCamera = true,
  DateTime? date,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FoodDiaryScreen(profile: profile, picker: picker, useCamera: useCamera, initialDate: date),
  ),
);

DateTime _clubToday() {
  final now = DateTime.now().toUtc().add(AppConfig.clubUtcOffset);
  return DateTime(now.year, now.month, now.day);
}

enum _AddSource { search, recent, scans, barcode }

/// The day's meals: breakfast, lunch, dinner and snacks with their entries and totals against the target.
class FoodDiaryScreen extends StatefulWidget {
  const FoodDiaryScreen({super.key, this.profile, this.picker = pickFoodPhoto, this.useCamera = true, this.initialDate});
  final NutritionProfile? profile;
  final FoodPhotoPicker picker;
  final bool useCamera;
  final DateTime? initialDate;

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> {
  late DateTime _date = widget.initialDate ?? _clubToday();
  DiaryDay? _day;
  Object? _error;
  int _request = 0;

  NutritionRepository get _repo => context.read<NutritionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _error = null);
    try {
      final day = await _repo.diaryDay(_date);
      if (mounted && request == _request) setState(() => _day = day);
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    }
  }

  void _shift(int days) {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(_clubToday())) return;
    setState(() {
      _date = DateTime(next.year, next.month, next.day);
      _day = null;
    });
    _load();
  }

  Future<void> _add(MealType meal) async {
    final source = await showGlassSheet<_AddSource>(context, builder: (_) => _AddSheet(meal: meal));
    if (source == null || !mounted) return;
    final t = AppLocalizations.of(context);
    switch (source) {
      case _AddSource.search:
        final pick = await showFoodSearch(context, title: t.addToMeal(mealTypeLabel(t, meal)));
        if (pick == null || !mounted) return;
        if (await saveFoodPick(context, pick, meal: meal, date: _date)) _load();
      case _AddSource.recent:
        final entry = await showGlassSheet<DiaryEntry>(context, builder: (_) => const _RecentSheet());
        if (entry == null || !mounted) return;
        try {
          await _repo.repeatEntry(entry.id, date: _date, mealType: meal);
          if (mounted) showSnack(context, t.addedToDiary(mealTypeLabel(t, meal)));
          _load();
        } catch (e) {
          if (mounted) showSnack(context, errorText(t, e));
        }
      case _AddSource.scans:
        final scanId = await showGlassSheet<String>(context, builder: (_) => const _ScansSheet());
        if (scanId == null || !mounted) return;
        await openScanResult(context, scanId, profile: widget.profile, onChanged: _load, picker: widget.picker);
      case _AddSource.barcode:
        await openBarcodeScanner(
          context,
          profile: widget.profile,
          picker: widget.picker,
          onChanged: _load,
          useCamera: widget.useCamera,
        );
    }
  }

  Future<void> _open(DiaryEntry entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiaryEntryScreen(entry: entry)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final today = _clubToday();
    final dayLabel = _date == today
        ? t.todayLabel
        : _date == today.subtract(const Duration(days: 1))
        ? t.yesterday
        : DateFormat('EEEE, d MMMM', lang).format(_date);
    final day = _day;
    return NutritionPage(
      listKey: const Key('food-diary'),
      title: t.foodDiary,
      onRefresh: _load,
      children: [
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                key: const Key('diary-prev'),
                tooltip: t.previousDay,
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded, color: Brand.textPrimary),
              ),
              Expanded(
                child: Text(
                  dayLabel,
                  key: const Key('diary-date'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                key: const Key('diary-next'),
                tooltip: t.nextDay,
                onPressed: _date == today ? null : () => _shift(1),
                icon: Icon(Icons.chevron_right_rounded, color: _date == today ? Brand.textTertiary : Brand.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null && day == null)
          ErrorView(error: _error!, onRetry: _load)
        else if (day == null)
          const GlassSkeleton(height: 220, radius: Brand.radiusHero)
        else ...[
          _DayTotals(day: day),
          for (final m in MealType.values) ...[
            const SizedBox(height: Brand.sectionGap),
            _MealSection(meal: day.meal(m), onAdd: () => _add(m), onOpen: _open),
          ],
        ],
      ],
    );
  }
}

class _DayTotals extends StatelessWidget {
  const _DayTotals({required this.day});
  final DiaryDay day;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final target = day.target;
    final consumed = day.totals.kcal;
    final remaining = target == null ? null : target.kcal - consumed;
    return GlassCard(
      key: const Key('diary-totals'),
      radius: Brand.radiusHero,
      glow: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              KcalRing(consumed: consumed, target: target?.kcal, size: 104),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.eatenKcal(fmt.kcal(consumed)),
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (remaining != null)
                      Text(
                        remaining >= 0 ? t.remainingKcal(fmt.kcal(remaining)) : t.overKcal(fmt.kcal(-remaining)),
                        style: TextStyle(
                          color: remaining >= 0 ? Brand.successText : Brand.flame,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (NutritionFmt.isWide(day.totals))
                      Text(
                        t.kcalRangeLabel(fmt.kcalRange(day.totals)!),
                        style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                      ),
                    if (day.totals.incomplete) ...[
                      const SizedBox(height: 6),
                      SoftTag(t.incompleteData, color: Brand.warningText),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MacroRow(values: day.totals.values, target: target),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.onAdd, required this.onOpen});
  final DiaryMeal meal;
  final VoidCallback onAdd;
  final ValueChanged<DiaryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final label = mealTypeLabel(t, meal.mealType);
    return Column(
      key: Key('meal-section-${meal.mealType.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(mealTypeIcon(meal.mealType), color: Brand.clock, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meal.entries.isEmpty ? label : '$label · ${fmt.kcal(meal.totals.kcal)} ${t.unitKcal}',
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                key: Key('meal-add-${meal.mealType.name}'),
                onPressed: onAdd,
                style: TextButton.styleFrom(foregroundColor: Brand.accent, minimumSize: const Size(44, 44)),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(t.addIngredientShort),
              ),
            ],
          ),
        ),
        if (meal.entries.isEmpty)
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: onAdd,
            child: Text(t.mealEmpty, style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
          )
        else
          GlassList(
            dividerIndent: 80,
            children: [for (final e in meal.entries) _EntryRow(entry: e, onTap: () => onOpen(e))],
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});
  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final v = entry.totals.values;
    return InkWell(
      key: Key('entry-${entry.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            entry.hasPhoto && entry.scanId != null
                ? ScanPhoto(scanId: entry.scanId, size: 52)
                : SizedBox.square(
                    dimension: 52,
                    child: IconPlate(icon: mealTypeIcon(entry.mealType), size: 52, color: Brand.accent, iconColor: Brand.clock),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt(lang).time(entry.eatenAt)} · ${fmt.grams(entry.totals.grams)}',
                    style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.proteinShort} ${fmt.macro(v.protein)} · ${t.fatShort} ${fmt.macro(v.fat)} · '
                    '${t.carbsShort} ${fmt.macro(v.carbs)}',
                    style: TextStyle(color: Brand.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.kcal(entry.totals.kcal, rough: NutritionFmt.isWide(entry.totals)),
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(t.unitKcal, style: TextStyle(color: Brand.textSecondary, fontSize: 11)),
                if (entry.totals.incomplete) const Icon(Icons.info_outline_rounded, size: 14, color: Brand.warningText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({required this.meal});
  final MealType meal;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget row(String key, IconData icon, Color color, String title, _AddSource source) => ListTile(
      key: Key(key),
      leading: IconPlate(icon: icon, color: color, iconColor: color, size: 38),
      title: Text(title, style: const TextStyle(color: Brand.textPrimary, fontWeight: FontWeight.w600)),
      onTap: () => Navigator.of(context).pop(source),
    );
    return Column(
      key: const Key('diary-add-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.addToMeal(mealTypeLabel(t, meal)),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        row('add-search', Icons.search_rounded, Brand.accent, t.addFromSearch, _AddSource.search),
        row('add-recent', Icons.replay_rounded, Brand.purple, t.addFromRecent, _AddSource.recent),
        row('add-scans', Icons.photo_library_outlined, Brand.clock, t.addFromScans, _AddSource.scans),
        row('add-barcode', Icons.qr_code_scanner_rounded, Brand.successText, t.barcodeTitle, _AddSource.barcode),
      ],
    );
  }
}

class _RecentSheet extends StatelessWidget {
  const _RecentSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    return Column(
      key: const Key('recent-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.addFromRecent,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: AsyncView<List<DiaryEntry>>(
            load: () => context.read<NutritionRepository>().recentEntries(),
            builder: (context, entries, _) => entries.isEmpty
                ? Center(child: Text(t.noRecent, style: TextStyle(color: Brand.textSecondary)))
                : ListView(
                    children: [
                      for (final e in entries)
                        ListTile(
                          key: Key('recent-${e.id}'),
                          title: Text(e.name, style: const TextStyle(color: Brand.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${fmt.grams(e.totals.grams)} · ${fmt.kcal(e.totals.kcal)} ${t.unitKcal}',
                            style: TextStyle(color: Brand.textSecondary),
                          ),
                          trailing: const Icon(Icons.add_circle_outline_rounded, color: Brand.accent),
                          onTap: () => Navigator.of(context).pop(e),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ScansSheet extends StatelessWidget {
  const _ScansSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    return Column(
      key: const Key('scans-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.addFromScans,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: AsyncView(
            load: () => context.read<NutritionRepository>().history(pageSize: 30),
            builder: (context, page, _) => page.items.isEmpty
                ? Center(child: Text(t.noScansYet, textAlign: TextAlign.center, style: TextStyle(color: Brand.textSecondary)))
                : ListView(
                    children: [
                      for (final s in page.items.where((s) => s.status != FoodScanStatus.notFood))
                        ListTile(
                          key: Key('scan-pick-${s.id}'),
                          leading: s.hasPhoto ? ScanPhoto(scanId: s.id, size: 44, radius: 12) : null,
                          title: Text(
                            s.title.isEmpty ? t.unknownDish : s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Brand.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [Fmt(lang).dateTime(s.createdAt), if (s.kcal != null) '≈ ${fmt.kcal(s.kcal!)} ${t.unitKcal}'].join(' · '),
                            style: TextStyle(color: Brand.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).pop(s.id),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Entry

/// An item of the entry being edited.
class _EditItem {
  _EditItem({
    this.diaryItemId,
    this.productId,
    this.recipeId,
    required this.name,
    required this.grams,
    required this.role,
    this.per100,
    this.source,
  });
  factory _EditItem.of(DiaryItem i) => _EditItem(
    diaryItemId: i.id,
    name: i.name,
    grams: i.grams,
    role: i.role,
    per100: i.per100,
    source: i.source,
  );

  /// The saved item (its values are kept by the server), or null for one added now from a product or a recipe.
  final String? diaryItemId;
  final String? productId, recipeId;
  final String name;
  double grams;
  final IngredientRole role;
  final Nutrients? per100;
  final NutritionSource? source;

  DiaryItemInput toInput() => diaryItemId != null
      ? DiaryItemInput(diaryItemId: diaryItemId, name: name, grams: grams, role: role)
      : DiaryItemInput(productId: productId, recipeId: recipeId, name: name, grams: grams, role: role);
}

/// A diary entry: its items with their weights, the whole portion scaled at once, meal and time, repeat, delete.
/// Pops with true when something changed.
class DiaryEntryScreen extends StatefulWidget {
  const DiaryEntryScreen({super.key, required this.entry});
  final DiaryEntry entry;

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late DiaryEntry _entry = widget.entry;
  late List<_EditItem> _items = [for (final i in _entry.items) _EditItem.of(i)];
  late MealType _meal = _entry.mealType;
  late DateTime _eatenAt = _entry.eatenAt;
  bool _dirty = false;
  bool _busy = false;
  bool _changed = false;

  NutritionRepository get _repo => context.read<NutritionRepository>();

  void _edit(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  void _reset(DiaryEntry e) {
    _entry = e;
    _items = [for (final i in e.items) _EditItem.of(i)];
    _meal = e.mealType;
    _eatenAt = e.eatenAt;
    _dirty = false;
  }

  /// Totals of the items as edited: values per 100 g times the weights, until the server recalculates on save.
  Nutrients get _preview {
    var kcal = 0.0, p = 0.0, f = 0.0, c = 0.0;
    for (final i in _items) {
      final v = i.per100?.forGrams(i.grams);
      if (v == null) continue;
      kcal += v.kcal;
      p += v.protein;
      f += v.fat;
      c += v.carbs;
    }
    return Nutrients(kcal: kcal, protein: p, fat: f, carbs: c);
  }

  Future<void> _grams(_EditItem item) async {
    final g = await showGramsSheet(context, title: item.name, initial: item.grams);
    if (g != null && mounted) _edit(() => item.grams = g);
  }

  void _scale(double factor) => _edit(() {
    for (final i in _items) {
      i.grams = (i.grams * factor).clamp(1.0, 5000.0).roundToDouble();
    }
  });

  void _remove(_EditItem item) {
    final t = AppLocalizations.of(context);
    if (_items.length == 1) {
      showSnack(context, t.lastItemDeleteEntry);
      return;
    }
    _edit(() => _items.remove(item));
  }

  Future<void> _addItem() async {
    final t = AppLocalizations.of(context);
    final pick = await showFoodSearch(context, title: t.addIngredient);
    if (pick == null || !mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    _edit(
      () => _items.add(
        _EditItem(
          productId: pick.product?.id,
          recipeId: pick.recipe?.id,
          name: pick.name(lang),
          grams: pick.grams,
          role: IngredientRole.main,
          per100: pick.per100,
          source: pick.product?.source ?? NutritionSource.recipe,
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final club = _eatenAt.toUtc().add(AppConfig.clubUtcOffset);
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: club.hour, minute: club.minute));
    if (picked == null || !mounted) return;
    final d = _entry.date;
    _edit(
      () => _eatenAt = DateTime.utc(d.year, d.month, d.day, picked.hour, picked.minute).subtract(AppConfig.clubUtcOffset),
    );
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final saved = await _repo.updateEntry(
        _entry.id,
        SaveDiaryEntry(
          date: _entry.date,
          mealType: _meal,
          eatenAt: _eatenAt,
          name: _entry.name,
          scanId: _entry.scanId,
          items: [for (final i in _items) i.toInput()],
        ),
      );
      if (!mounted) return;
      setState(() {
        _reset(saved);
        _changed = true;
      });
      showSnack(context, t.entrySaved);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repeat() async {
    final t = AppLocalizations.of(context);
    try {
      await _repo.repeatEntry(_entry.id);
      if (!mounted) return;
      _changed = true;
      showSnack(context, t.entryRepeated);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final ok = await showGlassSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(title: t.deleteEntryTitle, body: t.deleteEntryBody, confirm: t.deleteAction),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteEntry(_entry.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final totals = _entry.totals;
    final preview = _preview;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: NutritionPage(
        listKey: const Key('diary-entry'),
        title: _entry.name,
        subtitle: '${mealTypeLabel(t, _meal)} · ${Fmt(lang).time(_eatenAt)}',
        actions: [
          GlassCircleButton(
            key: const Key('entry-repeat'),
            icon: Icons.replay_rounded,
            iconSize: 20,
            tooltip: t.repeatToday,
            onTap: _repeat,
          ),
          GlassCircleButton(
            key: const Key('entry-delete'),
            icon: Icons.delete_outline_rounded,
            iconSize: 20,
            tooltip: t.deleteAction,
            onTap: _delete,
          ),
        ],
        bottom: _dirty
            ? GradientPillButton(
                key: const Key('entry-save'),
                label: t.save,
                icon: Icons.check_rounded,
                height: 54,
                loading: _busy,
                onPressed: _save,
              )
            : null,
        children: [
          if (_entry.hasPhoto && _entry.scanId != null) ...[
            SizedBox(
              height: 200,
              width: double.infinity,
              child: ScanPhoto(scanId: _entry.scanId, size: null, radius: Brand.radiusHero),
            ),
            const SizedBox(height: 16),
          ],
          GlassCard(
            key: const Key('entry-totals'),
            radius: Brand.radiusHero,
            glow: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dirty ? '≈ ${fmt.kcal(preview.kcal)} ${t.unitKcal}' : fmt.kcalTotal(totals),
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 30, fontWeight: FontWeight.w700),
                ),
                if (!_dirty && fmt.kcalRange(totals) != null)
                  Text(t.kcalRangeLabel(fmt.kcalRange(totals)!), style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
                if (_dirty)
                  Text(t.recalcOnSave, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
                if (totals.incomplete && !_dirty) ...[
                  const SizedBox(height: 6),
                  SoftTag(t.incompleteData, color: Brand.warningText),
                ],
                const SizedBox(height: 14),
                if (_dirty)
                  MacroRow(values: preview)
                else
                  NutrientGrid(values: totals.values),
              ],
            ),
          ),
          const SizedBox(height: Brand.sectionGap),
          GlassSectionHeader(t.ingredients, action: t.addIngredientShort, onAction: _addItem),
          GlassList(
            children: [
              for (final i in _items)
                Padding(
                  key: Key('entry-item-${i.diaryItemId ?? i.name}'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            if (i.per100 == null)
                              Text(t.noNutritionData, style: const TextStyle(color: Brand.warningText, fontSize: 12))
                            else
                              Row(
                                children: [
                                  if (i.source != null) ...[SourceChip(source: i.source!), const SizedBox(width: 6)],
                                  Text(
                                    '${fmt.kcal(i.per100!.kcal * i.grams / 100)} ${t.unitKcal}',
                                    style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: Key('entry-grams-${i.diaryItemId ?? i.name}'),
                        onPressed: () => _grams(i),
                        child: Text(
                          fmt.grams(i.grams),
                          style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        key: Key('entry-remove-${i.diaryItemId ?? i.name}'),
                        tooltip: t.deleteAction,
                        onPressed: () => _remove(i),
                        icon: Icon(Icons.close_rounded, size: 18, color: Brand.textTertiary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(t.portionSize, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (label, factor) in const [('×0.5', 0.5), ('×1.5', 1.5), ('×2', 2.0)]) ...[
                if (factor != 0.5) const SizedBox(width: 10),
                Expanded(
                  child: GlassPillButton(
                    key: Key('entry-scale-$factor'),
                    label: label,
                    icon: Icons.tune_rounded,
                    height: 42,
                    onPressed: () => _scale(factor),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Brand.sectionGap),
          GlassSectionHeader(t.mealTypeTitle),
          MealTypeSelector(value: _meal, onChanged: (m) => _edit(() => _meal = m)),
          const SizedBox(height: 12),
          GlassCard(
            key: const Key('entry-time'),
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: _pickTime,
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: Brand.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${t.eatenAt}: ${Fmt(lang).time(_eatenAt)}',
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
