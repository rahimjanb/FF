import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'ai_consent.dart';
import 'food_photo.dart';
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';
import 'product_screen.dart';
import 'scan_result_screen.dart';

/// What the photo is analysed for: a dish (recognition) or a package label (nutrition facts).
enum ScanMode { dish, label }

/// Takes or picks a photo and opens the preview. [onChanged] runs whenever something was saved (a scan, a diary
/// entry), so the screen underneath can reload; the returned future completes when the preview is left.
Future<void> startPhotoScan(
  BuildContext context, {
  required FoodPhotoSource source,
  required NutritionProfile? profile,
  FoodPhotoPicker picker = pickFoodPhoto,
  ScanMode mode = ScanMode.dish,
  String? barcode,
  VoidCallback? onChanged,
}) async {
  final t = AppLocalizations.of(context);
  final Uint8List? jpeg;
  try {
    jpeg = await picker(context, source, label: mode == ScanMode.label);
  } on FoodPhotoException catch (e) {
    if (context.mounted) showSnack(context, foodPhotoProblemText(t, e.problem));
    return;
  } catch (_) {
    if (context.mounted) showSnack(context, t.foodPhotoUnreadable);
    return;
  }
  if (jpeg == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ScanPreviewScreen(
        photo: jpeg!,
        profile: profile,
        picker: picker,
        mode: mode,
        barcode: barcode,
        onChanged: onChanged,
      ),
    ),
  );
}

/// The photo before it is sent: an optional hint («это лагман») and the analyse button. While the AI works, the
/// photo stays on screen under a scanning animation. Nothing is added to the diary here.
class ScanPreviewScreen extends StatefulWidget {
  const ScanPreviewScreen({
    super.key,
    required this.photo,
    required this.profile,
    this.picker = pickFoodPhoto,
    this.mode = ScanMode.dish,
    this.barcode,
    this.initialHint,
    this.onChanged,
  });
  final Uint8List photo;
  final NutritionProfile? profile;
  final FoodPhotoPicker picker;
  final ScanMode mode;

  /// For a label: the barcode the product was not found by, to link them.
  final String? barcode;
  final String? initialHint;

  /// Something was saved: a new scan, a product read from a label, a diary entry.
  final VoidCallback? onChanged;

  @override
  State<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends State<ScanPreviewScreen> {
  late Uint8List _photo = widget.photo;
  late final _hint = TextEditingController(text: widget.initialHint ?? '');
  late NutritionProfile? _profile = widget.profile;
  bool _analyzing = false;
  Object? _error;

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  Future<void> _retake(FoodPhotoSource source) async {
    final t = AppLocalizations.of(context);
    try {
      final jpeg = await widget.picker(context, source, label: widget.mode == ScanMode.label);
      if (jpeg != null && mounted) {
        setState(() {
          _photo = jpeg;
          _error = null;
        });
      }
    } on FoodPhotoException catch (e) {
      if (mounted) showSnack(context, foodPhotoProblemText(t, e.problem));
    } catch (_) {
      if (mounted) showSnack(context, t.foodPhotoUnreadable);
    }
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    final repo = context.read<NutritionRepository>();
    final agreed = await ensureAiConsent(context, _profile);
    if (agreed == null || !mounted) return;
    _profile = agreed;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    final FoodScan scan;
    try {
      scan = widget.mode == ScanMode.dish
          ? await repo.analyze(_photo, hint: _hint.text)
          : await repo.readLabel(_photo, barcode: widget.barcode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      if (isConsentError(e)) {
        // The consent was revoked meanwhile (e.g. on another device): ask again, then run the analysis again.
        final again = await showAiConsentSheet(context, provider: _profile?.aiProvider);
        if (again != null && mounted) {
          _profile = again;
          await _analyze();
        }
        return;
      }
      setState(() => _error = e);
      return;
    }
    if (!mounted) return;
    widget.onChanged?.call();
    final nav = Navigator.of(context);
    if (widget.mode == ScanMode.label) {
      if (scan.product != null && scan.status == FoodScanStatus.recognized) {
        await nav.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ProductScreen(product: scan.product!, scanId: scan.id, onChanged: widget.onChanged),
          ),
        );
        return;
      }
      // The label could not be read: say so here, the photo can be retaken right away.
      setState(() {
        _analyzing = false;
        _error = _LabelUnreadable(scan.clarificationQuestion);
      });
      return;
    }
    await nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScanResultScreen(
          scan: scan,
          photo: _photo,
          profile: _profile,
          picker: widget.picker,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final label = widget.mode == ScanMode.label;
    final error = _error;
    return PopScope(
      canPop: !_analyzing,
      child: NutritionPage(
        title: label ? t.labelPreviewTitle : t.scanPreviewTitle,
        subtitle: label ? t.labelPreviewSubtitle : t.scanPreviewSubtitle,
        bottom: _analyzing
            ? null
            : GradientPillButton(
                key: const Key('scan-analyze'),
                label: label ? t.readLabel : t.analyzeFood,
                icon: Icons.auto_awesome_rounded,
                height: 54,
                onPressed: _analyze,
              ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Brand.radiusHero),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_photo, key: const Key('scan-preview-photo'), fit: BoxFit.cover),
                  if (_analyzing) AnalyzingOverlay(label: label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (error != null) ...[
            GlassCard(
              key: const Key('scan-error'),
              radius: 20,
              child: InfoRow(
                icon: Icons.error_outline_rounded,
                color: Brand.redText,
                text: error is _LabelUnreadable ? (error.question ?? t.labelUnreadable) : errorText(t, error),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!label && !_analyzing)
            TextField(
              key: const Key('scan-hint'),
              controller: _hint,
              maxLength: 200,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: t.scanHintLabel, hintText: t.scanHintExample),
            ),
          if (!_analyzing)
            Row(
              children: [
                Expanded(
                  child: GlassPillButton(
                    key: const Key('scan-retake'),
                    label: t.retakePhoto,
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => _retake(FoodPhotoSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassPillButton(
                    key: const Key('scan-regallery'),
                    label: t.fromGallery,
                    icon: Icons.photo_library_outlined,
                    onPressed: () => _retake(FoodPhotoSource.gallery),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The label photo was readable as an image, but no nutrition facts were found on it.
class _LabelUnreadable {
  const _LabelUnreadable(this.question);
  final String? question;
}

/// Scanning line, glass tint and rotating status texts over the photo while the AI analyses it.
class AnalyzingOverlay extends StatefulWidget {
  const AnalyzingOverlay({super.key, this.label = false});
  final bool label;

  @override
  State<AnalyzingOverlay> createState() => _AnalyzingOverlayState();
}

class _AnalyzingOverlayState extends State<AnalyzingOverlay> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) => setState(() => _step++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final texts = widget.label
        ? [t.analyzingLabel1, t.analyzingLabel2, t.analyzingLabel3]
        : [t.analyzing1, t.analyzing2, t.analyzing3, t.analyzing4];
    final text = texts[_step % texts.length];
    return Semantics(
      key: const Key('scan-analyzing'),
      liveRegion: true,
      label: text,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => LayoutBuilder(
              builder: (context, c) {
                final y = Curves.easeInOut.transform(_sweep.value < 0.5 ? _sweep.value * 2 : 2 - _sweep.value * 2);
                return Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: y * (c.maxHeight - 90),
                      height: 90,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Brand.accent.withValues(alpha: 0),
                              Brand.accent.withValues(alpha: 0.35),
                              Brand.clock.withValues(alpha: 0.9),
                              Brand.accent.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.6, 0.62, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GlassCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Brand.clock),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        text,
                        key: ValueKey(text),
                        style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
