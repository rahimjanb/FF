import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/progress_ring.dart';
import 'nutrition_format.dart';

/// Colors of the macronutrients across the nutrition screens.
class MacroColors {
  static const protein = Brand.clock;
  static const fat = Brand.trophy;
  static const carbs = Brand.purple;
  static const kcal = Brand.accent;
  static const over = Brand.flame;
}

/// A pushed nutrition screen: glass background, back button, large title and a scrolling body.
class NutritionPage extends StatelessWidget {
  const NutritionPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
    this.onRefresh,
    this.bottom,
    this.listKey,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  /// Pinned under the list (e.g. a primary action), above the safe area.
  final Widget? bottom;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final list = ListView(
      key: listKey,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Brand.sidePadding,
        8,
        Brand.sidePadding,
        (bottom == null ? MediaQuery.paddingOf(context).bottom : 0) + 24,
      ),
      children: [
        Row(
          children: [
            GlassCircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 18,
              tooltip: t.back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
        ],
        const SizedBox(height: Brand.sectionGap),
        ...children,
      ],
    );
    return Scaffold(
      backgroundColor: Brand.background,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: onRefresh == null ? list : RefreshIndicator(color: Brand.accent, onRefresh: onRefresh!, child: list),
              ),
              if (bottom != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Brand.sidePadding,
                    8,
                    Brand.sidePadding,
                    MediaQuery.paddingOf(context).bottom + 12,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calories eaten against the daily target: ring with the number inside.
class KcalRing extends StatelessWidget {
  const KcalRing({super.key, required this.consumed, required this.target, this.size = 128});
  final double consumed;
  final int? target;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final over = target != null && consumed > target!;
    final value = target == null || target == 0 ? 0.0 : consumed / target!;
    return Semantics(
      label: target == null
          ? t.kcalEatenSemantics(fmt.kcal(consumed))
          : t.kcalOfTargetSemantics(fmt.kcal(consumed), fmt.kcalExact(target!.toDouble())),
      excludeSemantics: true,
      child: ProgressRing(
        value: value,
        size: size,
        color: over ? MacroColors.over : MacroColors.kcal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              child: Text(
                fmt.kcal(consumed),
                style: TextStyle(
                  color: Brand.textPrimary,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            Text(
              target == null ? t.unitKcal : t.ofKcal(fmt.kcalExact(target!.toDouble())),
              style: TextStyle(color: Brand.textSecondary, fontSize: size * 0.09),
            ),
          ],
        ),
      ),
    );
  }
}

/// One macro: label, value / target and a thin bar.
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.value, this.target, required this.color});
  final String label;
  final double value;
  final int? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final share = target == null || target == 0 ? 0.0 : (value / target!).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: fmt.macro(value),
                style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: target == null ? ' ${t.unitG}' : ' / $target ${t.unitG}',
                style: TextStyle(color: Brand.textSecondary, fontSize: 12),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.1))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: share),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    child: ColoredBox(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Protein, fat and carbs side by side.
class MacroRow extends StatelessWidget {
  const MacroRow({super.key, required this.values, this.target});
  final Nutrients values;
  final NutritionTarget? target;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: MacroBar(label: t.protein, value: values.protein, target: target?.proteinG, color: MacroColors.protein),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: MacroBar(label: t.fat, value: values.fat, target: target?.fatG, color: MacroColors.fat),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: MacroBar(label: t.carbs, value: values.carbs, target: target?.carbsG, color: MacroColors.carbs),
        ),
      ],
    );
  }
}

/// All nutrients of a dish or product as a compact grid.
class NutrientGrid extends StatelessWidget {
  const NutrientGrid({super.key, required this.values});
  final Nutrients values;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    final cells = [
      (t.protein, fmt.macroG(values.protein), MacroColors.protein),
      (t.fat, fmt.macroG(values.fat), MacroColors.fat),
      (t.carbs, fmt.macroG(values.carbs), MacroColors.carbs),
      (t.fiber, fmt.macroG(values.fiber), Brand.successText),
      (t.sugar, fmt.macroG(values.sugar), Brand.redText),
      (t.saturatedFat, fmt.macroG(values.saturatedFat), Brand.warningText),
      (t.sodium, fmt.mg(values.sodiumMg), Brand.blueIcon),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value, color) in cells)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Brand.textSecondary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small colored capsule naming where nutrition values come from.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});
  final NutritionSource source;

  @override
  Widget build(BuildContext context) {
    final color = sourceColor(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        sourceLabel(AppLocalizations.of(context), source),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Small rounded tag (allergen, category, «возможно»).
class SoftTag extends StatelessWidget {
  const SoftTag(this.label, {super.key, this.color = Brand.clock, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// An info row with an icon: soft warnings and hints.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.text, this.color = Brand.warningText});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: Brand.textSecondary, fontSize: 13, height: 1.3)),
        ),
      ],
    ),
  );
}

