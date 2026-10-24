import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/locale_controller.dart';
import '../../state/session.dart';
import '../auth/change_password_screen.dart';
import '../formatters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/language_switch.dart';

class _ProfileData {
  _ProfileData(this.profile, this.dashboard);
  final ClientProfile profile;
  final ClientDashboard dashboard;
}

/// Client profile in the Liquid Glass style. Personal data is read-only here and edited in [_EditProfileSheet].
/// Photo, Face ID, notification settings, support and club rules have no backend yet and are shown disabled.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClientRepository>();
    Future<_ProfileData> load() async {
      final r = await Future.wait<Object>([repo.profile(), repo.dashboard()]);
      return _ProfileData(r[0] as ClientProfile, r[1] as ClientDashboard);
    }

    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: AsyncView<_ProfileData>(
          load: load,
          loading: (_) => const _LoadingSkeleton(),
          builder: (context, d, reload) => RefreshIndicator(
            color: Brand.accent,
            onRefresh: reload,
            child: _ProfileContent(data: d, reload: reload),
          ),
        ),
      ),
    );
  }
}

enum _Field { firstName, lastName, email, birthDate, gender }

double _listBottom(BuildContext context) => MediaQuery.paddingOf(context).bottom + Brand.tabBarReserve + 8;

void _snack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
}

