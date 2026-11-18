import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';

/// Rounded surface card used across the app.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.gradient});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: gradient == null ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: gradient == null
            ? null
            : BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(22)),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = AppColors.accent});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2.5)),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return MessageView(
      icon: Icons.cloud_off_rounded,
      title: errorText(t, error),
      action: OutlinedButton(onPressed: onRetry, child: Text(t.retry)),
    );
  }
}

/// Maps backend error codes to localized messages.
String errorText(AppLocalizations t, Object error) {
  if (error is! ApiException) return t.errorGeneric;
  return switch (error.code) {
    'network' => t.errorNetwork,
    'invalid_credentials' => t.errorInvalidCredentials,
    'account_locked' => t.errorAccountLocked,
    'account_blocked' => t.errorAccountBlocked,
    'phone_taken' => t.errorPhoneTaken,
    'duplicate_request' => t.errorDuplicateRequest,
    'trainer_not_accepting' => t.errorTrainerNotAccepting,
    'already_assigned' => t.errorAlreadyAssigned,
    'request_not_pending' || 'membership_request_not_pending' => t.errorRequestNotPending,
    'membership_request_pending' => t.requestAlreadyPending,
    'session_overlap' => t.errorSessionOverlap,
    'start_in_past' => t.errorStartInPast,
    'session_not_scheduled' => t.errorSessionNotScheduled,
    'session_not_started' => t.errorSessionNotStarted,
    'not_found' => t.errorNotFound,
    'admin_use_web' => t.errorAdminUseWeb,
    'invalid_password' => t.errorInvalidPassword,
    'password_unchanged' => t.errorPasswordUnchanged,
    'password_change_required' => t.errorPasswordChangeRequired,
    'freeze_too_long' => t.errorFreezeTooLong,
    'freeze_not_available' => t.freezeNotAvailable,
    'freeze_limit_reached' => t.freezeLimitReached,
    'freeze_exists' => t.errorFreezeExists,
    'freeze_in_past' => t.errorFreezeInPast,
    'freeze_outside_membership' => t.errorFreezeOutside,
    'trainer_assigned' => t.errorTrainerAssigned,
    'face_consent_required' => t.faceConsentRequired,
    'face_invalid_format' => t.errorFaceFormat,
    'face_too_large' => t.errorFaceTooLarge,
    'face_bad_size' => t.errorFaceBadSize,
    // AI Food Scanner, food diary and nutrition analytics.
    'ai_not_configured' => t.errAiNotConfigured,
    'ai_consent_required' => t.errAiConsentRequired,
    'ai_unavailable' => t.errAiUnavailable,
    'ai_rate_limited' => t.errAiRateLimited,
    'ai_quota_exceeded' => t.errAiQuotaExceeded,
    'ai_budget_exceeded' => t.errAiBudgetExceeded,
    'ai_invalid_response' => t.errAiInvalidResponse,
    'ai_refused' => t.errAiRefused,
    'photo_invalid_format' => t.errPhotoFormat,
    'photo_too_large' => t.errPhotoTooLarge,
    'photo_bad_size' => t.errPhotoBadSize,
    'barcode_not_found' => t.errBarcodeNotFound,
    'barcode_invalid' => t.errBarcodeInvalid,
    'food_db_unavailable' => t.errFoodDbUnavailable,
    'item_without_nutrition' => t.errItemWithoutNutrition,
    'nutrition_profile_incomplete' => t.errProfileIncomplete,
    'scan_in_progress' => t.errScanInProgress,
    'validation_failed' => t.errValidation,
    _ => t.errorGeneric,
  };
}

void showSnack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Opens [uri] in its app or the browser; a snack bar says so if nothing can open it.
Future<void> openExternalLink(BuildContext context, Uri uri) async {
  final failed = AppLocalizations.of(context).openLinkFailed;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(failed)));
}

/// The club's privacy policy in the browser.
Future<void> openPrivacyPolicy(BuildContext context) =>
    openExternalLink(context, Uri.parse(AppConfig.privacyPolicyUrl));

/// Loads data with loading / error / data states and pull-to-refresh support.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder, this.loading});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  /// Placeholder while the first load runs (default: a spinner).
  final WidgetBuilder? loading;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();
  // Data may be stale after the app was in the background (e.g. a trainer accepted a request meanwhile).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _reload);

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final f = widget.load();
    // Block body: an arrow would return the Future from setState, which Flutter rejects.
    setState(() {
      _future = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      final Widget child;
      if (snap.hasError) {
        child = ErrorView(key: const ValueKey('error'), error: snap.error!, onRetry: _reload);
      } else if (!snap.hasData) {
        child = KeyedSubtree(
          key: const ValueKey('loading'),
          child: widget.loading?.call(context) ?? const LoadingView(),
        );
      } else {
        child = KeyedSubtree(key: const ValueKey('data'), child: widget.builder(context, snap.data as T, _reload));
      }
      return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: child);
    },
  );
}

/// Renders a paged list: the first page plus pages fetched on demand with a "Show more" button.
/// The full history is never loaded at once. Offset pages shift when new rows appear between requests,
/// so items already shown are skipped by id. Give it a key tied to [first] so a reload starts over.
class LoadMoreList<T> extends StatefulWidget {
  const LoadMoreList({
    super.key,
    required this.first,
    required this.loadPage,
    required this.idOf,
    required this.itemBuilder,
  });
  final Paged<T> first;
  final Future<Paged<T>> Function(int page) loadPage;
  final String Function(T item) idOf;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  State<LoadMoreList<T>> createState() => _LoadMoreListState<T>();
}

class _LoadMoreListState<T> extends State<LoadMoreList<T>> {
  late final List<T> _items = [...widget.first.items];
  late final Set<String> _ids = _items.map(widget.idOf).toSet();
  late int _page = widget.first.page;
  late bool _hasMore = widget.first.page < widget.first.totalPages;
  bool _busy = false;
  Object? _error;

  Future<void> _more() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await widget.loadPage(_page + 1);
      if (!mounted) return;
      setState(() {
        _page = next.page;
        _hasMore = next.items.isNotEmpty && next.page < next.totalPages;
        for (final item in next.items) {
          if (_ids.add(widget.idOf(item))) _items.add(item);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in _items) widget.itemBuilder(context, item),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              errorText(t, _error!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        if (_hasMore)
          Center(
            child: _busy
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                : TextButton(
                    key: const Key('load-more'),
                    onPressed: _more,
                    child: Text(_error == null ? t.loadMore : t.retry),
                  ),
          ),
      ],
    );
  }
}
