import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../client/trainers_screen.dart' show requestStatusStyle, TrainerAvatar;
import '../formatters.dart';
import '../widgets/common.dart';

class TrainerRequestsScreen extends StatelessWidget {
  const TrainerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<TrainerRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(t.incomingRequests)),
      body: AsyncView<(List<TrainerRequest>, Paged<TrainerRequest>)>(
        load: () async {
          final r = await Future.wait([repo.allPendingRequests(), repo.requests()]);
          return (r[0] as List<TrainerRequest>, r[1] as Paged<TrainerRequest>);
        },
        builder: (context, data, reload) {
          final (pending, history) = data;
          bool processed(TrainerRequest r) => r.status != TrainerRequestStatus.pending;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (pending.isEmpty) MessageView(icon: Icons.inbox_outlined, title: t.noRequests),
                for (final r in pending) ...[
                  _RequestCard(request: r, onRespond: (accept) => _respond(context, repo, r, accept, reload)),
                  const SizedBox(height: 10),
                ],
                // History pages mix in pending requests (already shown above); they are skipped here.
                if (history.items.any(processed) || history.totalPages > 1) ...[
                  SectionTitle(t.history),
                  LoadMoreList<TrainerRequest>(
                    key: ObjectKey(history),
                    first: history,
                    loadPage: (p) => repo.requests(page: p),
                    idOf: (r) => r.id,
                    itemBuilder: (context, r) => processed(r)
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RequestCard(request: r),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    TrainerRepository repo,
    TrainerRequest r,
    bool accept,
    Future<void> Function() reload,
  ) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accept ? t.accept : t.reject),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: InputDecoration(hintText: t.commentOptional),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    final comment = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      await repo.respond(r.id, accept: accept, comment: comment.isEmpty ? null : comment);
      if (context.mounted) showSnack(context, accept ? t.requestAccepted : t.requestRejected);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(t, e));
    }
    await reload();
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, this.onRespond});
  final TrainerRequest request;
  final void Function(bool accept)? onRespond;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final (label, color) = requestStatusStyle(t, request.status);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TrainerAvatar(name: request.client.firstName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.client.fullName, style: Theme.of(context).textTheme.titleMedium),
                    Text(fmt.dateTime(request.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(label, color: color),
            ],
          ),
          if (request.message != null) ...[
            const SizedBox(height: 12),
            Text(request.message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (onRespond != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => onRespond!(false), child: Text(t.reject)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: () => onRespond!(true), child: Text(t.accept)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