String _genderText(AppLocalizations t, String? g) => switch (g) {
  'Male' => t.genderMale,
  'Female' => t.genderFemale,
  _ => t.notSpecified,
};

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.data, required this.reload});
  final _ProfileData data;
  final Future<void> Function() reload;

  Future<void> _edit(BuildContext context, [_Field? focus]) async {
    final t = AppLocalizations.of(context);
    final repo = context.read<ClientRepository>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111116),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.radiusHero))),
      builder: (_) => _EditProfileSheet(profile: data.profile, focus: focus, onSave: repo.updateProfile),
    );
    if (saved == true && context.mounted) {
      _snack(context, t.saved);
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final fmt = Fmt(locale);
    final p = data.profile;
    final filled = [
      p.firstName.trim().isNotEmpty,
      p.lastName.trim().isNotEmpty,
      p.email?.isNotEmpty == true,
      p.birthDate != null,
      p.gender != null,
    ].where((x) => x).length;
    Widget soon() => SoonBadge(t.soon);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, _listBottom(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.profileTitle,
                style: const TextStyle(
                  color: Brand.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            GlassCircleButton(
              icon: Icons.settings_outlined,
              tooltip: t.settings,
              onTap: () => showGlassSheet<void>(context, builder: (_) => const _SettingsSheet()),
            ),
          ],
        ),
        const SizedBox(height: Brand.sectionGap),
        _ProfileCard(data: data, fmt: fmt, locale: locale, onEdit: () => _edit(context)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: Brand.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.phoneChangeHintShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Brand.textTertiary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Brand.sectionGap),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  t.personalData,
                  style: const TextStyle(
                    color: Brand.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Text(t.filledOf(filled, 5), style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
            ],
          ),
        ),
        GlassList(
          dividerIndent: 64,
          children: [
            _DataRow(
              icon: Icons.person_outline_rounded,
              label: t.firstName,
              value: p.firstName,
              onTap: () => _edit(context, _Field.firstName),
            ),
            _DataRow(
              icon: Icons.person_outline_rounded,
              label: t.lastName,
              value: p.lastName,
              onTap: () => _edit(context, _Field.lastName),
            ),
            _DataRow(
              key: const Key('profile-email'),
              icon: Icons.mail_outline_rounded,
              label: t.email,
              value: p.email,
              emptyText: t.addEmail,
              emptyIsAction: true,
              onTap: () => _edit(context, _Field.email),
            ),
            _DataRow(
              icon: Icons.cake_outlined,
              label: t.birthDate,
              value: p.birthDate == null ? null : fmt.numericDate(p.birthDate!),
              emptyText: t.notSpecified,
              trailing: Icons.calendar_today_outlined,
              onTap: () => _edit(context, _Field.birthDate),
            ),
            _DataRow(
              icon: Icons.wc_rounded,
              label: t.gender,
              value: p.gender == null ? null : _genderText(t, p.gender),
              emptyText: t.notSpecified,
              trailing: Icons.unfold_more_rounded,
              onTap: () => _edit(context, _Field.gender),
            ),
          ],
        ),
        const SizedBox(height: Brand.sectionGap),
        GlassSectionHeader(t.settings),
        GlassList(
          dividerIndent: 64,
          children: [
            // Notification preferences and biometric sign-in have no backend or plugin yet.
            _SettingRow(
              icon: Icons.notifications_none_rounded,
              color: const Color(0xFFFF6B6F),
              label: t.notifications,
              trailing: _DisabledSwitch(value: true, badge: soon()),
            ),
            _SettingRow(
              icon: Icons.face_retouching_natural_rounded,
              color: Brand.successText,
              label: t.faceIdLogin,
              trailing: _DisabledSwitch(value: false, badge: soon()),
            ),
            _SettingRow(
              icon: Icons.language_rounded,
              color: Brand.accent,
              label: t.language,
              value: t.languageName,
              onTap: () => showGlassSheet<void>(context, builder: (_) => const _LanguageSheet()),
            ),
            _SettingRow(
              key: const Key('open-change-password'),
              icon: Icons.lock_outline_rounded,
              color: Brand.blue,
              label: t.changePassword,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            _SettingRow(
              icon: Icons.chat_bubble_outline_rounded,
              color: Brand.purple,
              label: t.menuSupport,
              trailing: soon(),
            ),
            _SettingRow(icon: Icons.description_outlined, color: Brand.trophy, label: t.menuRules, trailing: soon()),
          ],
        ),
        const SizedBox(height: Brand.sectionGap + 4),
        _LogoutButton(onPressed: () => confirmLogout(context)),
        const SizedBox(height: 18),
        const _VersionLabel(),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.data, required this.fmt, required this.locale, required this.onEdit});
  final _ProfileData data;
  final Fmt fmt;
  final String locale;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = data.profile;
    final d = data.dashboard;
    final membership = d.currentMembership ?? d.nextMembership;
    final since = p.memberSince == null ? '—' : DateFormat('LLL y', locale).format(fmt.toClub(p.memberSince!));
    final (chipColor, chipText, chipIcon, chipLabel) = p.phoneConfirmed
        ? (Brand.success, Brand.successText, Icons.check_circle_outline_rounded, t.phoneStatusConfirmed)
        : (const Color(0xFFFF9F0A), const Color(0xFFFFB340), Icons.warning_amber_rounded, t.phoneStatusNotConfirmed);
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, style: TextStyle(color: Brand.textTertiary, fontSize: 11)),
        ],
      ),
    );
    Widget divider() => Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1));
    return Stack(
      children: [
        GlassCard(
          radius: Brand.radiusHero,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              _Avatar(initials: _initials(p), onCamera: () => _snack(context, t.photoSoon)),
              const SizedBox(height: 14),
              Text(
                '${p.firstName} ${p.lastName}'.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Brand.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(Fmt.phone(p.phone), style: TextStyle(color: Brand.textSecondary, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: chipColor.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(chipIcon, size: 13, color: chipText),
                        const SizedBox(width: 4),
                        Text(
                          chipLabel,
                          style: TextStyle(color: chipText, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _EditButton(label: t.editProfile, onPressed: onEdit),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    stat(membership?.planName ?? '—', t.membership),
                    divider(),
                    stat('${d.visits.total}', t.statVisits),
                    divider(),
                    stat(since, t.memberSince),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Soft accent light from the top of the card.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Brand.radiusHero),
                gradient: RadialGradient(
                  center: const Alignment(0, -1.2),
                  radius: 0.9,
                  colors: [Brand.accent.withValues(alpha: 0.25), Brand.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(ClientProfile p) => [
    p.firstName,
    p.lastName,
  ].where((s) => s.trim().isNotEmpty).map((s) => s.trim().characters.first).join().toUpperCase();
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onCamera});
  final String initials;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 104,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(-math.pi / 2),
                colors: [Brand.accent, Brand.glowBlue, Brand.clock, Brand.accent],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF123349), Color(0xFF0B1024)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(color: Brand.clock, fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        // Photo upload for clients has no backend yet; the button explains that.
        Positioned(
          right: -4,
          bottom: -4,
          child: Tooltip(
            message: AppLocalizations.of(context).changePhoto,
            child: InkResponse(
              onTap: onCamera,
              radius: 24,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Brand.buttonGradient,
                      border: Border.all(color: Brand.background, width: 2.5),
                    ),
                    child: const Icon(Icons.photo_camera_outlined, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PressScale(
    child: Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: StadiumBorder(side: BorderSide(color: Brand.glassStroke)),
      child: InkWell(
        key: const Key('profile-edit'),
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 16, color: Brand.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Read-only row of personal data; a tap opens the editor focused on this field.
class _DataRow extends StatelessWidget {
  const _DataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.emptyText,
    this.emptyIsAction = false,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String? value;
  final String? emptyText;
  final bool emptyIsAction;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.trim().isEmpty;
    final action = empty && emptyIsAction;
    return _TapRow(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: Brand.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  empty ? (emptyText ?? '') : value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: action ? Brand.accent : (empty ? Brand.textSecondary : Brand.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (action)
            const Icon(Icons.add_rounded, color: Brand.accent, size: 22)
          else if (trailing != null)
            Icon(trailing, color: Brand.textTertiary, size: 20),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        IconPlate(icon: icon, color: color, iconColor: color, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        if (value != null) ...[
          Text(value!, style: TextStyle(color: Brand.textSecondary, fontSize: 15)),
          const SizedBox(width: 6),
        ],
        trailing ?? Icon(Icons.chevron_right_rounded, color: Brand.textTertiary, size: 22),
      ],
    );
    return onTap == null
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: content)
        : _TapRow(onTap: onTap!, child: content);
  }
}

/// Tappable list row with press feedback (scale + haptic) and a 44+ high target.
class _TapRow extends StatelessWidget {
  const _TapRow({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => PressScale(
    child: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: child),
    ),
  );
}

class _DisabledSwitch extends StatelessWidget {
  const _DisabledSwitch({required this.value, required this.badge});
  final bool value;
  final Widget badge;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      badge,
      const SizedBox(width: 8),
      CupertinoSwitch(value: value, activeTrackColor: const Color(0xFF34C759), onChanged: null),
    ],
  );
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PressScale(
    child: Material(
      color: Brand.red.withValues(alpha: 0.08),
      shape: StadiumBorder(side: BorderSide(color: Brand.red.withValues(alpha: 0.2))),
      child: InkWell(
        key: const Key('profile-logout'),
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: Brand.redText, size: 20),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).logoutAccount,
                style: const TextStyle(color: Brand.redText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (context, snap) => Text(
      snap.hasData ? AppLocalizations.of(context).appVersion(snap.data!.version) : '',
      textAlign: TextAlign.center,
      style: TextStyle(color: Brand.textTertiary, fontSize: 12),
    ),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.settings,
          style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Text(t.language, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        const LanguageSwitch(),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline_rounded, color: Brand.textPrimary),
          title: Text(t.changePassword),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
          },
        ),
      ],
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    const names = {'ru': 'Русский', 'uz': 'O‘zbekcha'};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in LocaleController.supported)
          ListTile(
            title: Text(names[l.languageCode] ?? l.languageCode),
            trailing: l.languageCode == controller.locale.languageCode
                ? const Icon(Icons.check_rounded, color: Brand.accent)
                : null,
            onTap: () {
              controller.set(l);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// Edit sheet: Cancel | Редактирование | Done. Done is enabled only with valid changes; it pops `true` once saved.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile, required this.onSave, this.focus});
  final ClientProfile profile;
  final _Field? focus;
  final Future<ClientProfile> Function(ProfileUpdate) onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _email = TextEditingController(text: widget.profile.email ?? '');
  late DateTime? _birthDate = widget.profile.birthDate;
  late String? _gender = widget.profile.gender;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_first, _last, _email]) {
      c.addListener(() => setState(() {}));
    }
    if (widget.focus == _Field.birthDate) WidgetsBinding.instance.addPostFrameCallback((_) => _pickDate());
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  String? get _firstError => _first.text.trim().isEmpty ? AppLocalizations.of(context).validationRequired : null;
  String? get _lastError => _last.text.trim().isEmpty ? AppLocalizations.of(context).validationRequired : null;
  String? get _emailError {
    final v = _email.text.trim();
    return v.isNotEmpty && !Validators.isEmail(v) ? AppLocalizations.of(context).validationEmail : null;
  }

  bool get _changed {
    final p = widget.profile;
    return _first.text.trim() != p.firstName ||
        _last.text.trim() != p.lastName ||
        _email.text.trim() != (p.email ?? '') ||
        _birthDate != p.birthDate ||
        _gender != p.gender;
  }

  bool get _canSave => !_busy && _changed && _firstError == null && _lastError == null && _emailError == null;

  Future<void> _pickDate() async {
    final today = Fmt(Localizations.localeOf(context).languageCode).clubToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 25),
      firstDate: DateTime(1920),
      lastDate: today.subtract(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: Brand.accent, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
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
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(t, e);
        });
      }
    }
  }

  InputDecoration _decoration(String label, {String? error, Widget? suffix}) => InputDecoration(
    labelText: label,
    errorText: error,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    labelStyle: TextStyle(color: Brand.textTertiary),
    floatingLabelStyle: const TextStyle(color: Brand.accent),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Brand.glassStroke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Brand.accent, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    const genders = [null, 'Male', 'Female'];
    final dirty = _changed;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(foregroundColor: Brand.textSecondary, minimumSize: const Size(64, 44)),
                  child: Text(t.cancel),
                ),
                Expanded(
                  child: Text(
                    t.editTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: _busy
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.accent),
                          ),
                        )
                      : TextButton(
                          key: const Key('profile-edit-done'),
                          onPressed: _canSave ? _save : null,
                          style: TextButton.styleFrom(
                            foregroundColor: Brand.accent,
                            disabledForegroundColor: Brand.textTertiary,
                            minimumSize: const Size(64, 44),
                          ),
                          child: Text(t.done, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(Brand.sidePadding, 12, Brand.sidePadding, 24),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Brand.redText)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _first,
                  cursorColor: Brand.accent,
                  autofocus: widget.focus == _Field.firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(t.firstName, error: dirty ? _firstError : null),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _last,
                  cursorColor: Brand.accent,
                  autofocus: widget.focus == _Field.lastName,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(t.lastName, error: dirty ? _lastError : null),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('profile-edit-email'),
                  controller: _email,
                  cursorColor: Brand.accent,
                  autofocus: widget.focus == _Field.email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _decoration(t.email, error: _emailError),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _decoration(
                      t.birthDate,
                      suffix: Icon(Icons.calendar_today_outlined, size: 20, color: Brand.textTertiary),
                    ),
                    child: Text(
                      _birthDate == null ? t.notSpecified : fmt.numericDate(_birthDate!),
                      style: TextStyle(color: _birthDate == null ? Brand.textSecondary : Brand.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(t.gender, style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
                const SizedBox(height: 8),
                GlassSegmentedControl(
                  segments: [t.notSpecified, t.genderMale, t.genderFemale],
                  index: genders.indexOf(_gender).clamp(0, 2),
                  onChanged: (i) => setState(() => _gender = genders[i]),
                ),
                const SizedBox(height: 16),
                // Phone is the login and is changed only by club staff.
                InputDecorator(
                  isEmpty: false,
                  decoration: _decoration(
                    t.phone,
                    suffix: Icon(Icons.lock_outline_rounded, size: 18, color: Brand.textTertiary),
                  ),
                  child: Text(Fmt.phone(widget.profile.phone), style: TextStyle(color: Brand.textSecondary)),
                ),
                const SizedBox(height: 6),
                Text(t.phoneChangeHintShort, style: TextStyle(color: Brand.textTertiary, fontSize: 12)),
              ],
            ),
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
            child: Align(alignment: Alignment.centerLeft, child: GlassSkeleton(height: 34, width: 150, radius: 10)),
          ),
          GlassSkeleton(height: 44, width: 44, radius: 22),
        ],
      ),
      SizedBox(height: Brand.sectionGap),
      GlassSkeleton(height: 380, radius: Brand.radiusHero),
      SizedBox(height: Brand.sectionGap + 30),
      GlassSkeleton(height: 330, radius: Brand.radiusCard),
    ],
  );
}

/// Asks for confirmation, then signs out. Shared by client and trainer profiles.
Future<void> confirmLogout(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) {
      Widget action(String label, bool value, {Key? key, bool destructive = false}) => ios
          ? CupertinoDialogAction(
              key: key,
              isDestructiveAction: destructive,
              onPressed: () => Navigator.pop(ctx, value),
              child: Text(label),
            )
          : TextButton(key: key, onPressed: () => Navigator.pop(ctx, value), child: Text(label));
      // The Cupertino dialog takes its action color from the brand accent, not the legacy Material primary.
      return CupertinoTheme(
        data: const CupertinoThemeData(primaryColor: Brand.accent, brightness: Brightness.dark),
        child: AlertDialog.adaptive(
          title: Text(t.logoutConfirm),
          actions: [
            action(t.cancel, false),
            action(t.logout, true, key: const Key('logout-confirm'), destructive: true),
          ],
        ),
      );
    },
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
