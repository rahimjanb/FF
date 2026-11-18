import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

// ---------------------------------------------------------------------------------------------------------------
// Photo preparation

enum FacePhotoSource { camera, gallery }

/// Why a picked photo cannot be used: [camera] — no camera (e.g. the iOS simulator); [permission] — access denied.
enum FacePhotoProblem { unreadable, tooSmall, camera, permission }

class FacePhotoException implements Exception {
  const FacePhotoException(this.problem);
  final FacePhotoProblem problem;
}

/// Returns a JPEG ready for upload, or null when the user cancelled.
typedef FacePhotoPicker = Future<Uint8List?> Function(FacePhotoSource source);

/// What the turnstile terminal accepts (backend FaceService): JPEG up to 200 KB, at least 240 px on each side.
const faceMaxBytes = 200 * 1024;
const faceMinSide = 240;

/// The longer side after scaling: plenty for the face model, small enough for the 200 KB limit.
const faceMaxSide = 720;

/// Decodes the photo, applies the EXIF orientation (terminals ignore it), scales the longer side down to
/// [faceMaxSide] and encodes a JPEG of at most [faceMaxBytes]: lower quality first, then a smaller size.
/// Pure Dart: runs in a background isolate.
(Uint8List?, FacePhotoProblem?) prepareFacePhoto(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return (null, FacePhotoProblem.unreadable);
  final image = img.bakeOrientation(decoded);
  if (math.min(image.width, image.height) < faceMinSide) return (null, FacePhotoProblem.tooSmall);
  for (final side in const [faceMaxSide, 600, 480]) {
    final scaled = math.max(image.width, image.height) <= side
        ? image
        : image.width >= image.height
        ? img.copyResize(image, width: side, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: side, interpolation: img.Interpolation.average);
    if (math.min(scaled.width, scaled.height) < faceMinSide) return (null, FacePhotoProblem.tooSmall);
    for (var quality = 85; quality >= 45; quality -= 10) {
      final jpeg = img.encodeJpg(scaled, quality: quality);
      if (jpeg.length <= faceMaxBytes) return (jpeg, null);
    }
  }
  return (null, FacePhotoProblem.unreadable);
}

/// Takes a selfie (front camera) or picks a photo from the gallery and prepares it for the terminal.
Future<Uint8List?> pickFacePhoto(FacePhotoSource source) async {
  final XFile? file;
  try {
    // The native picker scales and re-encodes first (HEIC from the gallery becomes JPEG), so Dart decodes less.
    file = await ImagePicker().pickImage(
      source: source == FacePhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 92,
      requestFullMetadata: false,
    );
  } on PlatformException catch (e) {
    throw FacePhotoException(e.code.contains('denied') ? FacePhotoProblem.permission : FacePhotoProblem.camera);
  }
  if (file == null) return null;
  final (jpeg, problem) = await compute(prepareFacePhoto, await file.readAsBytes());
  if (problem != null) throw FacePhotoException(problem);
  return jpeg;
}

String facePhotoProblemText(AppLocalizations t, FacePhotoProblem p) => switch (p) {
  FacePhotoProblem.unreadable => t.faceErrorUnreadable,
  FacePhotoProblem.tooSmall => t.faceErrorTooSmall,
  FacePhotoProblem.camera => t.faceErrorCamera,
  FacePhotoProblem.permission => t.faceErrorPermission,
};

// ---------------------------------------------------------------------------------------------------------------
// Entry points

/// Opens the face entry screen; completes when the client comes back.
Future<void> openFaceAccess(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FaceAccessScreen()));

/// After a membership request is sent: if the client has no face photo yet, offers to add one now, so the
/// turnstile lets them in by face once the membership starts. [onReturn] runs after the face screen is closed.
Future<void> offerFaceAfterRequest(BuildContext context, {Future<void> Function()? onReturn}) async {
  final FaceAccess face;
  try {
    face = await context.read<ClientRepository>().faceAccess();
  } catch (_) {
    return; // the offer is optional
  }
  if (face.status != FaceAccessStatus.none || !context.mounted) return;
  final add = await showGlassSheet<bool>(context, builder: (_) => const _FaceOfferView());
  if (add != true || !context.mounted) return;
  await openFaceAccess(context);
  await onReturn?.call();
}

