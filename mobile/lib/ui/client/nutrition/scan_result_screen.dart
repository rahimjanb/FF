import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'food_photo.dart';
import 'food_search_sheet.dart';
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';
import 'scan_flow.dart';

/// Opens a scan from the history.
Future<void> openScanResult(
  BuildContext context,
  String scanId, {
  NutritionProfile? profile,
  VoidCallback? onChanged,
  FoodPhotoPicker picker = pickFoodPhoto,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ScanResultScreen.load(scanId: scanId, profile: profile, onChanged: onChanged, picker: picker),
  ),
);

/// An ingredient as the client is editing it.
class _Ing {
  _Ing({
    this.id,
    this.productId,
    required this.name,
    this.productName,
    required this.grams,
    required this.role,
    this.per100,
    this.source,
  });
  factory _Ing.of(FoodScanIngredient i) => _Ing(
    id: i.id,
    productId: i.productId,
    name: i.name,
    productName: i.productName,
    grams: i.grams,
    role: i.role,
    per100: i.per100,
    source: i.source,
  );

  /// Null for an ingredient the client added that the server has not seen yet.
  String? id;
  String? productId;
  String name;
  String? productName;
  double grams;
  IngredientRole role;
  Nutrients? per100;
  NutritionSource? source;

  bool get matched => per100 != null;

  DishIngredientInput toInput() =>
      DishIngredientInput(id: id, productId: productId, name: name, grams: grams, role: role);
}

