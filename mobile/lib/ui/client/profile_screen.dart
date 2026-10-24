import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session.dart';
import '../auth/change_password_screen.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/language_switch.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = context.read<ClientRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle), actions: const [LogoutAction()]),
      body: AsyncView<ClientProfile>(
        load: repo.profile,
        builder: (context, profile, reload) => ProfileForm(
          key: ValueKey(profile.id),
          profile: profile,
          onSave: (update) async {
            await repo.updateProfile(update);
            await reload();
          },
        ),
      ),
    );
  }
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.profile, required this.onSave});
  final ClientProfile profile;
  final Future<void> Function(ProfileUpdate) onSave;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _email = TextEditingController(text: widget.profile.email ?? '');
  late DateTime? _birthDate = widget.profile.birthDate;
  late String? _gender = widget.profile.gender;
  bool _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await widget.onSave(
        ProfileUpdate(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          birthDate: _birthDate,
          gender: _gender,
        ),
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
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final p = widget.profile;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  child: Text(
                    p.firstName.isEmpty ? '?' : p.firstName.characters.first.toUpperCase(),
                    style: const TextStyle(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.firstName} ${p.lastName}', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(p.phone, style: Theme.of(context).textTheme.bodySmall),
                      if (!p.phoneConfirmed) ...[
                        const SizedBox(height: 6),
                        StatusPill(t.phoneNotConfirmed, color: AppColors.orange),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(t.phoneChangeHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          SectionTitle(t.personalData),
          TextFormField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: t.firstName),
            validator: (v) => (v == null || v.trim().isEmpty) ? t.validationRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _last,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: t.lastName),
            validator: (v) => (v == null || v.trim().isEmpty) ? t.validationRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: t.email),
            validator: (v) =>
                (v != null && v.trim().isNotEmpty && !Validators.isEmail(v.trim())) ? t.validationEmail : null,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final today = fmt.clubToday();
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime(today.year - 25),
                firstDate: DateTime(1920),
                lastDate: today.subtract(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: t.birthDate,
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
              ),
              child: Text(_birthDate == null ? t.notSpecified : fmt.date(_birthDate!)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _gender,
            decoration: InputDecoration(labelText: t.gender),
            items: [
              DropdownMenuItem(value: null, child: Text(t.notSpecified)),
              DropdownMenuItem(value: 'Male', child: Text(t.genderMale)),
              DropdownMenuItem(value: 'Female', child: Text(t.genderFemale)),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(t.save),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('open-change-password'),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
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
      ),
    );
  }
}

/// Asks for confirmation, then signs out. Shared by client and trainer profiles.
Future<void> confirmLogout(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.logoutConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
        TextButton(key: const Key('logout-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.logout)),
      ],
    ),
  );
  if (ok == true && context.mounted) await context.read<SessionController>().logout();
}

class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('appbar-logout'),
    tooltip: AppLocalizations.of(context).logout,
    icon: const Icon(Icons.logout_rounded),
    onPressed: () => confirmLogout(context),
  );
}
