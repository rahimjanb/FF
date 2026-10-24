import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/language_switch.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().login(Validators.loginId(_phone.text)!, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerRight, child: LanguageSwitch()),
                    const SizedBox(height: 24),
                    const _Logo(),
                    const SizedBox(height: 32),
                    Text(t.loginTitle, style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 6),
                    Text(t.loginSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15)),
                    const SizedBox(height: 28),
                    PhoneField(controller: _phone, allowDevLogin: true),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: t.password,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? t.validationRequired : null,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _error == null
                          ? const SizedBox(height: 20)
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                            ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(t.signIn),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text(t.noAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, this.allowDevLogin = false});
  final TextEditingController controller;
  final bool allowDevLogin;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: t.phone,
        hintText: '+998 90 123 45 67',
        prefixIcon: const Icon(Icons.phone_iphone_rounded),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return t.validationRequired;
        return (allowDevLogin ? Validators.loginId(v) : Validators.normalizePhone(v)) == null
            ? t.validationPhone
            : null;
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.bolt_rounded, color: AppColors.accentInk, size: 28),
      ),
      const SizedBox(width: 12),
      Text('Fitness Formulasi', style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