/// Result of a food photo: the dish (or dishes), its estimated nutrition with the uncertainty range and the
/// ingredients the client can correct. Every correction is recalculated by the server. The dish goes to the diary
/// only when the client taps «Добавить в дневник».
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required FoodScan this.scan,
    this.photo,
    this.profile,
    this.picker = pickFoodPhoto,
    this.onChanged,
  }) : scanId = null;

  /// Loads the scan by id first (from the history).
  const ScanResultScreen.load({
    super.key,
    required String this.scanId,
    this.profile,
    this.picker = pickFoodPhoto,
    this.onChanged,
  }) : scan = null,
       photo = null;

  final FoodScan? scan;
  final String? scanId;

  /// The photo just taken (kept in memory to re-run the analysis with a hint); loaded from the server otherwise.
  final Uint8List? photo;
  final NutritionProfile? profile;
  final FoodPhotoPicker picker;
  final VoidCallback? onChanged;

  /// Corrections are sent this long after the last change.
  static const saveDelay = Duration(milliseconds: 400);

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  FoodScan? _scan;
  Object? _loadError;
  int _dish = 0;
  List<_Ing> _ings = [];
  String? _name;
  MealType _meal = mealTypeForTime(DateTime.now().toUtc().add(AppConfig.clubUtcOffset));

  Timer? _debounce;
  Future<void>? _saving;
  int _edits = 0;
  int _savedEdits = 0;
  Object? _saveError;
  bool _adding = false;

  NutritionRepository get _repo => context.read<NutritionRepository>();

  @override
  void initState() {
    super.initState();
    final scan = widget.scan;
    if (scan != null) {
      _apply(scan);
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final scan = await _repo.scan(widget.scanId!);
      if (mounted) setState(() => _apply(scan));
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Takes the server's version of the scan as the state being edited.
  void _apply(FoodScan scan) {
    _scan = scan;
    if (_dish >= scan.dishes.length) _dish = 0;
    if (scan.dishes.isNotEmpty) {
      final d = scan.dishes[_dish];
      _ings = [for (final i in d.ingredients) _Ing.of(i)];
      // Only a name the client typed is kept as state; otherwise the title follows the app language.
      _name = d.userEdited ? d.name : null;
    } else {
      _ings = [];
      _name = null;
    }
  }

  FoodDish? get _current {
    final s = _scan;
    return s == null || s.dishes.isEmpty ? null : s.dishes[_dish];
  }

  bool get _dirty => _edits != _savedEdits;

  void _changed() {
    HapticFeedback.selectionClick();
    setState(() => _edits++);
    _debounce?.cancel();
    _debounce = Timer(ScanResultScreen.saveDelay, _save);
  }

  /// Sends the current corrections; when more edits came meanwhile, their own save follows.
  Future<void> _save() {
    _debounce?.cancel();
    final running = _saving;
    if (running != null) return running.then((_) => _dirty ? _save() : null);
    final edits = _edits;
    final scan = _scan!;
    final f = () async {
      try {
        final updated = await _repo.updateDish(
          scan.id,
          dishIndex: _dish,
          name: _name,
          ingredients: [for (final i in _ings) i.toInput()],
        );
        if (!mounted) return;
        setState(() {
          _savedEdits = edits;
          _saveError = null;
          if (_edits == edits) {
            _apply(updated);
          } else {
            // Newer edits are waiting: keep them, take only the totals and the new ingredient ids.
            _scan = updated;
          }
        });
      } catch (e) {
        if (mounted) setState(() => _saveError = e);
        rethrow;
      }
    }();
    _saving = f;
    return f.whenComplete(() => _saving = null);
  }

  Future<bool> _flush() async {
    if (!_dirty && _saving == null) return true;
    try {
      await _save();
      return true;
    } catch (e) {
      if (mounted) showSnack(context, errorText(AppLocalizations.of(context), e));
      return false;
    }
  }

  Future<void> _switchDish(int i) async {
    if (i == _dish) return;
    if (!await _flush() || !mounted) return;
    setState(() {
      _dish = i;
      _apply(_scan!);
    });
  }

  Future<void> _editGrams(_Ing ing) async {
    final grams = await showGramsSheet(context, title: ing.productName ?? ing.name, initial: ing.grams);
    if (grams == null || !mounted) return;
    ing.grams = grams;
    _changed();
  }

  void _step(_Ing ing, int direction) {
    final step = ing.grams >= 100 ? 10.0 : 5.0;
    final next = (ing.grams + step * direction).clamp(1.0, 5000.0);
    if (next == ing.grams) return;
    ing.grams = NutritionFmt.roundTo(next, step.round());
    if (ing.grams < 1) ing.grams = 1;
    _changed();
  }

  void _remove(_Ing ing) {
    final t = AppLocalizations.of(context);
    if (_ings.length == 1) {
      showSnack(context, t.lastIngredient);
      return;
    }
    _ings.remove(ing);
    _changed();
  }

  void _scaleFats(double factor) {
    final t = AppLocalizations.of(context);
    final fats = _ings.where((i) => i.role == IngredientRole.fat || i.role == IngredientRole.sauce).toList();
    if (fats.isEmpty) {
      showSnack(context, t.noFatsToScale);
      return;
    }
    for (final i in fats) {
      i.grams = (i.grams * factor).clamp(1.0, 5000.0).roundToDouble();
    }
    _changed();
  }

  Future<void> _addIngredient() async {
    final t = AppLocalizations.of(context);
    final pick = await showFoodSearch(context, title: t.addIngredient, productsOnly: true);
    if (pick == null || pick.product == null || !mounted) return;
    final p = pick.product!;
    final lang = Localizations.localeOf(context).languageCode;
    _ings.add(
      _Ing(
        productId: p.id,
        name: p.localName(lang),
        productName: p.localName(lang),
        grams: pick.grams,
        role: p.category == FoodCategory.fatsOils
            ? IngredientRole.fat
            : p.category == FoodCategory.sauces
            ? IngredientRole.sauce
            : IngredientRole.main,
        per100: p.per100,
        source: p.source,
      ),
    );
    _changed();
  }

  Future<void> _pickProduct(_Ing ing) async {
    final t = AppLocalizations.of(context);
    final pick = await showFoodSearch(
      context,
      title: t.pickProductFor(ing.name),
      initialQuery: ing.name,
      productsOnly: true,
      askGrams: false,
    );
    if (pick == null || pick.product == null || !mounted) return;
    final p = pick.product!;
    ing
      ..productId = p.id
      ..productName = p.localName(Localizations.localeOf(context).languageCode)
      ..per100 = p.per100
      ..source = p.source;
    _changed();
  }

  Future<void> _rename() async {
    final t = AppLocalizations.of(context);
    final name = await showGlassSheet<String>(context, builder: (_) => _RenameSheet(initial: _name ?? _current?.localName(Localizations.localeOf(context).languageCode) ?? ''));
    if (name == null || name.trim().isEmpty || !mounted) return;
    _name = name.trim();
    _changed();
    if (mounted) showSnack(context, t.dishRenamed);
  }

  Future<void> _addToDiary({bool all = false}) async {
    final t = AppLocalizations.of(context);
    setState(() => _adding = true);
    try {
      if (!await _flush() || !mounted) return;
      final scan = _scan!;
      final dishes = all ? scan.dishes : [scan.dishes[_dish]];
      for (final d in dishes) {
        await _repo.addEntry(
          SaveDiaryEntry(
            mealType: _meal,
            name: d.userEdited ? d.name : d.localName(Localizations.localeOf(context).languageCode),
            scanId: scan.id,
            items: [
              for (final i in d.ingredients)
                DiaryItemInput(scanIngredientId: i.id, name: i.name, grams: i.grams, role: i.role),
            ],
          ),
        );
      }
      widget.onChanged?.call();
      if (!mounted) return;
      showSnack(context, all ? t.addedAllToDiary(dishes.length) : t.addedToDiary(mealTypeLabel(t, _meal)));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final ok = await showGlassSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(title: t.deleteScanTitle, body: t.deleteScanBody, confirm: t.deleteAction),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteScan(_scan!.id);
      ScanPhotoCache.remove(_scan!.id);
      widget.onChanged?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    }
  }

  Future<Uint8List?> _photoBytes() async {
    if (widget.photo != null) return widget.photo;
    final scan = _scan;
    if (scan == null || !scan.hasPhoto) return null;
    try {
      return ScanPhotoCache.get(scan.id) ?? await _repo.scanPhoto(scan.id);
    } catch (_) {
      return null;
    }
  }

  /// Runs the analysis again on the same photo with what the client says is on it.
  Future<void> _clarify() async {
    final t = AppLocalizations.of(context);
    final hint = await showGlassSheet<String>(
      context,
      builder: (_) => _RenameSheet(initial: _scan?.hint ?? '', title: t.clarifyTitle, label: t.scanHintLabel),
    );
    if (hint == null || hint.trim().isEmpty || !mounted) return;
    final photo = await _photoBytes();
    if (!mounted) return;
    if (photo == null) {
      showSnack(context, t.photoUnavailable);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScanPreviewScreen(
          photo: photo,
          profile: widget.profile,
          picker: widget.picker,
          initialHint: hint.trim(),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  /// A new photo instead of this one; the preview replaces this screen.
  Future<void> _retake() async {
    final t = AppLocalizations.of(context);
    final Uint8List? jpeg;
    try {
      jpeg = await widget.picker(context, FoodPhotoSource.camera);
    } on FoodPhotoException catch (e) {
      if (mounted) showSnack(context, foodPhotoProblemText(t, e.problem));
      return;
    } catch (_) {
      if (mounted) showSnack(context, t.foodPhotoUnreadable);
      return;
    }
    if (jpeg == null || !mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScanPreviewScreen(
          photo: jpeg!,
          profile: widget.profile,
          picker: widget.picker,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scan = _scan;
    if (scan == null) {
      return NutritionPage(
        title: t.scanResultTitle,
        children: [
          if (_loadError != null)
            ErrorView(error: _loadError!, onRetry: _load)
          else
            const GlassSkeleton(height: 320, radius: Brand.radiusHero),
        ],
      );
    }
    final dish = _current;
    final canAdd = dish != null;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Unsaved corrections are still sent when the client leaves.
        if (didPop && _dirty) unawaited(_save().catchError((_) {}));
      },
      child: NutritionPage(
        listKey: const Key('scan-result'),
        title: dish == null ? t.scanResultTitle : (_name ?? dish.localName(Localizations.localeOf(context).languageCode)),
        subtitle: scan.reused ? t.scanReused : null,
        actions: [
          GlassCircleButton(
            key: const Key('scan-delete'),
            icon: Icons.delete_outline_rounded,
            iconSize: 20,
            tooltip: t.deleteAction,
            onTap: _delete,
          ),
        ],
        bottom: canAdd
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GradientPillButton(
                    key: const Key('scan-add-to-diary'),
                    label: t.addToDiary,
                    icon: Icons.add_rounded,
                    height: 54,
                    loading: _adding,
                    onPressed: _addToDiary,
                  ),
                  if (scan.dishes.length > 1) ...[
                    const SizedBox(height: 8),
                    GlassPillButton(
                      key: const Key('scan-add-all'),
                      label: t.addAllDishes(scan.dishes.length),
                      icon: Icons.playlist_add_rounded,
                      onPressed: _adding ? null : () => _addToDiary(all: true),
                    ),
                  ],
                ],
              )
            : null,
        children: [
          _PhotoHeader(scan: scan, photo: widget.photo),
          const SizedBox(height: 16),
          ..._statusBlocks(t, scan),
          if (dish != null) ..._dishBlocks(t, scan, dish),
        ],
      ),
    );
  }

  List<Widget> _statusBlocks(AppLocalizations t, FoodScan scan) {
    final quality = imageQualityText(t, scan.imageQuality);
    switch (scan.status) {
      case FoodScanStatus.notFood:
        return [
          _StatusCard(
            key: const Key('scan-not-food'),
            icon: Icons.no_food_outlined,
            title: t.notFoodTitle,
            body: quality ?? t.notFoodBody,
            actions: [
              GradientPillButton(label: t.retakePhoto, icon: Icons.photo_camera_outlined, onPressed: _retake),
            ],
          ),
        ];
      case FoodScanStatus.failed:
        return [
          _StatusCard(
            key: const Key('scan-failed'),
            icon: Icons.cloud_off_rounded,
            title: t.scanFailedTitle,
            body: t.scanFailedBody,
            actions: [
              GradientPillButton(label: t.retry, icon: Icons.refresh_rounded, onPressed: _clarifyOrRetry),
            ],
          ),
        ];
      case FoodScanStatus.needsClarification:
        return [
          _StatusCard(
            key: const Key('scan-clarify'),
            icon: Icons.help_outline_rounded,
            title: t.clarifyNeededTitle,
            body: [scan.clarificationQuestion ?? t.clarifyNeededBody, ?quality].join('\n\n'),
            actions: [
              GradientPillButton(
                key: const Key('scan-clarify-name'),
                label: t.clarifyName,
                icon: Icons.edit_outlined,
                onPressed: _clarify,
              ),
              GlassPillButton(
                key: const Key('scan-retake-photo'),
                label: t.retakePhoto,
                icon: Icons.photo_camera_outlined,
                onPressed: _retake,
              ),
            ],
          ),
          if (scan.dishes.isNotEmpty) const SizedBox(height: 16),
        ];
      case FoodScanStatus.recognized:
        return const [];
    }
  }

  Future<void> _clarifyOrRetry() async {
    final photo = await _photoBytes();
    if (!mounted) return;
    if (photo == null) {
      showSnack(context, AppLocalizations.of(context).photoUnavailable);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScanPreviewScreen(
          photo: photo,
          profile: widget.profile,
          picker: widget.picker,
          initialHint: _scan?.hint,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  List<Widget> _dishBlocks(AppLocalizations t, FoodScan scan, FoodDish dish) {
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final totals = dish.totals;
    final range = fmt.kcalRange(totals);
    final warnings = [for (final w in dish.warnings) ?warningText(t, w)];
    final hasFats = _ings.any((i) => i.role == IngredientRole.fat || i.role == IngredientRole.sauce);
    return [
      if (scan.dishes.length > 1) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in scan.dishes)
              ChoiceChip(
                key: Key('dish-${d.index}'),
                selected: d.index == _dish,
                showCheckmark: false,
                label: Text(d.localName(lang), maxLines: 1, overflow: TextOverflow.ellipsis),
                labelStyle: TextStyle(
                  color: d.index == _dish ? Colors.white : Brand.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                selectedColor: Brand.accent.withValues(alpha: 0.35),
                side: BorderSide(color: d.index == _dish ? Brand.accent.withValues(alpha: 0.6) : Brand.glassStroke),
                shape: const StadiumBorder(),
                onSelected: (_) => _switchDish(scan.dishes.indexOf(d)),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      GlassCard(
        key: const Key('dish-card'),
        radius: Brand.radiusHero,
        glow: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      SoftTag(foodCategoryLabel(t, dish.category), color: Brand.clock),
                      if (dish.preparationMethod != PreparationMethod.unknown)
                        SoftTag(preparationLabel(t, dish.preparationMethod), color: Brand.purple),
                      _ConfidenceBadge(confidence: dish.confidence),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('dish-rename'),
                  tooltip: t.renameDish,
                  onPressed: _rename,
                  icon: Icon(Icons.edit_outlined, color: Brand.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      fmt.kcalTotal(totals),
                      key: ValueKey('kcal-${totals.kcal}'),
                      style: const TextStyle(
                        color: Brand.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_saving != null || _dirty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Brand.clock),
                    ),
                  ),
              ],
            ),
            if (range != null)
              Text(
                t.kcalRangeLabel(range),
                key: const Key('dish-range'),
                style: TextStyle(color: Brand.textSecondary, fontSize: 13),
              ),
            Text(
              '${fmt.grams(totals.grams)} · ${weightConfidenceLabel(t, dish.weightConfidence)}',
              style: TextStyle(color: Brand.textSecondary, fontSize: 13),
            ),
            if (totals.incomplete) ...[
              const SizedBox(height: 6),
              SoftTag(t.incompleteData, color: Brand.warningText, icon: Icons.info_outline_rounded),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 6),
              Text(errorText(t, _saveError!), style: const TextStyle(color: Brand.redText, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            NutrientGrid(values: totals.values),
          ],
        ),
      ),
      if (warnings.isNotEmpty || dish.possibleAllergens.isNotEmpty || dish.notes != null) ...[
        const SizedBox(height: 12),
        GlassCard(
          key: const Key('dish-notes'),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final w in warnings) InfoRow(icon: Icons.info_outline_rounded, text: w),
              if (dish.notes != null) InfoRow(icon: Icons.notes_rounded, text: dish.notes!, color: Brand.clock),
              if (dish.possibleAllergens.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(t.possibleAllergens, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in dish.possibleAllergens)
                      SoftTag(allergenLabel(t, a), color: Brand.redText, icon: Icons.warning_amber_rounded),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: Brand.sectionGap),
      GlassSectionHeader(t.ingredients, action: t.addIngredientShort, onAction: _addIngredient),
      GlassList(
        dividerIndent: 16,
        children: [for (final ing in _ings) _ingredientRow(t, fmt, ing)],
      ),
      const SizedBox(height: 16),
      Text(t.fatTitle, style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: GlassPillButton(
              key: const Key('fat-less'),
              label: t.fatLess,
              icon: Icons.remove_rounded,
              height: 42,
              onPressed: hasFats ? () => _scaleFats(0.5) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassPillButton(
              key: const Key('fat-more'),
              label: t.fatMore,
              icon: Icons.add_rounded,
              height: 42,
              onPressed: hasFats ? () => _scaleFats(1.5) : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(t.fatHint, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
      const SizedBox(height: Brand.sectionGap),
      GlassSectionHeader(t.mealTypeTitle),
      MealTypeSelector(value: _meal, onChanged: (m) => setState(() => _meal = m)),
      const SizedBox(height: 12),
      Text(t.calcNote, style: TextStyle(color: Brand.textTertiary, fontSize: 12, height: 1.35)),
    ];
  }

  Widget _ingredientRow(AppLocalizations t, NutritionFmt fmt, _Ing ing) {
    final kcal = ing.per100 == null ? null : ing.per100!.kcal * ing.grams / 100;
    final key = ing.id ?? 'new-${_ings.indexOf(ing)}';
    return Dismissible(
      key: Key('ing-$key'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Brand.red.withValues(alpha: 0.25),
        child: const Icon(Icons.delete_outline_rounded, color: Brand.redText),
      ),
      confirmDismiss: (_) async => _ings.length > 1,
      onDismissed: (_) => _remove(ing),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ing.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  if (ing.matched)
                    Row(
                      children: [
                        if (ing.source != null) ...[SourceChip(source: ing.source!), const SizedBox(width: 6)],
                        Flexible(
                          child: Text(
                            [
                              if (ing.productName != null && ing.productName != ing.name) ing.productName!,
                              if (ing.role != IngredientRole.main) roleLabel(t, ing.role),
                              if (kcal != null) '${fmt.kcal(kcal)} ${t.unitKcal}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      key: Key('ing-pick-$key'),
                      onTap: () => _pickProduct(ing),
                      child: Text(
                        t.notInDatabasePick,
                        style: const TextStyle(color: Brand.warningText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            _StepButton(
              key: Key('ing-minus-$key'),
              icon: Icons.remove_rounded,
              tooltip: t.decrease,
              onTap: () => _step(ing, -1),
            ),
            InkWell(
              key: Key('ing-grams-$key'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => _editGrams(ing),
              child: Container(
                constraints: const BoxConstraints(minWidth: 58),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  fmt.grams(ing.grams),
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _StepButton(
              key: Key('ing-plus-$key'),
              icon: Icons.add_rounded,
              tooltip: t.increase,
              onTap: () => _step(ing, 1),
            ),
            IconButton(
              key: Key('ing-remove-$key'),
              tooltip: t.deleteAction,
              onPressed: () => _remove(ing),
              icon: Icon(Icons.close_rounded, size: 18, color: Brand.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Brand.glassStroke),
            ),
            child: Icon(icon, size: 16, color: Brand.textPrimary),
          ),
        ),
      ),
    ),
  );
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, color) = confidence >= 0.8
        ? (t.confidenceHigh, Brand.successText)
        : confidence >= 0.55
        ? (t.confidenceMedium, Brand.warningText)
        : (t.confidenceLow, Brand.redText);
    return SoftTag('$label · ${(confidence * 100).round()}%', color: color, icon: Icons.auto_awesome_rounded);
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.scan, this.photo});
  final FoodScan scan;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    if (photo == null && !scan.hasPhoto) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Brand.radiusHero),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: photo != null
            ? Image.memory(photo!, fit: BoxFit.cover)
            : ScanPhoto(scanId: scan.id, size: null, radius: Brand.radiusHero),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.icon, required this.title, required this.body, required this.actions});
  final IconData icon;
  final String title, body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: Brand.radiusHero,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconPlate(icon: icon, color: Brand.warning, iconColor: Brand.warningIcon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(body, style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.4)),
        const SizedBox(height: 16),
        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 10), actions[i]],
      ],
    ),
  );
}

/// A one-line text: the dish name, or what is on the photo.
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial, this.title, this.label});
  final String initial;
  final String? title, label;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title ?? t.renameDish,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('text-sheet-field'),
            controller: _controller,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(labelText: widget.label ?? t.dishName),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: 12),
          GradientPillButton(
            key: const Key('text-sheet-ok'),
            label: t.done,
            height: 52,
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
    );
  }
}

/// A yes/no question with a destructive confirm button.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({super.key, required this.title, required this.body, required this.confirm});
  final String title, body, confirm;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('confirm-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('confirm-yes'),
          style: FilledButton.styleFrom(backgroundColor: Brand.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Brand.textSecondary, minimumSize: const Size(44, 44)),
          child: Text(t.cancel),
        ),
      ],
    );
  }
}