/// Recently loaded scan photos, so lists and the result screen do not load the same JPEG twice.
class ScanPhotoCache {
  // A map literal keeps insertion order, which the eviction below relies on.
  static final _cache = <String, Uint8List>{};
  static const _max = 40;

  static Uint8List? get(String scanId) => _cache[scanId];

  static void put(String scanId, Uint8List bytes) {
    _cache.remove(scanId);
    _cache[scanId] = bytes;
    while (_cache.length > _max) {
      _cache.remove(_cache.keys.first);
    }
  }

  static void remove(String scanId) => _cache.remove(scanId);
}

/// Photo of a scan loaded with the bearer token; a food icon while loading or when there is none.
class ScanPhoto extends StatefulWidget {
  const ScanPhoto({super.key, required this.scanId, this.size = 52, this.radius = 14, this.fit = BoxFit.cover});
  final String? scanId;
  final double? size;
  final double radius;
  final BoxFit fit;

  @override
  State<ScanPhoto> createState() => _ScanPhotoState();
}

class _ScanPhotoState extends State<ScanPhoto> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ScanPhoto old) {
    super.didUpdateWidget(old);
    if (old.scanId != widget.scanId) _load();
  }

  Future<void> _load() async {
    final id = widget.scanId;
    if (id == null) return;
    final cached = ScanPhotoCache.get(id);
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final bytes = await context.read<NutritionRepository>().scanPhoto(id);
      ScanPhotoCache.put(id, bytes);
      if (mounted && widget.scanId == id) setState(() => _bytes = bytes);
    } catch (_) {
      // The placeholder stays: the photo may have been deleted.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: bytes == null
            ? DecoratedBox(
                decoration: BoxDecoration(gradient: Brand.glassGradient),
                child: Icon(Icons.restaurant_rounded, color: Brand.textTertiary, size: (widget.size ?? 52) * 0.42),
              )
            : Image.memory(bytes, fit: widget.fit, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox()),
      ),
    );
  }
}

/// Choice of breakfast / lunch / dinner / snack.
class MealTypeSelector extends StatelessWidget {
  const MealTypeSelector({super.key, required this.value, required this.onChanged});
  final MealType value;
  final ValueChanged<MealType> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in MealType.values)
          ChoiceChip(
            key: Key('meal-${m.name}'),
            selected: m == value,
            showCheckmark: false,
            avatar: Icon(mealTypeIcon(m), size: 16, color: m == value ? Colors.white : Brand.textSecondary),
            label: Text(mealTypeLabel(t, m)),
            labelStyle: TextStyle(
              color: m == value ? Colors.white : Brand.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            selectedColor: Brand.accent.withValues(alpha: 0.35),
            side: BorderSide(color: m == value ? Brand.accent.withValues(alpha: 0.6) : Brand.glassStroke),
            shape: const StadiumBorder(),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onChanged(m);
            },
          ),
      ],
    );
  }
}

/// Asks for a weight in grams: quick chips plus a field. Returns null when cancelled.
Future<double?> showGramsSheet(
  BuildContext context, {
  required String title,
  double? initial,
  List<(String, double)> quick = const [],
  bool perMl = false,
}) => showGlassSheet<double>(
  context,
  builder: (_) => _GramsSheet(title: title, initial: initial, quick: quick, perMl: perMl),
);

class _GramsSheet extends StatefulWidget {
  const _GramsSheet({required this.title, this.initial, required this.quick, required this.perMl});
  final String title;
  final double? initial;
  final List<(String, double)> quick;
  final bool perMl;

  @override
  State<_GramsSheet> createState() => _GramsSheetState();
}

class _GramsSheetState extends State<_GramsSheet> {
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.round().toString(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = AppLocalizations.of(context);
    final v = double.tryParse(_controller.text.replaceAll(',', '.').trim());
    if (v == null || v < 1 || v > 5000) {
      setState(() => _error = t.gramsInvalid);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        key: const Key('grams-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (widget.quick.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final (label, grams) in widget.quick)
                  ActionChip(
                    label: Text(label),
                    labelStyle: const TextStyle(color: Brand.textPrimary, fontWeight: FontWeight.w600),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(color: Brand.glassStroke),
                    shape: const StadiumBorder(),
                    onPressed: () => setState(() {
                      _controller.text = grams.round().toString();
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            key: const Key('grams-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: widget.perMl ? t.amountMl : t.amountGrams,
              errorText: _error,
              suffixText: widget.perMl ? t.unitMl : t.unitG,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          GradientPillButton(key: const Key('grams-ok'), label: t.done, height: 52, onPressed: _submit),
        ],
      ),
    );
  }
}
