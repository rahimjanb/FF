import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _TrainersData {
  _TrainersData(this.trainers, this.requests, this.myTrainerId);
  final List<Trainer> trainers;
  final List<TrainerRequest> requests;
  final String? myTrainerId;

  TrainerRequest? pendingFor(String trainerId) =>
      requests.where((r) => r.trainer.id == trainerId && r.status == TrainerRequestStatus.pending).firstOrNull;
}

class TrainersScreen extends StatelessWidget {
  const TrainersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<ClientRepository>();
    Future<_TrainersData> load() async {
      final results = await Future.wait([repo.trainers(), repo.trainerRequests(), repo.profile()]);
      return _TrainersData(
        results[0] as List<Trainer>,
        results[1] as List<TrainerRequest>,
        (results[2] as ClientProfile).assignedTrainer?.id,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.trainersTitle)),
      body: AsyncView<_TrainersData>(
        load: load,
        builder: (context, data, reload) => RefreshIndicator(
          onRefresh: reload,
          child: data.trainers.isEmpty && data.requests.isEmpty
              ? ListView(
                  children: [MessageView(icon: Icons.groups_outlined, title: t.noTrainers)],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    // The client's own trainer and trainers with a pending request first, then the rest in API order:
                    // in a long list they would otherwise be far below the fold.
                    for (final tr in [
                      ...data.trainers.where((tr) => tr.id == data.myTrainerId),
                      ...data.trainers.where((tr) => tr.id != data.myTrainerId && data.pendingFor(tr.id) != null),
                      ...data.trainers.where((tr) => tr.id != data.myTrainerId && data.pendingFor(tr.id) == null),
                    ]) ...[
                      _TrainerTile(
                        trainer: tr,
                        isMine: tr.id == data.myTrainerId,
                        pending: data.pendingFor(tr.id) != null,
                        onTap: () async {
                          final changed = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => TrainerSheet(
                              trainer: tr,
                              isMine: tr.id == data.myTrainerId,
                              pending: data.pendingFor(tr.id),
                              repo: repo,
                            ),
                          );
                          if (changed == true) await reload();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (data.requests.isNotEmpty) ...[
                      SectionTitle(t.myRequests),
                      for (final r in data.requests) ...[_RequestTile(request: r), const SizedBox(height: 8)],
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _TrainerTile extends StatelessWidget {
  const _TrainerTile({required this.trainer, required this.isMine, required this.pending, required this.onTap});
  final Trainer trainer;
  final bool isMine, pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          TrainerAvatar(name: trainer.firstName, photoUrl: trainer.photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trainer.fullName, style: Theme.of(context).textTheme.titleMedium),
                if (trainer.specialization != null) ...[
                  const SizedBox(height: 2),
                  Text(trainer.specialization!, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                if (isMine)
                  StatusPill(t.currentTrainerBadge)
                else if (pending)
                  StatusPill(t.requestPending, color: AppColors.orange)
                else if (!trainer.isAcceptingClients)
                  StatusPill(t.notAcceptingClients, color: AppColors.textSecondary),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

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

/// Trainer profile with the request action. Pops `true` when something changed.
class TrainerSheet extends StatefulWidget {
  const TrainerSheet({
    super.key,
    required this.trainer,
    required this.isMine,
    required this.pending,
    required this.repo,
  });
  final Trainer trainer;
  final bool isMine;
  final TrainerRequest? pending;
  final ClientRepository repo;

  @override
  State<TrainerSheet> createState() => _TrainerSheetState();
}

class _TrainerSheetState extends State<TrainerSheet> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      showSnack(context, success);
      Navigator.of(context).pop(true);
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
    final canRequest = !widget.isMine && widget.pending == null && tr.isAcceptingClients;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TrainerAvatar(name: tr.firstName, radius: 34, photoUrl: tr.photoUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.fullName, style: Theme.of(context).textTheme.titleLarge),
                      if (tr.specialization != null)
                        Text(tr.specialization!, style: Theme.of(context).textTheme.bodySmall),
                      if (tr.experienceYears != null)
                        Text(t.experienceYears(tr.experienceYears!), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                tr.isAcceptingClients ? t.acceptingClients : t.notAcceptingClients,
                color: tr.isAcceptingClients ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            if (tr.bio != null) ...[
              const SizedBox(height: 18),
              Text(t.about, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(tr.bio!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
            ],
            const SizedBox(height: 22),
            if (widget.isMine)
              StatusPill(t.currentTrainerBadge)
            else if (widget.pending != null) ...[
              Text(t.requestPending, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.repo.cancelRequest(widget.pending!.id), t.requestCancelled),
                child: Text(t.cancelRequest),
              ),
            ] else if (canRequest) ...[
              TextField(
                controller: _message,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(hintText: t.requestMessageHint),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final text = _message.text.trim();
                        await widget.repo.requestTrainer(tr.id, text.isEmpty ? null : text);
                      }, t.requestSent),
                child: Text(t.sendRequest),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});
  final TrainerRequest request;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final (label, color) = requestStatusStyle(t, request.status);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(request.trainer.fullName, style: Theme.of(context).textTheme.titleMedium)),
              StatusPill(label, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(fmt.dateTime(request.createdAt), style: Theme.of(context).textTheme.bodySmall),
          if (request.responseComment != null) ...[
            const SizedBox(height: 6),
            Text(t.trainerComment(request.responseComment!), style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

(String, Color) requestStatusStyle(AppLocalizations t, TrainerRequestStatus s) => switch (s) {
  TrainerRequestStatus.pending => (t.requestPending, AppColors.orange),
  TrainerRequestStatus.accepted => (t.requestAccepted, AppColors.accent),
  TrainerRequestStatus.rejected => (t.requestRejected, AppColors.red),
  TrainerRequestStatus.cancelled => (t.requestCancelled, AppColors.textSecondary),
};