class _FaceOfferView extends StatelessWidget {
  const _FaceOfferView();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('face-offer'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: IconPlate(
            icon: Icons.face_retouching_natural_rounded,
            color: Brand.accent,
            iconColor: Brand.clock,
            size: 56,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.faceOfferTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          t.faceOfferBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35),
        ),
        const SizedBox(height: 20),
        GradientPillButton(
          key: const Key('face-offer-add'),
          label: t.faceOfferAdd,
          icon: Icons.photo_camera_front_rounded,
          height: 52,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const Key('face-offer-later'),
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Brand.textSecondary, minimumSize: const Size(44, 44)),
          child: Text(t.later),
        ),
      ],
    );
  }
}

/// Short status for the membership screen and its badge.
(String, String, Color) faceShortStatus(AppLocalizations t, FaceAccessStatus? s) => switch (s) {
  FaceAccessStatus.ready => (t.faceShortReady, '✓', Brand.successText),
  FaceAccessStatus.rejected => (t.faceShortRejected, '!', Brand.redText),
  FaceAccessStatus.pending => (t.faceShortPending, '…', Brand.clock),
  FaceAccessStatus.waiting => (t.faceShortWaiting, '…', Brand.warningText),
  FaceAccessStatus.none || null => (t.faceShortNone, '+', Brand.clock),
};

