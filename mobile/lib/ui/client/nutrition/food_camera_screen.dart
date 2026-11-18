import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/glass.dart';
import 'food_photo.dart';

/// Lists the device cameras (injectable: tests have none).
typedef CameraLister = Future<List<CameraDescription>> Function();

/// Picks a photo from the gallery and prepares it (injectable for tests).
typedef GalleryPicker = Future<Uint8List?> Function();

enum _CameraState { starting, ready, noCamera, noAccess, failed }

/// The app's own camera for food and labels: live preview with a framing guide, tap to focus, pinch or 1×/2× to zoom,
/// flash, gallery and the shutter. The system camera app is never opened. Pops with a JPEG prepared like any food
/// photo (orientation applied, metadata removed, scaled for upload), or null when closed.
class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({
    super.key,
    this.label = false,
    this.cameras = availableCameras,
    this.gallery = pickFoodPhotoFromGallery,
  });

  /// A package label instead of a dish: another guide and hint.
  final bool label;
  final CameraLister cameras;
  final GalleryPicker gallery;

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  CameraDescription? _camera;
  _CameraState _state = _CameraState.starting;
  FlashMode _flash = FlashMode.off;
  double _minZoom = 1, _maxZoom = 1, _zoom = 1, _zoomAtPinch = 1;
  bool _busy = false;
  Offset? _focusAt;
  Timer? _focusTimer;
  late final _shutterFlash = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _shutterFlash.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // The camera is released while the app is in the background and opened again on return (the plugin's guidance).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive && controller != null) {
      _controller = null;
      controller.dispose();
      if (mounted) setState(() => _state = _CameraState.starting);
    } else if (state == AppLifecycleState.resumed && _controller == null && _state != _CameraState.noCamera) {
      _start();
    }
  }

  Future<void> _start() async {
    setState(() => _state = _CameraState.starting);
    try {
      final all = _camera == null ? await widget.cameras() : [_camera!];
      if (all.isEmpty) {
        if (mounted) setState(() => _state = _CameraState.noCamera);
        return;
      }
      _camera = all.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => all.first);
      // 1920×1080 is plenty for recognition (the photo is scaled to 1568 px anyway) and fast to process.
      final controller = CameraController(
        _camera!,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flash);
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = _zoom.clamp(_minZoom, _maxZoom).toDouble();
      if (_zoom != 1) await controller.setZoomLevel(_zoom);
      setState(() {
        _controller = controller;
        _state = _CameraState.ready;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('Denied') || e.code.contains('Restricted') || e.code.contains('ermission');
      setState(() => _state = denied ? _CameraState.noAccess : _CameraState.failed);
    } catch (_) {
      if (mounted) setState(() => _state = _CameraState.failed);
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || _busy || controller.value.isTakingPicture) return;
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_shutterFlash.forward(from: 0).then((_) => _shutterFlash.reverse()));
    try {
      final file = await controller.takePicture();
      await controller.pausePreview(); // the shot stays on screen while it is prepared
      final raw = await file.readAsBytes();
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));
      final (jpeg, problem) = await compute(prepareFoodPhoto, raw);
      if (!mounted) return;
      if (problem != null) {
        await controller.resumePreview();
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(foodPhotoProblemText(t, problem));
        return;
      }
      Navigator.of(context).pop(jpeg);
    } on CameraException catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(t.cameraFailedTitle);
    }
  }

  Future<void> _fromGallery() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    try {
      final jpeg = await widget.gallery();
      if (jpeg != null && mounted) Navigator.of(context).pop(jpeg);
    } on FoodPhotoException catch (e) {
      if (mounted) _snack(foodPhotoProblemText(t, e.problem));
    } catch (_) {
      if (mounted) _snack(t.foodPhotoUnreadable);
    }
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException catch (_) {
      // No flash on this camera: the button stays as it is.
    }
  }

  Future<void> _setZoom(double zoom) async {
    final value = zoom.clamp(_minZoom, math.min(_maxZoom, 8.0)).toDouble();
    if ((value - _zoom).abs() < 0.01) return;
    setState(() => _zoom = value);
    try {
      await _controller?.setZoomLevel(value);
    } on CameraException catch (_) {}
  }

  Future<void> _focus(TapUpDetails details, BoxConstraints box) async {
    final controller = _controller;
    if (controller == null || _busy) return;
    final point = Offset(
      (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / box.maxHeight).clamp(0.0, 1.0),
    );
    setState(() => _focusAt = details.localPosition);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusAt = null);
    });
    try {
      if (controller.value.focusPointSupported) await controller.setFocusPoint(point);
      if (controller.value.exposurePointSupported) await controller.setExposurePoint(point);
    } on CameraException catch (_) {}
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('food-camera'),
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_state == _CameraState.ready && _controller != null) _preview(_controller!) else _placeholder(t),
            if (_state == _CameraState.ready) IgnorePointer(child: _Guide(label: widget.label)),
            IgnorePointer(
              child: FadeTransition(
                opacity: _shutterFlash,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            _topBar(t),
            if (_state == _CameraState.ready) _bottomBar(t),
          ],
        ),
      ),
    );
  }

  /// The preview fills the screen (cropped at the sides); the photo keeps the whole frame.
  Widget _preview(CameraController controller) {
    final size = controller.value.previewSize;
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        key: const Key('camera-preview'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _focus(d, box),
        onScaleStart: (_) => _zoomAtPinch = _zoom,
        onScaleUpdate: (d) {
          if (d.pointerCount > 1) _setZoom(_zoomAtPinch * d.scale);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: size == null
                    ? SizedBox(width: box.maxWidth, height: box.maxHeight, child: CameraPreview(controller))
                    // previewSize is landscape; the screen is portrait.
                    : SizedBox(width: size.height, height: size.width, child: CameraPreview(controller)),
              ),
            ),
            if (_focusAt != null)
              Positioned(
                left: _focusAt!.dx - 36,
                top: _focusAt!.dy - 36,
                child: const _FocusRing(),
              ),
            if (_busy)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: GlassCard(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Brand.clock),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context).cameraProcessing,
                          style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppLocalizations t) {
    if (_state == _CameraState.starting) {
      return const Center(child: CircularProgressIndicator(color: Brand.clock));
    }
    final (icon, title, body) = switch (_state) {
      _CameraState.noAccess => (Icons.no_photography_outlined, t.cameraNoAccessTitle, t.cameraNoAccessBody),
      _CameraState.noCamera => (Icons.no_photography_outlined, t.cameraUnavailableTitle, t.cameraUnavailableBody),
      _ => (Icons.error_outline_rounded, t.cameraFailedTitle, t.cameraFailedBody),
    };
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            key: Key('camera-${_state.name}'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: IconPlate(icon: icon, color: Colors.white.withValues(alpha: 0.08), iconColor: Brand.textSecondary, size: 64),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.textSecondary, fontSize: 15, height: 1.35),
              ),
              const SizedBox(height: 24),
              if (_state == _CameraState.noAccess && Platform.isIOS) ...[
                GradientPillButton(
                  key: const Key('camera-settings'),
                  label: t.cameraOpenSettings,
                  icon: Icons.settings_outlined,
                  height: 52,
                  onPressed: () => launchUrl(Uri.parse('app-settings:')),
                ),
                const SizedBox(height: 10),
              ],
              if (_state == _CameraState.failed) ...[
                GradientPillButton(
                  key: const Key('camera-retry'),
                  label: t.retry,
                  icon: Icons.refresh_rounded,
                  height: 52,
                  onPressed: _start,
                ),
                const SizedBox(height: 10),
              ],
              GlassPillButton(
                key: const Key('camera-gallery-fallback'),
                label: t.fromGallery,
                icon: Icons.photo_library_outlined,
                onPressed: _fromGallery,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(AppLocalizations t) {
    final ready = _state == _CameraState.ready;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  GlassCircleButton(
                    key: const Key('camera-close'),
                    icon: Icons.close_rounded,
                    tooltip: t.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: GlassCard(
                        radius: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          widget.label ? t.cameraLabelTitle : t.cameraDishTitle,
                          style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  if (ready)
                    GlassCircleButton(
                      key: const Key('camera-flash'),
                      icon: switch (_flash) {
                        FlashMode.off => Icons.flash_off_rounded,
                        FlashMode.auto => Icons.flash_auto_rounded,
                        _ => Icons.flash_on_rounded,
                      },
                      iconColor: _flash == FlashMode.off ? Brand.textPrimary : Brand.trophy,
                      tooltip: switch (_flash) {
                        FlashMode.off => t.cameraFlashOff,
                        FlashMode.auto => t.cameraFlashAuto,
                        _ => t.cameraFlashOn,
                      },
                      onTap: _toggleFlash,
                    )
                  else
                    const SizedBox.square(dimension: 44),
                ],
              ),
              if (ready) ...[
                const SizedBox(height: 12),
                Text(
                  widget.label ? t.cameraLabelHint : t.cameraDishHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(AppLocalizations t) {
    final canZoom2x = _maxZoom >= 2;
    final zoomLabel = _zoom >= 1.95 ? '2×' : '${(_zoom * 10).round() / 10}×'.replaceAll('.0×', '×');
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassCircleButton(
                key: const Key('camera-gallery'),
                icon: Icons.photo_library_outlined,
                size: 54,
                iconSize: 24,
                tooltip: t.fromGallery,
                onTap: _fromGallery,
              ),
              _Shutter(busy: _busy, label: t.cameraShutter, onTap: _shoot),
              if (canZoom2x)
                Semantics(
                  button: true,
                  label: t.cameraZoom(zoomLabel),
                  child: GlassCard(
                    key: const Key('camera-zoom'),
                    radius: 27,
                    padding: EdgeInsets.zero,
                    onTap: () => _setZoom(_zoom >= 1.95 ? 1 : 2),
                    child: SizedBox.square(
                      dimension: 54,
                      child: Center(
                        child: Text(
                          zoomLabel,
                          style: TextStyle(
                            color: _zoom > 1.05 ? Brand.trophy : Brand.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.square(dimension: 54),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big round shutter: white ring, white disc that shrinks while pressed, a spinner while the photo is prepared.
class _Shutter extends StatefulWidget {
  const _Shutter({required this.busy, required this.label, required this.onTap});
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        key: const Key('camera-shutter'),
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        child: Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: AnimatedScale(
            scale: _down ? 0.86 : 1,
            duration: const Duration(milliseconds: 90),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: widget.busy
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 3, color: Brand.background),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corner brackets of the area to fill: a square for a plate, a wide rectangle for a label.
class _Guide extends StatelessWidget {
  const _Guide({required this.label});
  final bool label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth * (label ? 0.86 : 0.82);
        final height = label ? width * 0.75 : width;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(painter: _CornersPainter()),
          ),
        );
      },
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const arm = 30.0, r = 18.0;
    for (final (x, y, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(x, y + sy * arm)
        ..lineTo(x, y + sy * r)
        ..arcToPoint(Offset(x + sx * r, y), radius: const Radius.circular(r), clockwise: sx * sy > 0)
        ..lineTo(x + sx * arm, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}

class _FocusRing extends StatelessWidget {
  const _FocusRing();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.35, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Brand.trophy, width: 2),
        ),
      ),
    );
  }
}
