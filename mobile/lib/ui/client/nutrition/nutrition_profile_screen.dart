import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../formatters.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'ai_consent.dart';
import 'nutrition_format.dart';
import 'nutrition_widgets.dart';

/// Opens the nutrition settings; completes with the saved profile, or null when nothing was saved.
Future<NutritionProfile?> openNutritionProfile(BuildContext context, NutritionProfile profile) =>
    Navigator.of(context).push<NutritionProfile>(
      MaterialPageRoute(builder: (_) => NutritionProfileScreen(profile: profile)),
    );

/// Goal, body measurements for the daily target (Mifflin–St Jeor, computed by the server), dietary restrictions,
/// allergies and the consent to the AI service.
class NutritionProfileScreen extends StatefulWidget {
  const NutritionProfileScreen({super.key, required this.profile});
  final NutritionProfile profile;

  @override
  State<NutritionProfileScreen> createState() => _NutritionProfileScreenState();
}

class _NutritionProfileScreenState extends State<NutritionProfileScreen> {
  final _form = GlobalKey<FormState>();
  late NutritionProfile _profile = widget.profile;
  late Sex? _sex = _profile.sex;
  late DateTime? _birthDate = _profile.birthDate;
  late NutritionGoal? _goal = _profile.goal;
  late ActivityLevel? _activity = _profile.activity;
  late final Set<Allergen> _allergies = {..._profile.allergies};
  late final _height = TextEditingController(text: _num(_profile.heightCm));
  late final _weight = TextEditingController(text: _num(_profile.weightKg));
  late final _custom = TextEditingController(text: _profile.customKcalTarget?.toString() ?? '');
  late final _restrictions = TextEditingController(text: _profile.restrictions ?? '');
  bool _busy = false;
  bool _consentBusy = false;

