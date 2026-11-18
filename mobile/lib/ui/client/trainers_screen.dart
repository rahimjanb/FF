import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

class _TrainersData {
  _TrainersData(this.trainers, this.requests, this.profile);
  final List<Trainer> trainers;
  final List<TrainerRequest> requests;
  final ClientProfile profile;

  String? get myTrainerId => profile.assignedTrainer?.id;

  /// The directory has no contacts; the client's own trainer comes with them in the profile.
  TrainerContacts get myContacts => profile.assignedTrainer?.contacts ?? TrainerContacts.none;

  /// Training on their own: only while no trainer is assigned.
  bool get withoutTrainer => profile.withoutTrainer && myTrainerId == null;

  Trainer? get mine => trainers.where((tr) => tr.id == myTrainerId).firstOrNull;

  TrainerRequest? pendingFor(String trainerId) =>
      requests.where((r) => r.trainer.id == trainerId && r.status == TrainerRequestStatus.pending).firstOrNull;

  TrainerRequest? get anyPending => requests.where((r) => r.status == TrainerRequestStatus.pending).firstOrNull;
}

/// Club trainers in the Liquid Glass style: own trainer on top, then a searchable list. Tap opens the profile,
/// where the client sends a request to choose the trainer.
class TrainersScreen extends StatelessWidget {
  const TrainersScreen({super.key, this.onNavigate});
  final void Function(int tab)? onNavigate;

  static const workoutsTab = 3;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClientRepository>();
    Future<_TrainersData> load() async {
      final results = await Future.wait([repo.trainers(), repo.trainerRequests(), repo.profile()]);
      return _TrainersData(
        results[0] as List<Trainer>,
        results[1] as List<TrainerRequest>,
        results[2] as ClientProfile,
      );
    }

    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: AsyncView<_TrainersData>(
          load: load,
          loading: (_) => const _LoadingSkeleton(),
          builder: (context, data, reload) => RefreshIndicator(
            color: Brand.accent,
            onRefresh: reload,
            child: _TrainersContent(data: data, reload: reload, onNavigate: onNavigate),
          ),
        ),
      ),
    );
  }
}

/// The design also shows a rating, a clients count, direction chips and «Свободен сегодня»; the API has none of
/// them, so those elements are hidden rather than mocked. Only the chat has no backend yet; its button is shown only
/// when [AppConfig.showUpcoming].
abstract final class _Stub {
  static void chat(BuildContext context) => _snack(context, AppLocalizations.of(context).chatSoon);
}

double _listBottom(BuildContext context) => MediaQuery.paddingOf(context).bottom + Brand.tabBarReserve + 8;

void _snack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
}

String _initials(Trainer tr) =>
    [tr.firstName, tr.lastName].where((s) => s.isNotEmpty).map((s) => s.characters.first.toUpperCase()).join();

/// Trainer profile as a bottom sheet. Resolves to `true` when a request was sent or cancelled, also when the
/// sheet is swiped away from the «request sent» screen. [contacts]: Telegram / Instagram the client may see
/// (own trainer or a pending request); by default those of [trainer].
Future<bool> showTrainerSheet(
  BuildContext context, {
  required Trainer trainer,
  required bool isMine,
  TrainerRequest? pending,
  TrainerContacts? contacts,
}) async {
  var changed = false;
  final popped = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF111116),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.radiusHero))),
    builder: (_) => TrainerSheet(
      trainer: trainer,
      isMine: isMine,
      pending: pending,
      contacts: contacts,
      repo: context.read<ClientRepository>(),
      onChanged: () => changed = true,
    ),
  );
  return changed || popped == true;
}

/// Opens a trainer's Telegram or Instagram in the app or the browser.
Future<void> openContact(BuildContext context, Uri uri) => openExternalLink(context, uri);

enum _Sort { name, experience }

class _TrainersContent extends StatefulWidget {
  const _TrainersContent({required this.data, required this.reload, required this.onNavigate});
  final _TrainersData data;
  final Future<void> Function() reload;
  final void Function(int tab)? onNavigate;

  @override
  State<_TrainersContent> createState() => _TrainersContentState();
}

