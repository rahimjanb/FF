import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Opens the QR pass for the club desk. [membership] (when known) warns that a scan will be refused.
Future<void> showQrPass(BuildContext context, {Membership? membership}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF111116),
  showDragHandle: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.radiusHero))),
  builder: (_) => QrPassSheet(membership: membership),
);

/// Signed code that changes every 30 seconds. The pass is polled while open: a new visit after opening means the
/// desk accepted the scan, and the sheet says so.
class QrPassSheet extends StatefulWidget {
  const QrPassSheet({super.key, this.membership});
  final Membership? membership;

  static const pollEvery = Duration(seconds: 3);

  @override
  State<QrPassSheet> createState() => _QrPassSheetState();
}

class _QrPassSheetState extends State<QrPassSheet> {
  QrPass? _pass;
  bool _failed = false;
  bool _entered = false;
  DateTime? _baseline;
  bool _baselineSet = false;
  DateTime _refreshAt = DateTime.now();
  Timer? _poll, _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(QrPassSheet.pollEvery, (_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_entered) return;
    try {
      final pass = await context.read<ClientRepository>().pass();
      if (!mounted) return;
      setState(() {
        _failed = false;
        _pass = pass;
        _refreshAt = DateTime.now().add(pass.refreshIn);
        if (!_baselineSet) {
          _baselineSet = true;
          _baseline = pass.lastVisitAt;
        } else if (pass.lastVisitAt != null && (_baseline == null || pass.lastVisitAt!.isAfter(_baseline!))) {
          _entered = true;
          HapticFeedback.heavyImpact();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = widget.membership;
    final warn = m != null && !m.isUsable;
    final seconds = _refreshAt.difference(DateTime.now()).inSeconds.clamp(0, 30) + 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Brand.sidePadding, 0, Brand.sidePadding, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _entered ? t.qrEntryRecorded : t.qrPassTitle,
              style: const TextStyle(color: Brand.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _entered ? t.qrEntryRecordedHint : t.qrPassHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Brand.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _entered
                  ? const _EnteredMark(key: ValueKey('entered'))
                  : _pass == null
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      height: 260,
                      child: Center(
                        child: _failed
                            ? _Offline(onRetry: _load)
                            : const CircularProgressIndicator(color: Brand.accent),
                      ),
                    )
                  : Container(
                      key: const ValueKey('qr'),
                      width: 260,
                      height: 260,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Brand.accent.withValues(alpha: 0.3), blurRadius: 30)],
                      ),
                      child: Semantics(
                        label: t.qrPassTitle,
                        image: true,
                        child: QrImageView(
                          key: const Key('qr-pass'),
                          data: _pass!.code,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          padding: EdgeInsets.zero,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0B1024)),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0B1024),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            if (!_entered && _pass != null) ...[
              if (_failed)
                Text(
                  t.qrOffline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.redText, fontSize: 13),
                )
              else
                Text(t.qrRefreshIn(seconds), style: const TextStyle(color: Brand.textPrimary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                t.qrScreenshotNote,
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.textTertiary, fontSize: 12),
              ),
            ],
            if (warn && !_entered) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Brand.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Brand.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Brand.warningIcon, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.qrNotUsable, style: const TextStyle(color: Brand.warningText, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GlassPillButton(
                label: t.close,
                icon: Icons.close_rounded,
                height: 50,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnteredMark extends StatelessWidget {
  const _EnteredMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    height: 260,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Brand.success.withValues(alpha: 0.15),
      border: Border.all(color: Brand.success.withValues(alpha: 0.4), width: 2),
    ),
    child: const Icon(Icons.check_rounded, color: Brand.successText, size: 120),
  );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, color: Brand.textTertiary, size: 40),
        const SizedBox(height: 12),
        Text(
          t.qrOffline,
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 12),
        GlassPillButton(label: t.retry, icon: Icons.refresh_rounded, height: 44, onPressed: onRetry),
      ],
    );
  }
}
