import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<NotificationRepository>();
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.notifications)),
      body: AsyncView<Paged<AppNotification>>(
        load: repo.list,
        builder: (context, page, reload) {
          if (page.items.isEmpty) {
            return MessageView(icon: Icons.notifications_none_rounded, title: t.noNotifications);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (page.items.any((n) => !n.isRead))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        await repo.markAllRead();
                        await reload();
                      },
                      child: Text(t.markAllRead),
                    ),
                  ),
                LoadMoreList<AppNotification>(
                  key: ObjectKey(page),
                  first: page,
                  loadPage: (p) => repo.list(page: p),
                  idOf: (n) => n.id,
                  itemBuilder: (context, n) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 12),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: n.isRead ? Colors.transparent : AppColors.accent,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notificationText(t, n), style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 4),
                                Text(fmt.dateTime(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String notificationText(AppLocalizations t, AppNotification n) => switch (n.type) {
  NotificationType.trainerRequestReceived => t.notifTrainerRequestReceived,
  NotificationType.trainerRequestAccepted => t.notifTrainerRequestAccepted(n.payload ?? ''),
  NotificationType.trainerRequestRejected => t.notifTrainerRequestRejected(n.payload ?? ''),
  NotificationType.trainingSessionScheduled => t.notifTrainingSessionScheduled,
  NotificationType.trainingSessionCancelled => t.notifTrainingSessionCancelled,
  NotificationType.membershipAssigned => t.notifMembershipAssigned(n.payload ?? ''),
  NotificationType.unknown => '',
};