class _TrainersContentState extends State<_TrainersContent> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _Sort _sort = _Sort.name;
  bool _onlyAccepting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    setState(() {}); // clear button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = text.trim().toLowerCase());
    });
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _onlyAccepting = false;
    });
  }

  Future<void> _open(Trainer tr) async {
    HapticFeedback.selectionClick();
    final mine = tr.id == widget.data.myTrainerId;
    final pending = widget.data.pendingFor(tr.id);
    final changed = await showTrainerSheet(
      context,
      trainer: tr,
      isMine: mine,
      pending: pending,
      contacts: mine ? widget.data.myContacts : pending?.trainerContacts,
    );
    if (changed) await widget.reload();
  }

  /// «Без тренера»: confirm, withdraw a pending request, remember the choice.
  Future<void> _chooseWithoutTrainer() async {
    final t = AppLocalizations.of(context);
    final repo = context.read<ClientRepository>();
    final pending = widget.data.anyPending;
    HapticFeedback.selectionClick();
    final confirmed = await showGlassSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        key: const Key('without-trainer-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconPlate(icon: Icons.directions_run_rounded, color: Brand.accent, iconColor: Brand.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  t.withoutTrainerOption,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.withoutTrainerOptionHint, style: TextStyle(color: Brand.textSecondary, fontSize: 15, height: 1.4)),
          if (pending != null) ...[
            const SizedBox(height: 10),
            Text(
              t.withoutTrainerCancelsRequest(pending.trainer.fullName),
              style: const TextStyle(color: Brand.warningText, fontSize: 14, height: 1.35),
            ),
          ],
          const SizedBox(height: 22),
          GradientPillButton(
            key: const Key('without-trainer-confirm'),
            label: t.withoutTrainerConfirm,
            icon: Icons.check_rounded,
            height: 52,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 10),
          GlassPillButton(
            label: t.cancel,
            icon: Icons.close_rounded,
            height: 48,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await repo.trainWithoutTrainer();
      if (!mounted) return;
      _snack(context, t.withoutTrainerDone);
      await widget.reload();
    } catch (e) {
      if (mounted) _snack(context, errorText(t, e));
    }
  }

  String _sortLabel(AppLocalizations t, _Sort s) => switch (s) {
    _Sort.name => t.sortByName,
    _Sort.experience => t.sortByExperience,
  };

  void _openFilters() {
    final t = AppLocalizations.of(context);
    showGlassSheet<void>(
      context,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          return Column(
            key: const Key('trainer-filters'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.filters,
                style: const TextStyle(
                  color: Brand.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 18),
              Text(t.sortTitle, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              GlassSegmentedControl(
                segments: [for (final s in _Sort.values) _sortLabel(t, s)],
                index: _sort.index,
                onChanged: (i) => update(() => _sort = _Sort.values[i]),
              ),
              const SizedBox(height: 14),
              GlassCard(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t.onlyAccepting, style: const TextStyle(color: Brand.textPrimary, fontSize: 15)),
                    ),
                    Switch.adaptive(
                      key: const Key('only-accepting'),
                      value: _onlyAccepting,
                      activeTrackColor: Brand.accent,
                      onChanged: (v) => update(() => _onlyAccepting = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = widget.data;
    final mine = d.mine;
    final others = d.trainers.where((tr) => tr.id != d.myTrainerId).toList();
    final filtersActive = _query.isNotEmpty || _onlyAccepting;
    final shown =
        others
            .where((tr) => !_onlyAccepting || tr.isAcceptingClients)
            .where(
              (tr) =>
                  _query.isEmpty ||
                  tr.fullName.toLowerCase().contains(_query) ||
                  (tr.specialization?.toLowerCase().contains(_query) ?? false),
            )
            .toList()
          ..sort(
            (a, b) => switch (_sort) {
              _Sort.name => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
              _Sort.experience => (b.experienceYears ?? -1).compareTo(a.experienceYears ?? -1),
            },
          );
    // Trainers with a pending request first: in a long list they would otherwise be far below the fold.
    final ordered = [
      ...shown.where((tr) => d.pendingFor(tr.id) != null),
      ...shown.where((tr) => d.pendingFor(tr.id) == null),
    ];
    final pending = d.anyPending;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
      children: [
        Text(
          t.trainersTitle,
          style: const TextStyle(
            color: Brand.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(t.trainersCount(d.trainers.length), style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
        const SizedBox(height: 16),
        _SearchField(
          controller: _search,
          onChanged: _onSearch,
          onClear: () {
            _debounce?.cancel();
            _search.clear();
            setState(() => _query = '');
          },
          onFilters: _openFilters,
          filtersActive: _onlyAccepting || _sort != _Sort.name,
        ),
        const SizedBox(height: Brand.sectionGap),
        if (mine != null)
          _MyTrainerCard(
            trainer: mine,
            onOpen: () => _open(mine),
            onChat: AppConfig.showUpcoming ? () => _Stub.chat(context) : null,
            onBook: widget.onNavigate == null ? null : () => widget.onNavigate!(TrainersScreen.workoutsTab),
          )
        else if (d.withoutTrainer && pending == null)
          const _WithoutTrainerCard(selected: true)
        else ...[
          _ChooseHint(
            text: pending == null ? t.chooseYourTrainerHint : t.pendingRequestTo(pending.trainer.fullName),
            pending: pending != null,
          ),
          const SizedBox(height: 10),
          _WithoutTrainerCard(selected: false, onTap: _chooseWithoutTrainer),
        ],
        const SizedBox(height: Brand.sectionGap),
        if (d.trainers.isEmpty)
          _MessageCard(icon: Icons.groups_outlined, title: t.noTrainers)
        else if (others.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.allTrainers,
                    style: const TextStyle(
                      color: Brand.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                PopupMenuButton<_Sort>(
                  key: const Key('trainer-sort'),
                  initialValue: _sort,
                  color: const Color(0xFF1C1C21),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _sort = s);
                  },
                  itemBuilder: (_) => [
                    for (final s in _Sort.values)
                      PopupMenuItem(
                        value: s,
                        child: Text(
                          _sortLabel(t, s),
                          style: TextStyle(color: s == _sort ? Brand.accent : Brand.textPrimary),
                        ),
                      ),
                  ],
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortLabel(t, _sort),
                          style: const TextStyle(color: Brand.accent, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded, color: Brand.accent, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (ordered.isEmpty)
            _MessageCard(
              key: const Key('nothing-found'),
              icon: Icons.search_rounded,
              title: t.nothingFound,
              action: filtersActive
                  ? GlassPillButton(label: t.resetFilters, icon: Icons.refresh_rounded, height: 44, onPressed: _reset)
                  : null,
            )
          else
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < ordered.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    _TrainerRow(
                      trainer: ordered[i],
                      pending: d.pendingFor(ordered[i].id) != null,
                      onTap: () => _open(ordered[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
        if (d.requests.isNotEmpty) ...[
          const SizedBox(height: Brand.sectionGap + 6),
          GlassSectionHeader(t.myRequests),
          GlassList(children: [for (final r in d.requests) _RequestRow(request: r)]),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onFilters,
    required this.filtersActive,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear, onFilters;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Brand.textTertiary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('trainer-search'),
                controller: controller,
                onChanged: onChanged,
                cursorColor: Brand.accent,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 15, letterSpacing: 0),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: t.searchTrainersHint,
                  hintMaxLines: 1,
                  hintStyle: TextStyle(color: Brand.textTertiary, fontSize: 15, letterSpacing: 0),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                key: const Key('trainer-search-clear'),
                tooltip: t.clearSearch,
                onPressed: onClear,
                icon: Icon(Icons.cancel_rounded, color: Brand.textTertiary, size: 20),
              ),
            Tooltip(
              message: t.filters,
              child: InkResponse(
                key: const Key('trainer-filters-button'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFilters();
                },
                radius: 22,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filtersActive
                            ? Brand.accent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: filtersActive ? Brand.accent : Brand.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyTrainerCard extends StatelessWidget {
  const _MyTrainerCard({required this.trainer, required this.onOpen, required this.onChat, required this.onBook});
  final Trainer trainer;
  final VoidCallback onOpen;

  /// Null hides the button; with neither button the card has no button row.
  final VoidCallback? onChat, onBook;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tr = trainer;
    return PressScale(
      child: GlassCard(
        key: const Key('my-trainer'),
        radius: Brand.radiusHero,
        padding: const EdgeInsets.all(18),
        glow: true,
        borderColor: Brand.accent.withValues(alpha: 0.4),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GlassRingAvatar(size: 76, ring: 3, photoUrl: tr.photoUrl, initials: _initials(tr)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Brand.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Brand.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_outlined, size: 13, color: Brand.accent),
                            const SizedBox(width: 4),
                            Text(
                              t.currentTrainerBadge,
                              style: const TextStyle(color: Brand.accent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Brand.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (tr.specialization != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          tr.specialization!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Brand.textSecondary, fontSize: 13, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Only the experience is available from the API; rating and clients count are not shown.
            if (tr.experienceYears != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.workspace_premium_outlined, size: 17, color: Brand.clock),
                        const SizedBox(width: 6),
                        Text(
                          t.yearsShort(tr.experienceYears!),
                          style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(t.experienceLabel, style: TextStyle(color: Brand.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
            ],
            if (onChat != null || onBook != null) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final book = onBook == null
                      ? null
                      : GradientPillButton(
                          key: const Key('my-trainer-book'),
                          label: t.bookWithTrainer,
                          icon: Icons.edit_calendar_outlined,
                          onPressed: onBook!,
                        );
                  if (onChat == null) return book!;
                  final chat = GlassPillButton(
                    key: const Key('my-trainer-chat'),
                    label: t.writeToTrainer,
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: onChat,
                  );
                  if (book == null) return chat;
                  // «Написать» keeps its natural width and «Записаться» takes the rest; stacked on narrow screens.
                  if (c.maxWidth < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [chat, const SizedBox(height: 10), book],
                    );
                  }
                  return Row(
                    children: [
                      IntrinsicWidth(child: chat),
                      const SizedBox(width: 10),
                      Expanded(child: book),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChooseHint extends StatelessWidget {
  const _ChooseHint({required this.text, required this.pending});
  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const Key('choose-trainer-hint'),
    radius: 20,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        pending
            ? const IconPlate(
                icon: Icons.hourglass_top_rounded,
                color: Brand.warning,
                iconColor: Brand.warningIcon,
                size: 40,
              )
            : const IconPlate(
                icon: Icons.person_search_rounded,
                color: Brand.accent,
                iconColor: Brand.accent,
                size: 40,
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Brand.textPrimary, fontSize: 14, height: 1.35)),
        ),
      ],
    ),
  );
}

/// The «Без тренера» choice: an option to tap, or the current state once chosen.
class _WithoutTrainerCard extends StatelessWidget {
  const _WithoutTrainerCard({required this.selected, this.onTap});
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return GlassCard(
      key: Key(selected ? 'without-trainer-selected' : 'without-trainer-option'),
      radius: 20,
      padding: const EdgeInsets.all(14),
      borderColor: selected ? Brand.accent.withValues(alpha: 0.45) : null,
      onTap: onTap,
      child: Row(
        children: [
          const IconPlate(icon: Icons.directions_run_rounded, color: Brand.accent, iconColor: Brand.accent, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected ? t.withoutTrainerSelected : t.withoutTrainerOption,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  selected ? t.withoutTrainerSelectedHint : t.withoutTrainerOptionHint,
                  style: TextStyle(color: Brand.textSecondary, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          selected
              ? const Icon(Icons.check_circle_rounded, color: Brand.accent, size: 24)
              : Icon(Icons.chevron_right_rounded, color: Brand.textTertiary),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({super.key, required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 24,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      children: [
        IconPlate(icon: icon, color: Brand.accent, iconColor: Brand.accent, size: 52),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

/// Gradients for trainers without a photo; the choice depends only on the id, so it never changes.
const _avatarGradients = [
  [Color(0xFFFF6B6F), Color(0xFFB4234D)],
  [Color(0xFFB48CFF), Color(0xFF5B3FD9)],
  [Color(0xFF4ADE80), Color(0xFF12805A)],
  [Color(0xFF1FACD8), Color(0xFF2340E0)],
  [Color(0xFFFFC93C), Color(0xFFC77A0A)],
];

/// 54×54 photo, or initials on a deterministic gradient while there is no photo or it fails to load.
class _ListAvatar extends StatelessWidget {
  const _ListAvatar({required this.trainer});
  final Trainer trainer;

  @override
  Widget build(BuildContext context) {
    final colors = _avatarGradients[trainer.id.codeUnits.fold(0, (a, b) => a + b) % _avatarGradients.length];
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                _initials(trainer),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (trainer.photoUrl != null)
              Image.network(
                AppConfig.resolve(trainer.photoUrl!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrainerRow extends StatelessWidget {
  const _TrainerRow({required this.trainer, required this.pending, required this.onTap});
  final Trainer trainer;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tr = trainer;
    final meta = <Widget>[
      if (tr.experienceYears != null)
        Text(t.yearsShort(tr.experienceYears!), style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
      if (pending)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Brand.warning, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              t.requestPending,
              style: const TextStyle(color: Brand.warningText, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        )
      else if (!tr.isAcceptingClients)
        Text(t.notAcceptingClients, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
    ];
    return PressScale(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _ListAvatar(trainer: tr),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (tr.specialization != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr.specialization!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: meta),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Brand.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

(String, Color) _clientRequestStyle(AppLocalizations t, TrainerRequestStatus s) => switch (s) {
  TrainerRequestStatus.pending => (t.requestPending, Brand.warning),
  TrainerRequestStatus.accepted => (t.requestAccepted, Brand.success),
  TrainerRequestStatus.rejected => (t.requestRejected, Brand.red),
  TrainerRequestStatus.cancelled => (t.requestCancelled, Brand.textTertiary),
};

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});
  final TrainerRequest request;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final (label, color) = _clientRequestStyle(t, request.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.trainer.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(fmt.dateTime(request.createdAt), style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
                if (request.responseComment != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t.trainerComment(request.responseComment!),
                    style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusChip(label: label, color: color),
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
      GlassSkeleton(height: 34, width: 230, radius: 10),
      SizedBox(height: 8),
      GlassSkeleton(height: 16, width: 200, radius: 8),
      SizedBox(height: 16),
      GlassSkeleton(height: 48, radius: 24),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 250, radius: Brand.radiusHero),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 24, width: 150, radius: 8),
      SizedBox(height: 12),
      GlassSkeleton(height: 82, radius: 24),
      SizedBox(height: 8),
      GlassSkeleton(height: 82, radius: 24),
      SizedBox(height: 8),
      GlassSkeleton(height: 82, radius: 24),
      SizedBox(height: 8),
      GlassSkeleton(height: 82, radius: 24),
    ],
  );
}

/// Circle avatar with the first letter (trainer screens) and an optional photo.
class TrainerAvatar extends StatelessWidget {
  const TrainerAvatar({super.key, required this.name, this.radius = 26, this.photoUrl});
  final String name;
  final double radius;

  /// Photo path from the API; the initial stays visible while it loads or if it fails.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
    foregroundImage: photoUrl == null ? null : NetworkImage(AppConfig.resolve(photoUrl!)),
    onForegroundImageError: photoUrl == null ? null : (_, _) {},
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: radius * 0.75),
    ),
  );
}

/// Trainer profile with the request action. Pops `true` when something changed. Open it with [showTrainerSheet].
class TrainerSheet extends StatefulWidget {
  const TrainerSheet({
    super.key,
    required this.trainer,
    required this.isMine,
    required this.pending,
    required this.repo,
    this.contacts,
    this.onChanged,
  });
  final Trainer trainer;
  final bool isMine;
  final TrainerRequest? pending;
  final ClientRepository repo;

  /// Telegram / Instagram the client may see; null uses those of [trainer] (own trainer from the profile).
  final TrainerContacts? contacts;

  /// Called once a request was sent or cancelled, even if the sheet is then swiped away.
  final VoidCallback? onChanged;

  @override
  State<TrainerSheet> createState() => _TrainerSheetState();
}

class _TrainerSheetState extends State<TrainerSheet> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Set once the request is sent: the sheet then shows the trainer's contacts.
  TrainerRequest? _sent;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged?.call();
      if (!mounted) return;
      showSnack(context, success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = _message.text.trim();
      final request = await widget.repo.requestTrainer(widget.trainer.id, text.isEmpty ? null : text);
      widget.onChanged?.call();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      FocusScope.of(context).unfocus();
      setState(() => _sent = request);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tr = widget.trainer;
    if (_sent != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: _RequestSentView(
            trainer: tr,
            contacts: _sent!.trainerContacts,
            onDone: () => Navigator.of(context).pop(true),
          ),
        ),
      );
    }
    final canRequest = !widget.isMine && widget.pending == null && tr.isAcceptingClients;
    // Contacts appear once the client has a request to the trainer or the trainer is theirs.
    final contacts = widget.isMine || widget.pending != null ? (widget.contacts ?? tr.contacts) : TrainerContacts.none;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GlassRingAvatar(size: 76, ring: 3, photoUrl: tr.photoUrl, initials: _initials(tr)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.fullName,
                        style: const TextStyle(
                          color: Brand.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (tr.specialization != null) ...[
                        const SizedBox(height: 2),
                        Text(tr.specialization!, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
                      ],
                      if (tr.experienceYears != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          t.experienceYears(tr.experienceYears!),
                          style: TextStyle(color: Brand.textTertiary, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.isMine) StatusChip(label: t.currentTrainerBadge, color: Brand.accent),
                StatusChip(
                  label: tr.isAcceptingClients ? t.acceptingClients : t.notAcceptingClients,
                  color: tr.isAcceptingClients ? Brand.success : Brand.textTertiary,
                  textColor: tr.isAcceptingClients ? Brand.successText : Brand.textSecondary,
                ),
              ],
            ),
            if (tr.bio != null) ...[
              const SizedBox(height: 20),
              Text(
                t.about,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(tr.bio!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.45)),
            ],
            if (!contacts.isEmpty) ...[
              const SizedBox(height: 20),
              Text(
                t.trainerContactsTitle,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TrainerContactButtons(contacts: contacts),
            ],
            const SizedBox(height: 22),
            if (widget.pending != null) ...[
              Row(
                children: [
                  const IconPlate(
                    icon: Icons.hourglass_top_rounded,
                    color: Brand.warning,
                    iconColor: Brand.warningIcon,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.requestPending,
                    style: const TextStyle(color: Brand.warningText, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassPillButton(
                label: t.cancelRequest,
                icon: Icons.close_rounded,
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.repo.cancelRequest(widget.pending!.id), t.requestCancelled),
              ),
            ] else if (canRequest) ...[
              TextField(
                controller: _message,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                cursorColor: Brand.accent,
                style: const TextStyle(color: Brand.textPrimary),
                decoration: InputDecoration(
                  hintText: t.requestMessageHint,
                  hintStyle: TextStyle(color: Brand.textTertiary),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  counterStyle: TextStyle(color: Brand.textTertiary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Brand.glassStroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Brand.accent, width: 1.5),
                  ),
                ),
              ),
              Text(t.requestExplain, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
              const SizedBox(height: 14),
              Opacity(
                opacity: _busy ? 0.6 : 1,
                child: GradientPillButton(
                  key: const Key('choose-as-trainer'),
                  label: t.chooseAsTrainer,
                  icon: Icons.check_rounded,
                  height: 50,
                  onPressed: _send,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Brand.redText)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown in the trainer sheet right after the request is sent: what happens next and how to reach the trainer.
class _RequestSentView extends StatelessWidget {
  const _RequestSentView({required this.trainer, required this.contacts, required this.onDone});
  final Trainer trainer;
  final TrainerContacts contacts;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('request-sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GlassRingAvatar(size: 84, ring: 3, photoUrl: trainer.photoUrl, initials: _initials(trainer)),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: Brand.buttonGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF111116), width: 3),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t.requestSentTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Brand.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          contacts.isEmpty ? t.requestSentBodyNoContacts(trainer.fullName) : t.requestSentBody(trainer.fullName),
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.textSecondary, fontSize: 15, height: 1.4),
        ),
        if (!contacts.isEmpty) ...[const SizedBox(height: 20), TrainerContactButtons(contacts: contacts)],
        const SizedBox(height: 22),
        GradientPillButton(key: const Key('request-sent-done'), label: t.done, height: 52, onPressed: onDone),
      ],
    );
  }
}

/// Telegram and Instagram buttons of a trainer, one under the other so usernames are not cut; each opens the
/// profile in the app or the browser.
class TrainerContactButtons extends StatelessWidget {
  const TrainerContactButtons({super.key, required this.contacts});
  final TrainerContacts contacts;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      if (contacts.telegramUri != null)
        _ContactButton(
          key: const Key('contact-telegram'),
          icon: Icons.telegram,
          color: const Color(0xFF29A9EB),
          title: 'Telegram',
          handle: '@${contacts.telegram}',
          onTap: () => openContact(context, contacts.telegramUri!),
        ),
      if (contacts.instagramUri != null)
        _ContactButton(
          key: const Key('contact-instagram'),
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFFE1306C),
          title: 'Instagram',
          handle: '@${contacts.instagram}',
          onTap: () => openContact(context, contacts.instagramUri!),
        ),
    ];
    return Column(
      children: [
        for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(height: 10), b],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.handle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 18,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    borderColor: color.withValues(alpha: 0.35),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Brand.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Icon(Icons.north_east_rounded, color: Brand.textTertiary, size: 18),
      ],
    ),
  );
}

/// Request status label and color for the trainer's request screens.
(String, Color) requestStatusStyle(AppLocalizations t, TrainerRequestStatus s) => switch (s) {
  TrainerRequestStatus.pending => (t.requestPending, AppColors.orange),
  TrainerRequestStatus.accepted => (t.requestAccepted, AppColors.accent),
  TrainerRequestStatus.rejected => (t.requestRejected, AppColors.red),
  TrainerRequestStatus.cancelled => (t.requestCancelled, AppColors.textSecondary),
};
