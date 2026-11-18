import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'food_photo.dart';
import 'food_search_sheet.dart';
import 'nutrition_widgets.dart';
import 'product_screen.dart';
import 'scan_flow.dart';

/// Opens the barcode scanner. [useCamera] false shows only the manual entry (tests, devices without a camera).
Future<void> openBarcodeScanner(
  BuildContext context, {
  NutritionProfile? profile,
  FoodPhotoPicker picker = pickFoodPhoto,
  VoidCallback? onChanged,
  bool useCamera = true,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => BarcodeScreen(profile: profile, picker: picker, onChanged: onChanged, useCamera: useCamera),
  ),
);

enum _NotFoundChoice { label, search, create }

/// Live barcode scanning with the rear camera, and a field to type the digits under the barcode. A found product
/// opens its card; an unknown one offers to photograph the label, find the food by name or create it.
class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key, this.profile, this.picker = pickFoodPhoto, this.onChanged, this.useCamera = true});
  final NutritionProfile? profile;
  final FoodPhotoPicker picker;
  final VoidCallback? onChanged;
  final bool useCamera;

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  late final MobileScannerController? _camera = widget.useCamera
      ? MobileScannerController(
          formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.itf14],
        )
      : null;
  final _manual = TextEditingController();
  bool _busy = false;
  String? _lastCode;

  static final _valid = RegExp(r'^\d{8,14}$');

  @override
  void dispose() {
    _camera?.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final code = b.rawValue?.trim();
      if (code != null && _valid.hasMatch(code) && code != _lastCode) {
        HapticFeedback.mediumImpact();
        _lookup(code);
        return;
      }
    }
  }

  Future<void> _lookup(String code) async {
    final t = AppLocalizations.of(context);
    if (!_valid.hasMatch(code)) {
      showSnack(context, t.errBarcodeInvalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    final nav = Navigator.of(context);
    try {
      final scan = await context.read<NutritionRepository>().barcode(code);
      widget.onChanged?.call();
      if (!mounted) return;
      final product = scan.product;
      if (product == null) throw ApiException(404, 'barcode_not_found', '');
      await nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProductScreen(product: product, scanId: scan.id, onChanged: widget.onChanged),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.code == 'barcode_not_found') {
        await _notFound(code);
      } else {
        showSnack(context, errorText(t, e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(t, e));
      }
    }
  }

  Future<void> _notFound(String code) async {
    final choice = await showGlassSheet<_NotFoundChoice>(
      context,
      builder: (_) => _NotFoundView(code: code, labelAvailable: widget.profile?.aiAvailable ?? false),
    );
    if (!mounted || choice == null) {
      _lastCode = null; // the same code may be scanned again
      return;
    }
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    switch (choice) {
      case _NotFoundChoice.label:
        await startPhotoScan(
          context,
          source: FoodPhotoSource.camera,
          profile: widget.profile,
          picker: widget.picker,
          mode: ScanMode.label,
          barcode: code,
          onChanged: widget.onChanged,
        );
      case _NotFoundChoice.search:
        final pick = await showFoodSearch(context, title: t.findManually, askGrams: false);
        if (pick == null || !mounted) return;
        if (pick.product != null) {
          await nav.pushReplacement(
            MaterialPageRoute<void>(builder: (_) => ProductScreen(product: pick.product!, onChanged: widget.onChanged)),
          );
        } else {
          await _addRecipe(pick.recipe!);
        }
      case _NotFoundChoice.create:
        final product = await nav.push<FoodProduct>(
          MaterialPageRoute(builder: (_) => CreateProductScreen(barcode: code)),
        );
        if (product == null || !mounted) return;
        await nav.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => ProductScreen(product: product, onChanged: widget.onChanged)),
        );
    }
    _lastCode = null;
  }

  Future<void> _addRecipe(FoodRecipeSummary recipe) async {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final grams = await showGramsSheet(
      context,
      title: recipe.localName(lang),
      initial: recipe.portionGrams,
      quick: [(t.portion(recipe.portionGrams.round()), recipe.portionGrams)],
    );
    if (grams == null || !mounted) return;
    try {
      await context.read<NutritionRepository>().addEntry(
        SaveDiaryEntry(
          mealType: MealType.snack,
          name: recipe.localName(lang),
          items: [DiaryItemInput(recipeId: recipe.id, name: recipe.localName(lang), grams: grams)],
        ),
      );
      widget.onChanged?.call();
      if (mounted) {
        showSnack(context, t.addedToDiary(t.mealSnack));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return NutritionPage(
      title: t.barcodeTitle,
      subtitle: t.barcodeSubtitle,
      children: [
        if (_camera != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(Brand.radiusHero),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _camera,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            error.errorCode == MobileScannerErrorCode.permissionDenied
                                ? t.foodPhotoPermission
                                : t.barcodeCameraUnavailable,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Brand.textSecondary, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 240,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Brand.clock, width: 2),
                        ),
                      ),
                    ),
                  ),
                  if (_busy)
                    const ColoredBox(
                      color: Color(0x88000000),
                      child: Center(child: CircularProgressIndicator(color: Brand.clock)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        GlassSectionHeader(t.barcodeManual),
        TextField(
          key: const Key('barcode-field'),
          controller: _manual,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
          decoration: InputDecoration(labelText: t.barcodeDigits),
          onSubmitted: _lookup,
        ),
        const SizedBox(height: 12),
        GradientPillButton(
          key: const Key('barcode-find'),
          label: t.barcodeFind,
          icon: Icons.search_rounded,
          height: 50,
          loading: _busy,
          onPressed: () => _lookup(_manual.text.trim()),
        ),
        const SizedBox(height: 12),
        InfoRow(icon: Icons.info_outline_rounded, text: t.barcodeSourceNote, color: Brand.clock),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.code, required this.labelAvailable});
  final String code;
  final bool labelAvailable;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('barcode-not-found'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: IconPlate(icon: Icons.qr_code_scanner_rounded, color: Brand.warning, iconColor: Brand.warningIcon, size: 56),
        ),
        const SizedBox(height: 14),
        Text(
          t.barcodeNotFoundTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          t.barcodeNotFoundBody(code),
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35),
        ),
        const SizedBox(height: 18),
        if (labelAvailable) ...[
          GradientPillButton(
            key: const Key('barcode-photo-label'),
            label: t.photoLabel,
            icon: Icons.document_scanner_outlined,
            height: 50,
            onPressed: () => Navigator.of(context).pop(_NotFoundChoice.label),
          ),
          const SizedBox(height: 10),
        ],
        GlassPillButton(
          key: const Key('barcode-search'),
          label: t.findManually,
          icon: Icons.search_rounded,
          onPressed: () => Navigator.of(context).pop(_NotFoundChoice.search),
        ),
        const SizedBox(height: 10),
        GlassPillButton(
          key: const Key('barcode-create'),
          label: t.createOwnProduct,
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(context).pop(_NotFoundChoice.create),
        ),
      ],
    );
  }
}
