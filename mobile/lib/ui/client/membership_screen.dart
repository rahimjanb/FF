import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/membership_view.dart';
import 'face_access_screen.dart';
import 'qr_pass_sheet.dart';

class _MembershipData {
  _MembershipData(this.memberships, this.plans, this.requests, this.face);
  final List<Membership> memberships;
  final List<MembershipPlan> plans;
  final List<MembershipRequest> requests;

  /// Entry by face; null when it could not be loaded (the rest of the screen still works).
  final FaceAccess? face;

  MembershipRequest? get pending => requests.where((r) => r.status == MembershipRequestStatus.pending).firstOrNull;
}

/// Membership tab in the Liquid Glass style. Without a membership in effect or upcoming it offers the
/// plans on sale; otherwise it shows the pass, its terms and the membership history.
/// Buying and renewing send a request that the club completes after payment at the desk; the client freezes
/// the membership here (plans of six months or longer). Online payment and guest visits arrive in stage 2
/// and are shown disabled.
class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClientRepository>();
    Future<_MembershipData> load() async {
      final face = repo.faceAccess().then<FaceAccess?>((f) => f, onError: (Object _) => null);
      final r = await Future.wait<Object?>([repo.memberships(), repo.plans(), repo.membershipRequests(), face]);
      return _MembershipData(
        r[0] as List<Membership>,
        r[1] as List<MembershipPlan>,
        r[2] as List<MembershipRequest>,
        r[3] as FaceAccess?,
      );
    }

    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: AsyncView<_MembershipData>(
          load: load,
          loading: (_) => const _LoadingSkeleton(),
          builder: (context, d, reload) {
            const inEffect = [
              MembershipEffectiveStatus.active,
              MembershipEffectiveStatus.frozen,
              MembershipEffectiveStatus.exhausted,
            ];
            final upcoming =
                d.memberships.where((m) => m.effectiveStatus == MembershipEffectiveStatus.upcoming).toList()
                  ..sort((a, b) => a.startDate.compareTo(b.startDate));
            final shown =
                d.memberships.where((m) => inEffect.contains(m.effectiveStatus)).firstOrNull ?? upcoming.firstOrNull;
            return RefreshIndicator(
              color: Brand.accent,
              onRefresh: reload,
              child: shown == null
                  ? _PlansView(plans: d.plans, pending: d.pending, reload: reload)
                  : _ManageView(
                      membership: shown,
                      history: d.memberships.where((m) => m != shown).toList(),
                      plans: d.plans,
                      pending: d.pending,
                      face: d.face,
                      reload: reload,
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Bottom padding that keeps the last block above the floating tab bar.
double _listBottom(BuildContext context) => MediaQuery.paddingOf(context).bottom + Brand.tabBarReserve + 8;

void _snack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
}

void _showOnlinePaymentSoon(BuildContext context) => _snack(context, AppLocalizations.of(context).onlinePaymentSoon);

/// Sends a membership request; payment is taken at the club desk, where staff complete it.
Future<bool> _sendRequest(BuildContext context, MembershipPlan plan, MembershipRequestKind kind) async {
  final t = AppLocalizations.of(context);
  try {
    await context.read<ClientRepository>().requestMembership(plan.id, kind);
    if (context.mounted) _snack(context, t.requestSentPay);
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, errorText(t, e));
    return false;
  }
}

String _requestKindText(AppLocalizations t, MembershipRequestKind k) => switch (k) {
  MembershipRequestKind.first => t.requestKindNew,
  MembershipRequestKind.renew => t.requestKindRenew,
  MembershipRequestKind.change => t.requestKindChange,
};

/// The request waiting for payment at the desk, with a way to withdraw it.
class _PendingRequestCard extends StatefulWidget {
  const _PendingRequestCard({required this.request, required this.reload});
  final MembershipRequest request;
  final Future<void> Function() reload;

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await context.read<ClientRepository>().cancelMembershipRequest(widget.request.id);
      await widget.reload();
    } catch (e) {
      if (mounted) _snack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final r = widget.request;
    return GlassCard(
      key: const Key('pending-membership-request'),
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      borderColor: Brand.warning.withValues(alpha: 0.35),
      child: Row(
        children: [
          const IconPlate(
            icon: Icons.hourglass_top_rounded,
            color: Brand.warning,
            iconColor: Brand.warningIcon,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_requestKindText(t, r.kind)} «${r.plan.name}»',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(t.pendingPayAtDesk, style: const TextStyle(color: Brand.warningText, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            key: const Key('cancel-membership-request'),
            onPressed: _busy ? null : _cancel,
            style: TextButton.styleFrom(foregroundColor: Brand.textSecondary, minimumSize: const Size(44, 44)),
            child: Text(t.cancel),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle, this.button});
  final String subtitle;
  final Widget? button;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).membership,
              style: const TextStyle(
                color: Brand.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
          ],
        ),
      ),
      if (button != null) ...[
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 2), child: button),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Plans (no membership)

