import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../client/workouts_screen.dart' show SessionTile;
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TrainerScheduleScreen extends StatefulWidget {
  const TrainerScheduleScreen({super.key});
  @override
  State<TrainerScheduleScreen> createState() => _TrainerScheduleScreenState();
}

class _TrainerScheduleScreenState extends State<TrainerScheduleScreen> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<TrainerRepository>();
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.schedule)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _NewSessionSheet(repo: repo),
          );
          if (created == true) setState(() => _version++);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(t.newSession),
      ),
      body: AsyncView<List<TrainingSession>>(
        key: ValueKey(_version),
        load: repo.sessions,
        builder: (context, sessions, reload) {
          // The API returns the last 7 days through the next 30. Unmarked past sessions stay actionable.
          final now = DateTime.now();
          final upcoming = sessions.where((s) => s.endsAt.isAfter(now)).toList();
          final past = sessions.where((s) => !s.endsAt.isAfter(now)).toList().reversed.toList();
          Widget tile(TrainingSession s) => SessionTile(
            session: s,
            fmt: fmt,
            onTap: s.status == TrainingSessionStatus.scheduled ? () => _actions(context, repo, s, reload) : null,
          );
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                SectionTitle(t.upcoming),
                if (upcoming.isEmpty) MessageView(icon: Icons.event_busy_rounded, title: t.noSessions),
                for (final s in upcoming) ...[tile(s), const SizedBox(height: 10)],
                if (past.isNotEmpty) ...[
                  SectionTitle(t.pastWeek),
                  for (final s in past) ...[tile(s), const SizedBox(height: 10)],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _actions(
    BuildContext context,
    TrainerRepository repo,
    TrainingSession s,
    Future<void> Function() reload,
  ) async {
    final t = AppLocalizations.of(context);
    final completed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (s.startsAt.isBefore(DateTime.now()))
              ListTile(
                key: const Key('session-complete'),
                leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent),
                title: Text(t.markCompleted),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ListTile(
              key: const Key('session-cancel'),
              leading: const Icon(Icons.cancel_outlined, color: AppColors.red),
              title: Text(t.cancelSession),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (completed == null || !context.mounted) return;
    // Cancelling cannot be undone, so it needs an explicit confirmation.
    if (!completed && await _confirmCancel(context) != true) return;
    try {
      await repo.setSessionStatus(s.id, completed: completed);
      if (context.mounted) showSnack(context, completed ? t.sessionMarkedCompleted : t.sessionMarkedCancelled);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(t, e));
    }
    // Reload in both cases: on a conflict the list shows the status set elsewhere.
    await reload();
  }

  Future<bool?> _confirmCancel(BuildContext context) {
    final t = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cancelSessionConfirm),
        content: Text(t.cancelSessionConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.keepSession)),
          TextButton(
            key: const Key('session-cancel-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.cancelSession, style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _NewSessionSheet extends StatefulWidget {
  const _NewSessionSheet({required this.repo});
  final TrainerRepository repo;
  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  late final Future<List<TrainerClient>> _clients = widget.repo.allClients();
  final _notes = TextEditingController();
  String? _clientId;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 60;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = Fmt('ru').clubToday().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Picked date and time are club-local; convert to a UTC instant for the API.
  DateTime get _startsAtUtc =>
      DateTime.utc(_date.year, _date.month, _date.day, _time.hour, _time.minute).subtract(AppConfig.clubUtcOffset);

  Future<void> _submit() async {
    if (_clientId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.createSession(
        clientId: _clientId!,
        startsAtUtc: _startsAtUtc,
        durationMinutes: _duration,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: FutureBuilder<List<TrainerClient>>(
        future: _clients,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => Navigator.pop(context));
          if (!snap.hasData) return const SizedBox(height: 200, child: LoadingView());
          final clients = snap.data!;
          if (clients.isEmpty) return MessageView(icon: Icons.people_outline_rounded, title: t.noClients);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.newSession, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _clientId,
                  decoration: InputDecoration(labelText: t.client),
                  items: [for (final c in clients) DropdownMenuItem(value: c.id, child: Text(c.fullName))],
                  onChanged: (v) => setState(() => _clientId = v),
                ),
                if (_clientId != null &&
                    !(clients.firstWhere((c) => c.id == _clientId).currentMembership?.isUsable ?? false))
                  Padding(
                    key: const Key('client-membership-warning'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(t.clientNoActiveMembership, style: const TextStyle(color: AppColors.orange)),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: t.date,
                        value: fmt.date(_date),
                        onTap: () async {
                          final today = fmt.clubToday();
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: today,
                            lastDate: today.add(const Duration(days: 120)),
                          );
                          if (d != null) setState(() => _date = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerField(
                        label: t.time,
                        value: _time.format(context),
                        onTap: () async {
                          final tm = await showTimePicker(context: context, initialTime: _time);
                          if (tm != null) setState(() => _time = tm);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: InputDecoration(labelText: t.duration),
                  items: [
                    for (final m in [30, 45, 60, 90, 120]) DropdownMenuItem(value: m, child: Text(t.minutes(m))),
                  ],
                  onChanged: (v) => setState(() => _duration = v ?? 60),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLength: 1000,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: t.notes),
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.red)),
                const SizedBox(height: 8),
                FilledButton(onPressed: _busy || _clientId == null ? null : _submit, child: Text(t.create)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    ),
  );
}