  static String _num(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');

  static double? _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _custom.dispose();
    _restrictions.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final saved = await context.read<NutritionRepository>().updateProfile(
        NutritionProfileUpdate(
          goal: _goal,
          weightKg: _parse(_weight.text),
          heightCm: _parse(_height.text),
          activity: _activity,
          sex: _sex,
          birthDate: _birthDate,
          customKcalTarget: _custom.text.trim().isEmpty ? null : int.tryParse(_custom.text.trim()),
          restrictions: _restrictions.text.trim().isEmpty ? null : _restrictions.text.trim(),
          allergies: _allergies.toList(),
        ),
      );
      if (!mounted) return;
      showSnack(context, t.nutritionProfileSaved);
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleConsent() async {
    final t = AppLocalizations.of(context);
    if (!_profile.hasAiConsent) {
      final p = await showAiConsentSheet(context, provider: _profile.aiProvider);
      if (p != null && mounted) setState(() => _profile = p);
      return;
    }
    setState(() => _consentBusy = true);
    try {
      final p = await context.read<NutritionRepository>().revokeAiConsent();
      if (!mounted) return;
      setState(() => _profile = p);
      showSnack(context, t.aiConsentRevoked);
    } catch (e) {
      if (mounted) showSnack(context, errorText(t, e));
    } finally {
      if (mounted) setState(() => _consentBusy = false);
    }
  }

  String? _range(String v, double min, double max, {bool required = false}) {
    final t = AppLocalizations.of(context);
    if (v.trim().isEmpty) return required ? t.validationRequired : null;
    final n = _parse(v);
    if (n == null || n < min || n > max) return t.valueRange(_num(min), _num(max));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = Fmt(Localizations.localeOf(context).languageCode);
    final target = _profile.target;
    return NutritionPage(
      title: t.nutritionProfileTitle,
      subtitle: t.nutritionProfileSubtitle,
      bottom: GradientPillButton(
        key: const Key('nutrition-profile-save'),
        label: t.save,
        icon: Icons.check_rounded,
        height: 54,
        loading: _busy,
        onPressed: _save,
      ),
      children: [
        if (target != null) ...[
          _TargetCard(target: target),
          const SizedBox(height: Brand.sectionGap),
        ],
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassSectionHeader(t.nutritionGoal),
              _Chips<NutritionGoal>(
                keyPrefix: 'goal',
                values: NutritionGoal.values,
                selected: _goal,
                label: (g) => goalLabel(t, g),
                onSelected: (g) => setState(() => _goal = g),
              ),
              if (_goal == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(t.nutritionGoalPick, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                ),
              const SizedBox(height: Brand.sectionGap),
              GlassSectionHeader(t.aboutYou),
              _Chips<Sex>(
                keyPrefix: 'sex',
                values: Sex.values,
                selected: _sex,
                label: (s) => s == Sex.male ? t.genderMale : t.genderFemale,
                onSelected: (s) => setState(() => _sex = s),
              ),
              const SizedBox(height: 12),
              GlassCard(
                key: const Key('nutrition-birthdate'),
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onTap: _pickBirthDate,
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: Brand.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _birthDate == null ? t.birthDate : '${t.birthDate}: ${fmt.numericDate(_birthDate!)}',
                        style: const TextStyle(color: Brand.textPrimary, fontSize: 15),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Brand.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('nutrition-height'),
                      controller: _height,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(labelText: t.heightCm),
                      validator: (v) => _range(v ?? '', 100, 250),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('nutrition-weight'),
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(labelText: t.weightKg),
                      validator: (v) => _range(v ?? '', 25, 350),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Brand.sectionGap),
              GlassSectionHeader(t.activityLevel),
              GlassList(
                children: [
                  for (final a in ActivityLevel.values)
                    _ChoiceRow(
                      key: Key('activity-${a.name}'),
                      title: activityLabel(t, a),
                      subtitle: activityHint(t, a),
                      selected: _activity == a,
                      onTap: () => setState(() => _activity = a),
                    ),
                ],
              ),
              const SizedBox(height: Brand.sectionGap),
              GlassSectionHeader(t.customTarget),
              TextFormField(
                key: const Key('nutrition-custom-kcal'),
                controller: _custom,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: t.customTargetHint, suffixText: t.unitKcal),
                validator: (v) => _range(v ?? '', 800, 6000),
              ),
              const SizedBox(height: Brand.sectionGap),
              GlassSectionHeader(t.restrictions),
              TextFormField(
                key: const Key('nutrition-restrictions'),
                controller: _restrictions,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(labelText: t.restrictionsHint),
              ),
              const SizedBox(height: 8),
              GlassSectionHeader(t.allergies),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in Allergen.values)
                    FilterChip(
                      key: Key('allergy-${a.name}'),
                      label: Text(allergenLabel(t, a)),
                      selected: _allergies.contains(a),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _allergies.contains(a) ? Colors.white : Brand.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      selectedColor: Brand.red.withValues(alpha: 0.35),
                      side: BorderSide(
                        color: _allergies.contains(a) ? Brand.red.withValues(alpha: 0.6) : Brand.glassStroke,
                      ),
                      shape: const StadiumBorder(),
                      onSelected: (on) => setState(() => on ? _allergies.add(a) : _allergies.remove(a)),
                    ),
                ],
              ),
              const SizedBox(height: Brand.sectionGap),
              GlassSectionHeader(t.aiAnalysis),
              GlassCard(
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconPlate(icon: Icons.auto_awesome_rounded, color: Brand.accent, iconColor: Brand.clock),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            !_profile.aiAvailable
                                ? t.errAiNotConfigured
                                : _profile.hasAiConsent
                                ? t.aiConsentGiven(fmt.numericDate(_profile.aiConsentAt!.toLocal()))
                                : t.aiConsentNotGiven,
                            style: TextStyle(color: Brand.textSecondary, fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    if (_profile.aiAvailable) ...[
                      const SizedBox(height: 12),
                      GlassPillButton(
                        key: const Key('ai-consent-toggle'),
                        label: _profile.hasAiConsent ? t.aiConsentRevoke : t.aiConsentGive,
                        icon: _profile.hasAiConsent ? Icons.block_rounded : Icons.check_rounded,
                        onPressed: _consentBusy ? null : _toggleConsent,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target});
  final NutritionTarget target;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = NutritionFmt(t, Localizations.localeOf(context).languageCode);
    return GlassCard(
      radius: Brand.radiusHero,
      glow: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dailyTarget, style: TextStyle(color: Brand.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${fmt.kcalExact(target.kcal.toDouble())} ${t.unitKcal}',
            style: const TextStyle(color: Brand.textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          ),
          const SizedBox(height: 4),
          Text(
            '${t.proteinShort} ${target.proteinG} ${t.unitG} · ${t.fatShort} ${target.fatG} ${t.unitG} · '
            '${t.carbsShort} ${target.carbsG} ${t.unitG}',
            style: const TextStyle(color: Brand.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            target.method == 'Custom'
                ? t.targetCustomNote
                : t.targetMethodNote(
                    fmt.kcalExact((target.bmr ?? 0).toDouble()),
                    fmt.kcalExact((target.tdee ?? 0).toDouble()),
                  ),
            style: TextStyle(color: Brand.textSecondary, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// One of a few values as chips; nothing is preselected when the client has not chosen yet.
class _Chips<T extends Enum> extends StatelessWidget {
  const _Chips({
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final String keyPrefix;
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        ChoiceChip(
          key: Key('$keyPrefix-${v.name}'),
          selected: v == selected,
          showCheckmark: false,
          label: Text(label(v)),
          labelStyle: TextStyle(color: v == selected ? Colors.white : Brand.textSecondary, fontWeight: FontWeight.w600),
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          selectedColor: Brand.accent.withValues(alpha: 0.35),
          side: BorderSide(color: v == selected ? Brand.accent.withValues(alpha: 0.6) : Brand.glassStroke),
          shape: const StadiumBorder(),
          onSelected: (_) => onSelected(v),
        ),
    ],
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({super.key, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Brand.accent : Colors.transparent,
                border: Border.all(color: selected ? Brand.accent : Brand.glassStroke, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    ),
  );
}
