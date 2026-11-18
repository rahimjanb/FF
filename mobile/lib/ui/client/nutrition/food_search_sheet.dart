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
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';

/// A food the client chose in the search, with the weight they ate (when asked).
class FoodPick {
  const FoodPick({this.product, this.recipe, required this.grams});
  final FoodProduct? product;
  final FoodRecipeSummary? recipe;
  final double grams;

  String name(String lang) => product?.localName(lang) ?? recipe!.localName(lang);
  Nutrients get per100 => product?.per100 ?? recipe!.per100;
}

/// Search in the food database (built-in products, Uzbek dishes, Open Food Facts and USDA products found earlier,
/// the client's own) and pick one. [productsOnly] hides dishes (an ingredient must be a product); [askGrams] false
/// returns the pick with grams 0.
Future<FoodPick?> showFoodSearch(
  BuildContext context, {
  required String title,
  String? initialQuery,
  bool productsOnly = false,
  bool askGrams = true,
}) => showGlassSheet<FoodPick>(
  context,
  builder: (_) =>
      FoodSearchView(title: title, initialQuery: initialQuery, productsOnly: productsOnly, askGrams: askGrams),
);

/// Adds a food chosen in the search to the diary; asks for the meal unless [meal] is given (the one that fits the
/// time of day is preselected). Returns whether it was added.
Future<bool> saveFoodPick(BuildContext context, FoodPick pick, {MealType? meal, DateTime? date}) async {
  final t = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  final repo = context.read<NutritionRepository>();
  final m = meal ?? await showMealTypeSheet(context, mealTypeForTime(DateTime.now().toUtc().add(AppConfig.clubUtcOffset)));
  if (m == null || !context.mounted) return false;
  try {
    await repo.addEntry(
      SaveDiaryEntry(
        date: date,
        mealType: m,
        name: pick.name(lang),
        items: [
          DiaryItemInput(
            productId: pick.product?.id,
            recipeId: pick.recipe?.id,
            name: pick.name(lang),
            grams: pick.grams,
          ),
        ],
      ),
    );
    if (context.mounted) showSnack(context, t.addedToDiary(mealTypeLabel(t, m)));
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(t, e));
    return false;
  }
}

/// Asks which meal something belongs to.
Future<MealType?> showMealTypeSheet(BuildContext context, MealType initial) =>
    showGlassSheet<MealType>(context, builder: (_) => _MealTypeSheet(initial: initial));

class _MealTypeSheet extends StatefulWidget {
  const _MealTypeSheet({required this.initial});
  final MealType initial;

  @override
  State<_MealTypeSheet> createState() => _MealTypeSheetState();
}

