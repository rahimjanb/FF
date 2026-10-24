import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Password change. With [forced] it is the only screen available after signing in with a temporary
/// password issued by the club; the backend blocks every other endpoint until it is done.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      showSnack(context, t.passwordChanged);
      if (!widget.forced) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.forced,
        title: widget.forced ? null : Text(t.changePassword),
        actions: [
          if (widget.forced)
            TextButton(onPressed: () => context.read<SessionController>().logout(), child: Text(t.logout)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.forced) ...[
                      const Icon(Icons.lock_reset_rounded, size: 44, color: AppColors.accent),
                      const SizedBox(height: 16),
                      Text(t.changePasswordForcedTitle, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        t.changePasswordForcedText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: t.currentPassword),
                      validator: (v) => (v == null || v.isEmpty) ? t.validationRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _next,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: t.newPassword, helperText: t.validationPassword),
                      validator: (v) {
                        if (!Validators.isStrongPassword(v ?? '')) return t.validationPassword;
                        if (v == _current.text) return t.errorPasswordUnchanged;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(labelText: t.confirmPassword),
                      validator: (v) => v != _next.text ? t.validationPasswordMatch : null,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                      ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(widget.forced ? t.save : t.changePassword),
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
