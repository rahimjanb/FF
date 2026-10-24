import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../client/trainers_screen.dart' show TrainerAvatar;
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/membership_view.dart';

class TrainerClientsScreen extends StatelessWidget {
  const TrainerClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<TrainerRepository>();
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.myClients)),
      body: AsyncView<Paged<TrainerClient>>(
        load: repo.clients,
        builder: (context, page, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (page.items.isEmpty) MessageView(icon: Icons.people_outline_rounded, title: t.noClients),
              LoadMoreList<TrainerClient>(
                key: ObjectKey(page),
                first: page,
                loadPage: (p) => repo.clients(page: p),
                idOf: (c) => c.id,
                itemBuilder: (context, c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TrainerAvatar(name: c.firstName, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.fullName, style: Theme.of(context).textTheme.titleMedium),
                                  Text(c.phone, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            // Flexible: long labels (e.g. in Uzbek) shrink with an ellipsis instead of overflowing.
                            Flexible(
                              child: c.currentMembership != null
                                  ? StatusPill(
                                      membershipStatusText(t, c.currentMembership!.effectiveStatus),
                                      color: membershipColor(c.currentMembership!.effectiveStatus),
                                    )
                                  : StatusPill(t.noMembership, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (c.currentMembership != null)
                          Text(
                            '${c.currentMembership!.planName} · ${t.validUntil(fmt.date(c.currentMembership!.endDate))}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          c.lastVisitAt == null ? t.noVisitsYet : t.lastVisitOn(fmt.dateTime(c.lastVisitAt!)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