/// Row on the membership screen: entry by face and its state. [access] null: the state could not be loaded.
class FaceAccessTile extends StatelessWidget {
  const FaceAccessTile({super.key, required this.access, required this.onTap});
  final FaceAccess? access;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, badge, color) = faceShortStatus(t, access?.status);
    return Semantics(
      button: true,
      label: '${t.faceAccessTitle}, $label',
      excludeSemantics: true,
      child: GlassCard(
        key: const Key('face-access-tile'),
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        onTap: onTap,
        child: Row(
          children: [
            const IconPlate(
              icon: Icons.face_retouching_natural_rounded,
              color: Brand.accent,
              iconColor: Brand.clock,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.faceAccessTitle,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    access == null ? t.faceAccessSubtitle : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: access == null ? Brand.textSecondary : color, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (access != null)
              Container(
                key: Key('face-badge-${access!.status.name}'),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Card on the home screen inviting a client with a membership to add a face photo.
class FaceHomePrompt extends StatelessWidget {
  const FaceHomePrompt({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return GlassCard(
      key: const Key('home-face-prompt'),
      radius: 20,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          const IconPlate(
            icon: Icons.face_retouching_natural_rounded,
            color: Brand.accent,
            iconColor: Brand.clock,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.faceHomePromptTitle,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(t.faceHomePromptBody, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Screen

/// Entry by face through the turnstile: the client takes a selfie (or picks a photo), agrees to its processing
/// and sends it; the club sends it to the Hikvision terminal at the entrance, which then lets the client in by face
/// for the days of the membership. The screen shows how far the photo got and lets the client replace or delete it.
class FaceAccessScreen extends StatefulWidget {
  const FaceAccessScreen({super.key, this.picker = pickFacePhoto});

  /// Source of photos; replaced in tests.
  final FacePhotoPicker picker;

  /// While the photo is being sent to the terminal, the state is checked this often, [maxPolls] times.
  static const pollInterval = Duration(seconds: 3);
  static const maxPolls = 10;

  @override
  State<FaceAccessScreen> createState() => _FaceAccessScreenState();
}

class _FaceAccessScreenState extends State<FaceAccessScreen> {
  FaceAccess? _access;
  Object? _error;
  Uint8List? _photo;
  Uint8List? _draft;
  bool _consent = false;
  bool _busy = false;
  Timer? _poll;
  int _polls = 0;

  ClientRepository get _repo => context.read<ClientRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final access = await _repo.faceAccess();
      Uint8List? photo;
      if (access.hasPhoto) {
        try {
          photo = await _repo.facePhoto();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _access = access;
        _photo = photo;
        _consent = _consent || access.hasPhoto; // given with the photo already sent
      });
      _watch(access, restart: true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Keeps checking while the photo is on its way to the terminal.
  void _watch(FaceAccess access, {bool restart = false}) {
    _poll?.cancel();
    if (restart) _polls = 0;
    if (access.status != FaceAccessStatus.pending || _polls >= FaceAccessScreen.maxPolls) return;
    _poll = Timer(FaceAccessScreen.pollInterval, () async {
      _polls++;
      try {
        final next = await _repo.faceAccess();
        if (!mounted) return;
        setState(() => _access = next);
        _watch(next);
      } catch (_) {
        if (mounted && _access != null) _watch(_access!);
      }
    });
  }

  Future<void> _pick(FacePhotoSource source) async {
    final t = AppLocalizations.of(context);
    try {
      final jpeg = await widget.picker(source);
      if (jpeg != null && mounted) setState(() => _draft = jpeg);
    } on FacePhotoException catch (e) {
      if (mounted) showSnack(context, facePhotoProblemText(t, e.problem));
    } catch (_) {
      if (mounted) showSnack(context, t.faceErrorUnreadable);
    }
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    final draft = _draft;
    if (draft == null) return;
    if (!_consent) {
      showSnack(context, t.faceConsentRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      final access = await _repo.uploadFace(draft);
      if (!mounted) return;
      setState(() {
        _access = access;
        _photo = draft;
        _draft = null;
      });
      showSnack(context, t.faceUploaded);
      _watch(access, restart: true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final confirmed = await showGlassSheet<bool>(context, builder: (_) => const _DeleteSheet());
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final access = await _repo.deleteFace();
      if (!mounted) return;
      _poll?.cancel();
      setState(() {
        _access = access;
        _photo = null;
        _consent = false;
      });
      showSnack(context, t.faceDeleted);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final access = _access;
    return Scaffold(
      backgroundColor: Brand.background,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: Brand.accent,
            onRefresh: _load,
            child: ListView(
              key: const Key('face-access-screen'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                Brand.sidePadding,
                8,
                Brand.sidePadding,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                Row(
                  children: [
                    GlassCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      iconSize: 18,
                      tooltip: t.back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  t.faceAccessTitle,
                  style: const TextStyle(
                    color: Brand.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(t.faceAccessSubtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
                const SizedBox(height: Brand.sectionGap),
                if (_error != null)
                  ErrorView(error: _error!, onRetry: _load)
                else if (access == null)
                  // Static placeholder: the state arrives within a moment.
                  const GlassCard(radius: 20, child: SizedBox(height: 64))
                else
                  ..._content(t, access),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations t, FaceAccess access) {
    final draft = _draft;
    if (draft != null) {
      return [
        GlassSectionHeader(t.facePreviewTitle),
        _PhotoFrame(key: const Key('face-draft'), bytes: draft),
        const SizedBox(height: 14),
        _ConsentRow(value: _consent, onChanged: (v) => setState(() => _consent = v)),
        const SizedBox(height: 14),
        GradientPillButton(
          key: const Key('face-send'),
          label: t.faceSend,
          icon: Icons.arrow_upward_rounded,
          height: 54,
          loading: _busy,
          onPressed: _consent ? _send : null,
        ),
        const SizedBox(height: 10),
        GlassPillButton(
          key: const Key('face-retake'),
          label: t.faceRetake,
          icon: Icons.refresh_rounded,
          onPressed: _busy ? null : () => setState(() => _draft = null),
        ),
      ];
    }

    final showTips = access.status == FaceAccessStatus.none || access.status == FaceAccessStatus.rejected;
    return [
      _StatusCard(access: access),
      if (_photo != null) ...[const SizedBox(height: 16), _PhotoFrame(key: const Key('face-photo'), bytes: _photo!)],
      if (showTips) ...[
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.faceTipsTitle),
        GlassList(
          dividerIndent: 56,
          children: [
            _TipRow(icon: Icons.face_rounded, text: t.faceTipFront),
            _TipRow(icon: Icons.visibility_off_outlined, text: t.faceTipNoAccessories),
            _TipRow(icon: Icons.wb_sunny_outlined, text: t.faceTipLight),
          ],
        ),
      ],
      if (!access.hasPhoto) ...[
        const SizedBox(height: 16),
        _ConsentRow(value: _consent, onChanged: (v) => setState(() => _consent = v)),
      ],
      const SizedBox(height: 16),
      GradientPillButton(
        key: const Key('face-camera'),
        label: access.hasPhoto && access.status != FaceAccessStatus.rejected ? t.faceReplace : t.faceTakeSelfie,
        icon: Icons.photo_camera_front_rounded,
        height: 54,
        onPressed: _busy ? null : () => _pick(FacePhotoSource.camera),
      ),
      const SizedBox(height: 10),
      GlassPillButton(
        key: const Key('face-gallery'),
        label: t.facePickGallery,
        icon: Icons.photo_library_outlined,
        onPressed: _busy ? null : () => _pick(FacePhotoSource.gallery),
      ),
      if (access.hasPhoto) ...[
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            key: const Key('face-delete'),
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Brand.redText, minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(t.faceDelete),
          ),
        ),
      ],
    ];
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.access});
  final FaceAccess access;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final from = access.accessFrom, to = access.accessTo;
    final period = from != null && to != null ? t.faceAccessPeriod(fmt.date(from), fmt.date(to)) : null;
    final (icon, color, iconColor, title, body) = switch (access.status) {
      FaceAccessStatus.none => (
        Icons.face_retouching_natural_rounded,
        Brand.blue,
        Brand.blueIcon,
        t.faceStatusNone,
        t.faceStatusNoneHint,
      ),
      FaceAccessStatus.waiting => (
        Icons.hourglass_top_rounded,
        Brand.warning,
        Brand.warningIcon,
        t.faceShortWaiting,
        access.hasAccess ? t.faceStatusWaitingNoTerminal : t.faceStatusWaitingNoAccess,
      ),
      FaceAccessStatus.pending => (
        Icons.sync_rounded,
        Brand.accent,
        Brand.clock,
        t.faceStatusPending,
        t.faceStatusPendingHint,
      ),
      FaceAccessStatus.ready => (Icons.verified_rounded, Brand.success, Brand.successText, t.faceStatusReady, period),
      FaceAccessStatus.rejected => (Icons.error_outline_rounded, Brand.red, Brand.redText, t.faceStatusRejected, null),
    };
    return GlassCard(
      key: Key('face-status-${access.status.name}'),
      radius: 20,
      borderColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconPlate(icon: icon, color: color, iconColor: iconColor, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(color: Brand.textSecondary, fontSize: 13, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo in a portrait frame, as the terminal will see it.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Brand.radiusHero),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05)),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(Icons.face_rounded, color: Brand.textTertiary, size: 64),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return GlassCard(
      key: const Key('face-consent'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: Brand.accent,
            side: BorderSide(color: Brand.textSecondary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(t.faceConsent, style: const TextStyle(color: Brand.textPrimary, fontSize: 13, height: 1.3)),
                // What the photo is used for, where it is kept and how to withdraw: the privacy policy.
                TextButton(
                  key: const Key('face-privacy-link'),
                  onPressed: () => openPrivacyPolicy(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                    foregroundColor: Brand.clock,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text(t.faceDataMore),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
        Icon(icon, color: Brand.clock, size: 22),
        const SizedBox(width: 18),
        Expanded(
          child: Text(text, style: const TextStyle(color: Brand.textPrimary, fontSize: 14)),
        ),
      ],
    ),
  );
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('face-delete-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.faceDeleteTitle,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(t.faceDeleteBody, style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35)),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('face-delete-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Brand.red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          child: Text(t.faceDelete),
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
