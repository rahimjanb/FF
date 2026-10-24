import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/validators.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = {};

  @override
  void dispose() {
    for (final c in [_phone, _first, _last, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().register(
        phone: Validators.normalizePhone(_phone.text)!,
        password: _password.text,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(AppLocalizations.of(context), e);
        if (e is ApiException) _fieldErrors = e.fields;
      });
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _server(String field) => _fieldErrors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.registerTitle, style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 6),
                      Text(t.registerSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _first,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: t.firstName),
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.validationRequired : _server('FirstName'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _last,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.familyName],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: t.lastName),
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.validationRequired : _server('LastName'),
                      ),
                      const SizedBox(height: 12),
                      PhoneField(controller: _phone),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: t.password, helperText: t.validationPassword),
                        validator: (v) =>
                            !Validators.isStrongPassword(v ?? '') ? t.validationPassword : _server('Password'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(labelText: t.confirmPassword),
                        validator: (v) => v != _password.text ? t.validationPasswordMatch : null,
                      ),
                      const SizedBox(height: 14),
                      Text(t.smsNotice, style: Theme.of(context).textTheme.bodySmall),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(t.signUp),
                      ),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.haveAccount)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