class _MealTypeSheetState extends State<_MealTypeSheet> {
  late MealType _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('meal-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.mealTypeTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Center(child: MealTypeSelector(value: _value, onChanged: (m) => setState(() => _value = m))),
        const SizedBox(height: 18),
        GradientPillButton(
          key: const Key('meal-sheet-ok'),
          label: t.addToDiary,
          icon: Icons.add_rounded,
          height: 52,
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

/// Asks the weight eaten of a product: per serving and per package when they are known.
Future<double?> askProductGrams(BuildContext context, FoodProduct product, {double? initial}) {
  final t = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  return showGramsSheet(
    context,
    title: product.localName(lang),
    initial: initial ?? product.servingGrams ?? 100,
    perMl: product.per100Ml,
    quick: [
      (product.per100Ml ? '100 ${t.unitMl}' : '100 ${t.unitG}', 100),
      if (product.servingGrams != null) (t.serving(product.servingGrams!.round()), product.servingGrams!),
      if (product.packageGrams != null) (t.package(product.packageGrams!.round()), product.packageGrams!),
    ],
  );
}

class FoodSearchView extends StatefulWidget {
  const FoodSearchView({
    super.key,
    required this.title,
    this.initialQuery,
    this.productsOnly = false,
    this.askGrams = true,
  });
  final String title;
  final String? initialQuery;
  final bool productsOnly, askGrams;

  /// Searches wait this long after the last keystroke.
  static const delay = Duration(milliseconds: 350);

  @override
  State<FoodSearchView> createState() => _FoodSearchViewState();
}

class _FoodSearchViewState extends State<FoodSearchView> {
  late final _query = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  FoodSearchResult? _result;
  Object? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (_query.text.trim().length >= 2) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(FoodSearchView.delay, _search);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() {
        _result = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<NutritionRepository>().search(q);
      if (mounted && request == _request) setState(() => _result = r);
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _pickProduct(FoodProduct p) async {
    if (!widget.askGrams) {
      Navigator.of(context).pop(FoodPick(product: p, grams: 0));
      return;
    }
    final grams = await askProductGrams(context, p);
    if (grams != null && mounted) Navigator.of(context).pop(FoodPick(product: p, grams: grams));
  }

  Future<void> _pickRecipe(FoodRecipeSummary r) async {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    if (!widget.askGrams) {
      Navigator.of(context).pop(FoodPick(recipe: r, grams: 0));
      return;
    }
    final grams = await showGramsSheet(
      context,
      title: r.localName(lang),
      initial: r.portionGrams,
      quick: [
        (t.portion(r.portionGrams.round()), r.portionGrams),
        (t.halfPortion, r.portionGrams / 2),
        ('100 ${t.unitG}', 100),
      ],
    );
    if (grams != null && mounted) Navigator.of(context).pop(FoodPick(recipe: r, grams: grams));
  }

  Future<void> _create() async {
    final product = await Navigator.of(context).push<FoodProduct>(
      MaterialPageRoute(builder: (_) => CreateProductScreen(initialName: _query.text.trim())),
    );
    if (product != null && mounted) await _pickProduct(product);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final r = _result;
    final recipes = widget.productsOnly || r == null ? const <FoodRecipeSummary>[] : r.recipes;
    final products = r?.products ?? const <FoodProduct>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        key: const Key('food-search'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('food-search-field'),
            controller: _query,
            autofocus: widget.initialQuery == null,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: Brand.textSecondary),
              labelText: t.searchFoodHint,
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: _error != null
                ? Center(
                    child: Text(
                      errorText(t, _error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Brand.redText),
                    ),
                  )
                : r == null
                ? Center(
                    child: Text(
                      t.searchFoodStart,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Brand.textSecondary, fontSize: 14),
                    ),
                  )
                : recipes.isEmpty && products.isEmpty
                ? Center(
                    child: Text(
                      t.searchFoodNothing,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Brand.textSecondary, fontSize: 14),
                    ),
                  )
                : ListView(
                    children: [
                      for (final rec in recipes)
                        _ResultRow(
                          key: Key('recipe-${rec.id}'),
                          title: rec.localName(lang),
                          subtitle: '${fmt.kcalExact(rec.per100.kcal)} ${t.unitKcal} / 100 ${t.unitG}',
                          badge: rec.isTraditional
                              ? SoftTag(t.traditionalDish, color: Brand.purple)
                              : rec.isOwn
                              ? SoftTag(t.sourceUser, color: Brand.blueIcon)
                              : null,
                          icon: Icons.ramen_dining_outlined,
                          onTap: () => _pickRecipe(rec),
                        ),
                      for (final p in products)
                        _ResultRow(
                          key: Key('product-${p.id}'),
                          title: p.localName(lang),
                          subtitle: [
                            if (p.brand != null) p.brand!,
                            '${fmt.kcalExact(p.per100.kcal)} ${t.unitKcal} / 100 ${p.per100Ml ? t.unitMl : t.unitG}',
                          ].join(' · '),
                          badge: SourceChip(source: p.source),
                          icon: Icons.egg_alt_outlined,
                          onTap: () => _pickProduct(p),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          GlassPillButton(
            key: const Key('food-create'),
            label: t.createOwnProduct,
            icon: Icons.add_rounded,
            onPressed: _create,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          IconPlate(icon: icon, size: 38, color: Brand.accent, iconColor: Brand.clock),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
        ],
      ),
    ),
  );
}

/// The client's own product: name and nutrition per 100 g (from a package, a recipe book…).
class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key, this.initialName, this.barcode});
  final String? initialName;
  final String? barcode;

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName ?? '');
  final _brand = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _sat = TextEditingController();
  final _sodium = TextEditingController();
  final _serving = TextEditingController();
  final _package = TextEditingController();
  late final _barcode = TextEditingController(text: widget.barcode ?? '');
  bool _perMl = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _brand, _kcal, _protein, _fat, _carbs, _fiber, _sugar, _sat, _sodium, _serving, _package, _barcode]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());

  String? _check(String? v, double max, {bool required = false}) {
    final t = AppLocalizations.of(context);
    if (v == null || v.trim().isEmpty) return required ? t.validationRequired : null;
    final n = double.tryParse(v.replaceAll(',', '.').trim());
    if (n == null || n < 0 || n > max) return t.valueRange('0', max.round().toString());
    return null;
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final product = await context.read<NutritionRepository>().createProduct(
        NewFoodProduct(
          name: _name.text.trim(),
          brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          per100: Nutrients(
            kcal: _num(_kcal)!,
            protein: _num(_protein)!,
            fat: _num(_fat)!,
            carbs: _num(_carbs)!,
            fiber: _num(_fiber),
            sugar: _num(_sugar),
            saturatedFat: _num(_sat),
            sodiumMg: _num(_sodium),
          ),
          per100Ml: _perMl,
          servingGrams: _num(_serving),
          packageGrams: _num(_package),
          barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        ),
      );
      if (!mounted) return;
      showSnack(context, t.productCreated);
      Navigator.of(context).pop(product);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, TextEditingController c, String label, double max, {bool required = false, String? suffix}) =>
      TextFormField(
        key: Key(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        validator: (v) => _check(v, max, required: required),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const gap = SizedBox(height: 12);
    return NutritionPage(
      title: t.createOwnProduct,
      subtitle: t.createProductSubtitle,
      bottom: GradientPillButton(
        key: const Key('product-save'),
        label: t.save,
        icon: Icons.check_rounded,
        height: 54,
        loading: _busy,
        onPressed: _save,
      ),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('product-name'),
                controller: _name,
                maxLength: 120,
                decoration: InputDecoration(labelText: t.productName),
                validator: (v) => v == null || v.trim().isEmpty ? t.validationRequired : null,
              ),
              TextFormField(
                key: const Key('product-brand'),
                controller: _brand,
                maxLength: 80,
                decoration: InputDecoration(labelText: t.productBrand),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _perMl,
                onChanged: (v) => setState(() => _perMl = v),
                title: Text(t.per100MlSwitch, style: const TextStyle(color: Brand.textPrimary, fontSize: 15)),
              ),
              GlassSectionHeader(_perMl ? t.per100Ml : t.per100g),
              _field('product-kcal', _kcal, t.unitKcal, 900, required: true),
              gap,
              Row(
                children: [
                  Expanded(child: _field('product-protein', _protein, t.protein, 100, required: true, suffix: t.unitG)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('product-fat', _fat, t.fat, 100, required: true, suffix: t.unitG)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('product-carbs', _carbs, t.carbs, 100, required: true, suffix: t.unitG)),
                ],
              ),
              gap,
              Row(
                children: [
                  Expanded(child: _field('product-fiber', _fiber, t.fiber, 100, suffix: t.unitG)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('product-sugar', _sugar, t.sugar, 100, suffix: t.unitG)),
                ],
              ),
              gap,
              Row(
                children: [
                  Expanded(child: _field('product-sat', _sat, t.saturatedFat, 100, suffix: t.unitG)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('product-sodium', _sodium, t.sodium, 40000, suffix: t.unitMg)),
                ],
              ),
              const SizedBox(height: Brand.sectionGap),
              GlassSectionHeader(t.portionSizes),
              Row(
                children: [
                  Expanded(child: _field('product-serving', _serving, t.servingSize, 5000, suffix: t.unitG)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('product-package', _package, t.packageSize, 20000, suffix: t.unitG)),
                ],
              ),
              gap,
              TextFormField(
                key: const Key('product-barcode'),
                controller: _barcode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
                decoration: InputDecoration(labelText: t.barcodeOptional),
                validator: (v) =>
                    v == null || v.isEmpty || RegExp(r'^\d{8,14}$').hasMatch(v) ? null : t.errBarcodeInvalid,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
