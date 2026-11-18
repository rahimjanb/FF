import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'food_search_sheet.dart';
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';

/// A packaged product found by barcode or read from its label: values per 100 g (ml), serving and package sizes,
/// allergens and ingredients as printed. The client picks how much they ate and adds it to the diary.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.product, this.scanId, this.onChanged, this.mealType});
  final FoodProduct product;

  /// The barcode or label scan the product came from (marks it as added in the history).
  final String? scanId;
  final VoidCallback? onChanged;
  final MealType? mealType;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late double _grams = widget.product.servingGrams ?? 100;
  late MealType _meal = widget.mealType ?? mealTypeForTime(DateTime.now().toUtc().add(AppConfig.clubUtcOffset));
  bool _busy = false;

  Future<void> _editGrams() async {
    final grams = await askProductGrams(context, widget.product, initial: _grams);
    if (grams != null && mounted) setState(() => _grams = grams);
  }

  Future<void> _add() async {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() => _busy = true);
    try {
      await context.read<NutritionRepository>().addEntry(
        SaveDiaryEntry(
          mealType: _meal,
          name: widget.product.localName(lang),
          scanId: widget.scanId,
          items: [DiaryItemInput(productId: widget.product.id, name: widget.product.localName(lang), grams: _grams)],
        ),
      );
      widget.onChanged?.call();
      if (!mounted) return;
      showSnack(context, t.addedToDiary(mealTypeLabel(t, _meal)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fmt = NutritionFmt(t, lang);
    final p = widget.product;
    final unit = p.per100Ml ? t.unitMl : t.unitG;
    final portion = p.per100.forGrams(_grams);
    return NutritionPage(
      listKey: const Key('product-screen'),
      title: p.localName(lang),
      subtitle: p.brand,
      bottom: GradientPillButton(
        key: const Key('product-add'),
        label: t.addToDiary,
        icon: Icons.add_rounded,
        height: 54,
        loading: _busy,
        onPressed: _add,
      ),
      children: [
        GlassCard(
          radius: Brand.radiusHero,
          glow: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SourceChip(source: p.source),
                  if (p.barcode != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        p.barcode!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Brand.textTertiary, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(p.per100Ml ? t.per100Ml : t.per100g, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
              Text(
                '${fmt.kcalExact(p.per100.kcal)} ${t.unitKcal}',
                style: const TextStyle(color: Brand.textPrimary, fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              NutrientGrid(values: p.per100),
              if (p.servingGrams != null || p.packageGrams != null) ...[
                const SizedBox(height: 12),
                Text(
                  [
                    if (p.servingGrams != null) '${t.servingSize}: ${fmt.kcalExact(p.servingGrams!)} $unit',
                    if (p.packageGrams != null) '${t.packageSize}: ${fmt.kcalExact(p.packageGrams!)} $unit',
                  ].join(' · '),
                  style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (p.allergens.isNotEmpty || p.ingredientsText != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.allergens.isNotEmpty) ...[
                  Text(t.allergensStated, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in p.allergens)
                        SoftTag(allergenLabel(t, a), color: Brand.redText, icon: Icons.warning_amber_rounded),
                    ],
                  ),
                ],
                if (p.ingredientsText != null) ...[
                  if (p.allergens.isNotEmpty) const SizedBox(height: 12),
                  Text(t.composition, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(p.ingredientsText!, style: const TextStyle(color: Brand.textPrimary, fontSize: 13, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.howMuchEaten),
        GlassCard(
          key: const Key('product-grams'),
          radius: 20,
          onTap: _editGrams,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fmt.kcalExact(_grams)} $unit',
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmt.kcal(portion.kcal)} ${t.unitKcal} · ${t.proteinShort} ${fmt.macro(portion.protein)} · '
                      '${t.fatShort} ${fmt.macro(portion.fat)} · ${t.carbsShort} ${fmt.macro(portion.carbs)}',
                      style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: Brand.textSecondary, size: 20),
            ],
          ),
        ),
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.mealTypeTitle),
        MealTypeSelector(value: _meal, onChanged: (m) => setState(() => _meal = m)),
      ],
    );
  }
}