/// Months in a plan duration when it is a whole number of months (30, 90, 365 days...), otherwise null.
int? _months(int days) {
  final m = (days / 30).round();
  return m > 0 && (days - m * 30).abs() <= m * 1.5 ? m : null;
}

String _periodShort(AppLocalizations t, int days) {
  final m = _months(days);
  return m == null ? t.daysShortCount(days) : t.monthsShort(m);
}

String _periodLong(AppLocalizations t, int days) {
  final m = _months(days);
  return m == null ? t.daysCount(days) : t.monthsCount(m);
}

class _PlansView extends StatefulWidget {
  const _PlansView({required this.plans, required this.pending, required this.reload});
  final List<MembershipPlan> plans;
  final MembershipRequest? pending;
  final Future<void> Function() reload;

  @override
  State<_PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends State<_PlansView> {
  late final List<int> _durations = widget.plans.map((p) => p.durationDays).toSet().toList()..sort();
  int _durationIndex = 0;
  String? _selectedId;

  List<MembershipPlan> get _visible =>
      _durations.isEmpty ? const [] : widget.plans.where((p) => p.durationDays == _durations[_durationIndex]).toList();

  MembershipPlan? get _selected {
    final visible = _visible;
    return visible.where((p) => p.id == _selectedId).firstOrNull ?? visible.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final selected = _selected;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
      children: [
        _Header(
          subtitle: t.membershipPlansSubtitle,
          button: GlassCircleButton(
            icon: Icons.info_outline_rounded,
            tooltip: t.plansInfo,
            onTap: () => showGlassSheet<void>(context, builder: (_) => _InfoSheet(text: t.plansInfoText)),
          ),
        ),
        const SizedBox(height: Brand.sectionGap),
        GlassCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const IconPlate(icon: Icons.credit_card_rounded, color: Brand.red, iconColor: Brand.redText, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.noMembership,
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(t.noMembershipHint, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.pending != null) ...[
          const SizedBox(height: 12),
          _PendingRequestCard(request: widget.pending!, reload: widget.reload),
        ],
        if (widget.plans.isEmpty) ...[
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.price_change_outlined, color: Brand.textTertiary, size: 32),
                const SizedBox(height: 10),
                Text(
                  t.noPlansTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  t.noPlansHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Brand.textSecondary),
                ),
              ],
            ),
          ),
        ] else ...[
          if (_durations.length > 1) ...[
            const SizedBox(height: 16),
            GlassSegmentedControl(
              index: _durationIndex,
              onChanged: (i) => setState(() => _durationIndex = i),
              segments: [for (final days in _durations) _periodShort(t, days)],
            ),
          ],
          const SizedBox(height: 16),
          for (final p in _visible) ...[
            _PlanCard(
              plan: p,
              selected: p.id == selected?.id,
              fmt: fmt,
              onTap: () => setState(() => _selectedId = p.id),
            ),
            const SizedBox(height: 12),
          ],
          if (selected != null && widget.pending == null) ...[
            const SizedBox(height: 10),
            _CheckoutCard(plan: selected, fmt: fmt, reload: widget.reload),
          ],
        ],
      ],
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.plansInfo,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(color: Brand.textSecondary, fontSize: 15, height: 1.4)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: GradientPillButton(label: t.close, onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.fmt, required this.onTap});
  final MembershipPlan plan;
  final bool selected;
  final Fmt fmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (icon, color) = plan.isUnlimited
        ? (Icons.all_inclusive_rounded, Brand.accent)
        : (Icons.confirmation_number_outlined, Brand.trophy);
    final features = [
      plan.isUnlimited ? t.unlimitedVisits : t.visitsCount(plan.visitLimit ?? 0),
      t.validForPeriod(_periodLong(t, plan.durationDays)),
    ];
    final per = _months(plan.durationDays) == 1 ? t.perMonth : t.perPeriod(_periodShort(t, plan.durationDays));
    return Semantics(
      selected: selected,
      child: Stack(
        children: [
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            glow: selected,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconPlate(icon: icon, color: color, iconColor: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Brand.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.description?.trim().isNotEmpty == true
                                ? plan.description!.trim()
                                : (plan.isUnlimited ? t.unlimited : t.limitedVisits),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Radio(selected: selected),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      fmt.money(plan.price, t.currencySum),
                      style: const TextStyle(
                        color: Brand.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(per, style: TextStyle(color: Brand.textSecondary, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 12),
                for (final f in features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? Brand.accent.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: selected ? const Color(0xFF7FD6F2) : Brand.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              color: selected ? Brand.textPrimary : Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Accent outline of the selected plan, drawn above the glass stroke.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? Brand.accent.withValues(alpha: 0.7) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? Brand.accent : Colors.transparent,
      border: Border.all(color: selected ? Brand.accent : Colors.white.withValues(alpha: 0.3), width: 1.5),
    ),
    child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
  );
}

class _CheckoutCard extends StatefulWidget {
  const _CheckoutCard({required this.plan, required this.fmt, required this.reload});
  final MembershipPlan plan;
  final Fmt fmt;
  final Future<void> Function() reload;

  @override
  State<_CheckoutCard> createState() => _CheckoutCardState();
}

class _CheckoutCardState extends State<_CheckoutCard> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    final sent = await _sendRequest(context, widget.plan, MembershipRequestKind.first);
    if (mounted) setState(() => _busy = false);
    // Bought in the app: the turnstile can let the client in by face once the membership starts.
    if (sent && mounted) await offerFaceAfterRequest(context);
    if (sent) await widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final plan = widget.plan;
    final fmt = widget.fmt;
    return GlassCard(
      radius: Brand.radiusHero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Online payment is a stage 2 integration: the request is paid at the desk. The row states that; where
          // upcoming features are shown it also tells that online payment is coming.
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: AppConfig.showUpcoming ? () => _showOnlinePaymentSoon(context) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: Brand.textPrimary, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.paymentMethod, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            t.paymentAtDesk,
                            style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (AppConfig.showUpcoming) Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            t.totalFor(_periodLong(t, plan.durationDays)),
            style: TextStyle(color: Brand.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmt.money(plan.price, t.currencySum),
                    style: const TextStyle(
                      color: Brand.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GradientPillButton(
            key: const Key('checkout-plan'),
            label: t.checkoutPlan(plan.name),
            icon: Icons.arrow_forward_rounded,
            height: 54,
            loading: _busy,
            onPressed: _request,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.place_outlined, size: 15, color: Brand.textTertiary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(t.requestPayAtDeskHint, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Manage (membership in effect or upcoming)

/// Chip color, chip text color and label for the pass. Active with a week or less left is "expiring".
(Color, Color, String) _passStatus(AppLocalizations t, Membership m) => switch (m.effectiveStatus) {
  MembershipEffectiveStatus.active when m.daysLeft <= 7 => (Brand.flame, Brand.flame, t.statusExpiring),
  MembershipEffectiveStatus.active => (Brand.success, Brand.successText, t.statusActive),
  MembershipEffectiveStatus.frozen => (Brand.accent, Brand.clock, t.statusFrozen),
  MembershipEffectiveStatus.upcoming => (Brand.accent, Brand.clock, t.statusUpcoming),
  MembershipEffectiveStatus.exhausted => (Brand.flame, Brand.flame, t.statusExhausted),
  final s => (Brand.red, Brand.redText, membershipStatusText(t, s)),
};

Color _historyColor(MembershipEffectiveStatus s) => switch (s) {
  MembershipEffectiveStatus.active => Brand.successText,
  MembershipEffectiveStatus.upcoming || MembershipEffectiveStatus.frozen => Brand.clock,
  MembershipEffectiveStatus.exhausted => Brand.flame,
  MembershipEffectiveStatus.cancelled => Brand.redText,
  MembershipEffectiveStatus.expired => Brand.textTertiary,
};

/// Short display number derived from the membership id (there is no separate card number yet).
String _passNumber(String id) {
  final hex = id.replaceAll('-', '');
  final n = int.tryParse(hex.substring(hex.length > 6 ? hex.length - 6 : 0), radix: 16) ?? 0;
  return '№ ${(n % 1000000).toString().padLeft(6, '0')}';
}

class _ManageView extends StatelessWidget {
  const _ManageView({
    required this.membership,
    required this.history,
    required this.plans,
    required this.pending,
    required this.reload,
    this.face,
  });
  final Membership membership;
  final List<Membership> history;
  final List<MembershipPlan> plans;
  final MembershipRequest? pending;
  final FaceAccess? face;
  final Future<void> Function() reload;

  Future<void> _requestRenewal(BuildContext context) async {
    if (pending != null) {
      _snack(context, AppLocalizations.of(context).requestAlreadyPending);
      return;
    }
    final sent = await showGlassSheet<bool>(
      context,
      builder: (_) => _PlanRequestSheet(current: membership, plans: plans, reload: reload),
    );
    if (sent == true && context.mounted) await offerFaceAfterRequest(context, onReturn: reload);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final m = membership;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
      children: [
        _Header(
          subtitle: t.membershipManageSubtitle,
          // The menu lists documents and support, which are not published yet.
          button: AppConfig.showUpcoming
              ? GlassCircleButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: t.more,
                  onTap: () => showGlassSheet<void>(context, builder: (_) => const _MenuSheet()),
                )
              : null,
        ),
        const SizedBox(height: Brand.sectionGap),
        _PassCard(membership: m, fmt: fmt),
        if (m.hasFreeze) ...[const SizedBox(height: 12), _FreezeInfo(membership: m, fmt: fmt)],
        const SizedBox(height: 16),
        GradientPillButton(
          key: const Key('show-qr-pass'),
          label: t.showQrPass,
          icon: Icons.qr_code_2_rounded,
          height: 54,
          onPressed: () => showQrPass(context, membership: m),
        ),
        if (pending != null) ...[const SizedBox(height: 12), _PendingRequestCard(request: pending!, reload: reload)],
        const SizedBox(height: 12),
        FaceAccessTile(
          access: face,
          onTap: () async {
            await openFaceAccess(context);
            await reload();
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Changing the plan is not offered: a new plan is bought after the current one (renewal).
            for (final (i, (key, icon, color, label, onTap, badge))
                in <(String, IconData, Color, String, VoidCallback?, String?)>[
                  (
                    'action-freeze',
                    Icons.ac_unit_rounded,
                    Brand.clock,
                    t.actionFreeze,
                    () => showGlassSheet<void>(
                      context,
                      builder: (_) => _FreezeSheet(membership: m, fmt: fmt, reload: reload),
                    ),
                    // Freezes left, for plans that can be frozen at all.
                    m.freezesAllowed > 0 && !m.hasFreeze ? '${m.freezesLeft}/${m.freezesAllowed}' : null,
                  ),
                  (
                    'action-renew',
                    Icons.autorenew_rounded,
                    Brand.accent,
                    t.actionRenew,
                    () => _requestRenewal(context),
                    null,
                  ),
                  // Guest visits are a stage 2 feature.
                  if (AppConfig.showUpcoming)
                    ('action-guest', Icons.person_add_alt_rounded, Brand.purple, t.actionGuest, null, t.soon),
                ].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: GlassActionTile(
                  key: Key(key),
                  icon: icon,
                  color: color,
                  label: label,
                  onTap: onTap,
                  badge: badge,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Brand.sectionGap + 4),
        GlassSectionHeader(t.includedTitle),
        GlassList(
          dividerIndent: 64,
          children: [
            _TermRow(
              icon: m.isUnlimited ? Icons.all_inclusive_rounded : Icons.confirmation_number_outlined,
              color: Brand.blue,
              label: t.type,
              value: m.isUnlimited ? t.unlimited : t.limitedVisits,
            ),
            _TermRow(
              icon: Icons.login_rounded,
              color: Brand.purple,
              label: t.visits,
              value: m.visitLimit == null ? t.unlimited : t.usedOfLimit(m.visitsUsed, m.visitLimit!),
            ),
            _TermRow(
              icon: Icons.date_range_rounded,
              color: Brand.clock,
              label: t.period,
              value: _periodLong(t, m.totalDays),
            ),
            _TermRow(
              icon: Icons.event_rounded,
              color: Brand.trophy,
              label: t.startLabel,
              value: fmt.numericDate(m.startDate),
            ),
          ],
        ),
        const SizedBox(height: Brand.sectionGap + 4),
        GlassSectionHeader(t.membershipHistory),
        if (history.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Brand.textTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t.historyEmpty, style: TextStyle(color: Brand.textSecondary)),
                ),
              ],
            ),
          )
        else
          GlassList(
            dividerIndent: 68,
            children: [for (final h in history) _HistoryRow(membership: h, fmt: fmt)],
          ),
      ],
    );
  }
}

/// Current or planned freeze and the end date it moved to.
class _FreezeInfo extends StatelessWidget {
  const _FreezeInfo({required this.membership, required this.fmt});
  final Membership membership;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = membership;
    final from = fmt.numericDate(m.freezeStart!), to = fmt.numericDate(m.freezeEnd!);
    return GlassCard(
      key: const Key('freeze-info'),
      radius: 20,
      padding: const EdgeInsets.all(14),
      borderColor: Brand.clock.withValues(alpha: 0.3),
      child: Row(
        children: [
          const IconPlate(icon: Icons.ac_unit_rounded, color: Brand.clock, iconColor: Brand.clock, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.effectiveStatus == MembershipEffectiveStatus.frozen
                      ? t.frozenPeriod(from, to)
                      : t.freezePlanned(from, to),
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  t.extendedUntil(fmt.numericDate(m.endDate)),
                  style: TextStyle(color: Brand.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Freeze by the client: pick the first day and the length (up to [Membership.maxFreezeDays]); the end date moves
/// by the frozen days. With a current or planned freeze it offers to end or cancel it. Plans shorter than six
/// months cannot be frozen, and each membership has a limited number of freezes.
class _FreezeSheet extends StatefulWidget {
  const _FreezeSheet({required this.membership, required this.fmt, required this.reload});
  final Membership membership;
  final Fmt fmt;
  final Future<void> Function() reload;

  @override
  State<_FreezeSheet> createState() => _FreezeSheetState();
}

class _FreezeSheetState extends State<_FreezeSheet> {
  late final DateTime _today = widget.fmt.clubToday();
  late DateTime _start = _firstDay;
  int _days = 14;
  bool _busy = false;
  String? _error;

  Membership get _m => widget.membership;
  DateTime get _firstDay => _m.startDate.isAfter(_today) ? _m.startDate : _today;
  DateTime _plus(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: _firstDay,
      lastDate: _m.endDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: Brand.accent, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _run(Future<void> Function(ClientRepository repo) action, String done) async {
    if (_busy) return;
    final repo = context.read<ClientRepository>();
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(repo);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      _snack(context, done);
      navigator.pop();
      await widget.reload();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = widget.fmt;
    final m = _m;
    final header = Row(
      children: [
        const IconPlate(icon: Icons.ac_unit_rounded, color: Brand.clock, iconColor: Brand.clock),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            t.freezeTitle,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    final hint = TextStyle(color: Brand.textSecondary, fontSize: 15, height: 1.4);
    final error = _error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Brand.redText)),
          );

    final List<Widget> body;
    if (m.hasFreeze) {
      // A current freeze ends today; a planned one is cancelled.
      final started = !m.freezeStart!.isAfter(_today);
      body = [
        _FreezeInfo(membership: m, fmt: fmt),
        const SizedBox(height: 14),
        Text(t.unfreezeHint, style: hint),
        const SizedBox(height: 22),
        GradientPillButton(
          key: const Key('unfreeze'),
          label: started ? t.unfreezeAction : t.cancelFreezeAction,
          icon: Icons.wb_sunny_outlined,
          height: 52,
          loading: _busy,
          onPressed: () =>
              _run((repo) => repo.unfreezeMembership(m.id), started ? t.unfreezeDone : t.freezeCancelledDone),
        ),
      ];
    } else if (m.freezesAllowed == 0 || m.freezesLeft == 0) {
      final unavailable = m.freezesAllowed == 0;
      body = [
        GlassCard(
          key: const Key('freeze-unavailable'),
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconPlate(
                icon: Icons.lock_outline_rounded,
                color: Brand.textTertiary,
                iconColor: Brand.textSecondary,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unavailable ? t.freezeNotAvailable : t.freezeLimitReached,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(unavailable ? t.freezeNotAvailableHint : t.freezeLeft(0, m.freezesAllowed), style: hint),
        const SizedBox(height: 22),
        GradientPillButton(label: t.close, height: 52, onPressed: () => Navigator.of(context).pop()),
      ];
    } else {
      final end = _plus(_start, _days - 1);
      body = [
        StatusChip(label: t.freezeLeft(m.freezesLeft, m.freezesAllowed), color: Brand.clock, textColor: Brand.clock),
        const SizedBox(height: 12),
        Text(t.freezeRules(Membership.maxFreezeDays), style: hint),
        const SizedBox(height: 18),
        Text(t.freezeFrom, style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
        const SizedBox(height: 6),
        GlassCard(
          key: const Key('freeze-start'),
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: _busy ? null : _pickStart,
          child: Row(
            children: [
              const Icon(Icons.event_rounded, color: Brand.clock, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fmt.date(_start),
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(t.freezeDuration, style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
            ),
            Text(
              t.freezeDays(_days),
              style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Brand.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: Colors.white,
            overlayColor: Brand.accent.withValues(alpha: 0.15),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            key: const Key('freeze-days'),
            value: _days.toDouble(),
            min: 1,
            max: Membership.maxFreezeDays.toDouble(),
            divisions: Membership.maxFreezeDays - 1,
            label: t.freezeDays(_days),
            onChanged: _busy ? null : (v) => setState(() => _days = v.round()),
          ),
        ),
        GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fmt.numericDate(_start)} — ${fmt.numericDate(end)}',
                style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                t.freezeResult(fmt.date(_plus(m.endDate, _days))),
                key: const Key('freeze-result'),
                style: TextStyle(color: Brand.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GradientPillButton(
          key: const Key('freeze-submit'),
          label: '${t.freezeAction} · ${t.freezeDays(_days)}',
          icon: Icons.ac_unit_rounded,
          height: 52,
          loading: _busy,
          onPressed: () => _run(
            (repo) => repo.freezeMembership(m.id, _start, end),
            _start == _today ? t.freezeDone : t.freezePlannedDone,
          ),
        ),
      ];
    }

    return SingleChildScrollView(
      child: Column(
        key: const Key('freeze-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const SizedBox(height: 16), ...body, ?error],
      ),
    );
  }
}

/// Renewal with the current plan preselected; sends a request paid at the desk.
class _PlanRequestSheet extends StatefulWidget {
  const _PlanRequestSheet({required this.current, required this.plans, required this.reload});
  final Membership current;
  final List<MembershipPlan> plans;
  final Future<void> Function() reload;

  @override
  State<_PlanRequestSheet> createState() => _PlanRequestSheetState();
}

class _PlanRequestSheetState extends State<_PlanRequestSheet> {
  late final List<MembershipPlan> _plans = widget.plans;
  late String? _selected = (_plans.where((p) => p.id == widget.current.planId).firstOrNull ?? _plans.firstOrNull)?.id;
  bool _busy = false;

  Future<void> _send() async {
    final plan = _plans.firstWhere((p) => p.id == _selected);
    setState(() => _busy = true);
    final sent = await _sendRequest(context, plan, MembershipRequestKind.renew);
    if (!mounted) return;
    setState(() => _busy = false);
    if (sent) {
      Navigator.of(context).pop(true);
      await widget.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        key: const Key('plan-request-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.renewTitle,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(t.renewHint, style: TextStyle(color: Brand.textSecondary, fontSize: 14, height: 1.35)),
          const SizedBox(height: 16),
          if (_plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                t.noOtherPlans,
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.textSecondary),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: GlassList(
                  dividerIndent: 16,
                  children: [
                    for (final p in _plans)
                      InkWell(
                        key: Key('request-plan-${p.id}'),
                        onTap: () => setState(() => _selected = p.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Brand.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (p.id == widget.current.planId) ...[
                                          const SizedBox(width: 8),
                                          SoonBadge(t.currentPlanBadge),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_periodLong(t, p.durationDays)} · '
                                      '${p.isUnlimited ? t.unlimited : t.visitsCount(p.visitLimit ?? 0)}',
                                      style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                fmt.money(p.price, t.currencySum),
                                style: const TextStyle(
                                  color: Brand.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _Radio(selected: p.id == _selected),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          GradientPillButton(
            key: const Key('send-membership-request'),
            label: t.sendRequest,
            height: 52,
            loading: _busy,
            onPressed: _selected == null ? null : _send,
          ),
        ],
      ),
    );
  }
}

class _MenuSheet extends StatelessWidget {
  const _MenuSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Documents and support contacts are not published in the app yet.
    Widget row(IconData icon, String label) => ListTile(
      enabled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: Brand.textSecondary),
      title: Text(label, style: TextStyle(color: Brand.textSecondary, fontSize: 16)),
      trailing: SoonBadge(t.soon),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(Icons.description_outlined, t.menuContract),
        row(Icons.rule_rounded, t.menuRules),
        row(Icons.support_agent_rounded, t.menuSupport),
      ],
    );
  }
}

/// Wallet-style pass: dark blue gradient, glows, a decorative ring, status, progress and key facts.
class _PassCard extends StatelessWidget {
  const _PassCard({required this.membership, required this.fmt});
  final Membership membership;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = membership;
    final (chipColor, chipText, chipLabel) = _passStatus(t, m);
    final upcoming = m.effectiveStatus == MembershipEffectiveStatus.upcoming;
    final share = upcoming || m.totalDays == 0 ? 1.0 : m.daysLeft / m.totalDays;
    const radius = BorderRadius.all(Radius.circular(Brand.radiusHero));
    Widget fact(String label, String value, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: TextStyle(color: Brand.textTertiary, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Brand.accent.withValues(alpha: 0.19), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3346), Color(0xFF0B1024)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1, -1),
                      radius: 1.0,
                      colors: [Brand.accent.withValues(alpha: 0.35), Brand.accent.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1, 1),
                      radius: 0.9,
                      colors: [Brand.glowBlue.withValues(alpha: 0.4), Brand.glowBlue.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -70,
                top: -80,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 22),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          label: 'Fitness Formula',
                          image: true,
                          child: Image.asset('assets/images/ff-logo-white.png', height: 26, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: StatusChip(label: chipLabel, color: chipColor, textColor: chipText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      m.planName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Brand.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_periodLong(t, m.totalDays)} · '
                      '${m.visitLimit == null ? t.unlimited : t.visitsCount(m.visitLimit!)}',
                      style: TextStyle(color: Brand.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            upcoming ? t.startsOn(fmt.numericDate(m.startDate)) : t.daysLeft(m.daysLeft),
                            style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!upcoming)
                          Text(t.ofTotal(m.totalDays), style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PassProgress(value: share),
                    const SizedBox(height: 18),
                    Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: fact(t.validTillLabel, fmt.numericDate(m.endDate), CrossAxisAlignment.start)),
                        Expanded(child: fact(t.ownerLabel, m.clientName.split(' ').first, CrossAxisAlignment.start)),
                        fact(t.numberLabel, _passNumber(m.id), CrossAxisAlignment.end),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassProgress extends StatelessWidget {
  const _PassProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.12))),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            widthFactor: value.clamp(0, 1),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2BBBE8), Color(0xFF5AD2F4)]),
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        IconPlate(icon: icon, color: color, iconColor: color, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: const TextStyle(color: Brand.textPrimary, fontSize: 15)),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(color: Brand.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.membership, required this.fmt});
  final Membership membership;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = membership;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.card_membership_rounded, size: 19, color: Brand.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.numericDate(m.startDate)} — ${fmt.numericDate(m.endDate)}',
                  style: TextStyle(color: Brand.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            membershipStatusText(t, m.effectiveStatus),
            style: TextStyle(color: _historyColor(m.effectiveStatus), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
    children: const [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassSkeleton(height: 34, width: 190, radius: 10),
                SizedBox(height: 8),
                GlassSkeleton(height: 16, width: 220, radius: 8),
              ],
            ),
          ),
          GlassSkeleton(height: 44, width: 44, radius: 22),
        ],
      ),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 290, radius: Brand.radiusHero),
      SizedBox(height: 16),
      GlassSkeleton(height: 54, radius: 27),
      SizedBox(height: 16),
      GlassSkeleton(height: 96, radius: 20),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 220, radius: Brand.radiusCard),
    ],
  );
}
