import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'nutrition_format.dart';

/// Before a photo, a label, a report or a consultant question goes to the AI service, the client agrees to it
/// (App Store 5.1.2(i): personal data shared with a third-party AI needs explicit permission). Returns the profile
/// with the consent, or null when the client declined or it could not be saved.
Future<NutritionProfile?> ensureAiConsent(BuildContext context, NutritionProfile? profile) async {
  if (profile != null && profile.hasAiConsent) return profile;
  return showAiConsentSheet(context, provider: profile?.aiProvider);
}

Future<NutritionProfile?> showAiConsentSheet(BuildContext context, {String? provider}) =>
    showGlassSheet<NutritionProfile>(context, builder: (_) => _AiConsentView(provider: provider));

/// Runs an AI request; when the server answers that consent is missing (it was revoked on another device), asks
/// for it and retries once. Other errors are rethrown.
Future<T?> withAiConsent<T>(BuildContext context, NutritionProfile? profile, Future<T> Function() call) async {
  final agreed = await ensureAiConsent(context, profile);
  if (agreed == null) return null;
  try {
    return await call();
  } catch (e) {
    if (!isConsentError(e) || !context.mounted) rethrow;
    final again = await showAiConsentSheet(context, provider: agreed.aiProvider);
    if (again == null) return null;
    return call();
  }
}

class _AiConsentView extends StatefulWidget {
  const _AiConsentView({this.provider});
  final String? provider;

  @override
  State<_AiConsentView> createState() => _AiConsentViewState();
}

class _AiConsentViewState extends State<_AiConsentView> {
  bool _busy = false;

  Future<void> _agree() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final profile = await context.read<NutritionRepository>().giveAiConsent();
      if (mounted) Navigator.of(context).pop(profile);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(t, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final provider = widget.provider ?? t.aiProviderUnknown;
    return SingleChildScrollView(
      child: Column(
        key: const Key('ai-consent-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: IconPlate(icon: Icons.auto_awesome_rounded, color: Brand.accent, iconColor: Brand.clock, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            t.aiConsentTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            t.aiConsentBody(provider),
            style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          _Point(icon: Icons.photo_camera_outlined, text: t.aiConsentPointPhoto),
          _Point(icon: Icons.person_off_outlined, text: t.aiConsentPointNoName),
          _Point(icon: Icons.delete_outline_rounded, text: t.aiConsentPointDelete),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('ai-consent-policy'),
              onPressed: () => openPrivacyPolicy(context),
              style: TextButton.styleFrom(foregroundColor: Brand.accent, padding: EdgeInsets.zero),
              child: Text(t.privacyPolicy),
            ),
          ),
          const SizedBox(height: 12),
          GradientPillButton(
            key: const Key('ai-consent-agree'),
            label: t.aiConsentAgree,
            icon: Icons.check_rounded,
            height: 52,
            loading: _busy,
            onPressed: _agree,
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('ai-consent-decline'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: Brand.textSecondary, minimumSize: const Size(44, 44)),
            child: Text(t.aiConsentDecline),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Brand.clock),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Brand.textPrimary, fontSize: 14, height: 1.3)),
        ),
      ],
    ),
  );
}
