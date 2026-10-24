import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/change_password_screen.dart';
import '../client/profile_screen.dart' show LogoutAction, confirmLogout;
import '../client/trainers_screen.dart' show TrainerAvatar;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/language_switch.dart';

class TrainerProfileScreen extends StatelessWidget {
  const TrainerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<TrainerRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(t.trainerCabinet), actions: const [LogoutAction()]),
      body: AsyncView<TrainerSelfProfile>(
        load: repo.profile,
        builder: (context, p, reload) => _TrainerProfileForm(profile: p, repo: repo),
      ),
    );
  }
}

class _TrainerProfileForm extends StatefulWidget {
  const _TrainerProfileForm({required this.profile, required this.repo});
  final TrainerSelfProfile profile;
  final TrainerRepository repo;
  @override
  State<_TrainerProfileForm> createState() => _TrainerProfileFormState();
}

class _TrainerProfileFormState extends State<_TrainerProfileForm> {
  late final _spec = TextEditingController(text: widget.profile.specialization ?? '');
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  late bool _accepting = widget.profile.isAcceptingClients;
  bool _busy = false;

  @override
  void dispose() {
    _spec.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await widget.repo.updateProfile(
        specialization: _spec.text.trim().isEmpty ? null : _spec.text.trim(),
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        isAcceptingClients: _accepting,
      );
      if (mounted) showSnack(context, t.saved);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        AppCard(
          child: Row(
            children: [
              TrainerAvatar(name: p.firstName, radius: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName, style: Theme.of(context).textTheme.titleLarge),
                    Text(p.phone, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    StatusPill(t.clientsCount(p.clientsCount), color: AppColors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _spec,
          maxLength: 128,
          decoration: InputDecoration(labelText: t.specialization),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _bio,
          maxLength: 2000,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: t.bio),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(t.acceptNewClients),
          value: _accepting,
          onChanged: (v) => setState(() => _accepting = v),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _save, child: Text(t.save)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
          icon: const Icon(Icons.lock_outline_rounded),
          label: Text(t.changePassword),
        ),
        SectionTitle(t.language),
        const Align(alignment: Alignment.centerLeft, child: LanguageSwitch()),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          key: const Key('profile-logout'),
          onPressed: () => confirmLogout(context),
          icon: const Icon(Icons.logout_rounded, color: AppColors.red),
          label: Text(t.logout, style: const TextStyle(color: AppColors.red)),
        ),
      ],
    );
  }
}
