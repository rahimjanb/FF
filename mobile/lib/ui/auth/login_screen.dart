import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/validators.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/login_history.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/language_switch.dart';
import 'register_screen.dart';

/// Actions without a backend or plugin yet; kept in one place and shown only when [AppConfig.showUpcoming].
abstract final class _Stub {
  /// Biometric sign-in needs a credential kept behind Face ID / Touch ID, which the app does not store yet.
  static void faceId(BuildContext context) => showSnack(context, AppLocalizations.of(context).faceIdSoon);
}

final _spots = [
  GlassSpot(right: -70, top: 40, size: const Size(300, 280), color: Brand.accent.withValues(alpha: 0.42)),
  GlassSpot(left: -150, top: 220, size: const Size(320, 320), color: Brand.glowBlue.withValues(alpha: 0.6)),
  GlassSpot(right: -120, top: 420, size: const Size(280, 260), color: Brand.glowCyan.withValues(alpha: 0.35)),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _busy = false;
  bool _obscure = true;
  bool _faceId = false;
  String? _phoneError;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final f in [_phoneFocus, _passwordFocus]) {
      f.addListener(() => setState(() {}));
    }
    _restore();
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _shake.dispose();
    super.dispose();
  }

  /// Prefills the last login on this device; Face ID is offered only to returning users with biometrics set up.
  Future<void> _restore() async {
    final last = await LoginHistory.lastLogin();
    final biometrics = last != null && await LoginHistory.biometricsAvailable();
    if (!mounted) return;
    setState(() {
      _faceId = biometrics;
      if (last != null && _phone.text.isEmpty) _phone.text = UzPhoneFormatter.format(last);
    });
  }

  bool get _filled => _phone.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _changed() => setState(() => _phoneError = _error = null);

  void _fail() {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    if (_busy || !_filled) return;
    final t = AppLocalizations.of(context);
    final login = Validators.loginId(_phone.text);
    setState(() {
      _phoneError = login == null ? t.validationPhone : null;
      _error = null;
    });
    if (login == null) return _fail();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<SessionController>().login(login, _password.text);
      await LoginHistory.remember(login);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(AppLocalizations.of(context), e));
      _fail();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() => showGlassSheet<void>(
    context,
    builder: (context) {
      final t = AppLocalizations.of(context);
      return Column(
        key: const Key('forgot-password-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconPlate(icon: Icons.lock_reset_rounded, color: Brand.accent, iconColor: Brand.clock),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  t.forgotPasswordTitle,
                  style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.forgotPasswordText, style: TextStyle(color: Brand.textSecondary, fontSize: 15, height: 1.4)),
          const SizedBox(height: 22),
          GradientPillButton(label: t.close, height: 52, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return GlassBackground(
      spots: _spots,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, c) {
              final top = MediaQuery.paddingOf(context).top;
              // While typing the language switch and the hero give way to the form; otherwise the hero keeps 80 pt.
              final switchRow = keyboard ? 0.0 : 56.0;
              final panelMax = math.max(0.0, c.maxHeight - top - switchRow - (keyboard ? 0 : 80));
              return Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(height: top + switchRow),
                      const Expanded(child: _Hero()),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: panelMax),
                        child: _GlassPanel(child: _form(t, keyboard)),
                      ),
                    ],
                  ),
                  if (!keyboard) Positioned(top: top + 4, right: 20, child: const GlassLanguageSwitch()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form(AppLocalizations t, bool keyboard) {
    final bottom = keyboard ? 16.0 : math.max(MediaQuery.paddingOf(context).bottom, 20.0);
    const fieldText = TextStyle(color: Brand.textPrimary, fontSize: 16, letterSpacing: 0);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Brand.sidePadding, keyboard ? 20 : 28, Brand.sidePadding, bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
              child: child,
            ),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.loginTitle,
                    style: const TextStyle(
                      color: Brand.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(t.loginSubtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 15)),
                  const SizedBox(height: 22),
                  _GlassField(
                    focused: _phoneFocus.hasFocus,
                    invalid: _phoneError != null || _error != null,
                    error: _phoneError,
                    children: [
                      Icon(Icons.phone_iphone_outlined, color: Brand.textSecondary, size: 22),
                      const SizedBox(width: 12),
                      const Text(
                        '+998',
                        style: TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('login-phone'),
                          controller: _phone,
                          focusNode: _phoneFocus,
                          style: fieldText,
                          cursorColor: Brand.accent,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [UzPhoneFormatter()],
                          autofillHints: const [AutofillHints.telephoneNumber],
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(t.phoneNumberHint),
                          onChanged: (v) {
                            _changed();
                            // The iOS phone pad has no «Next» key: a complete number moves on to the password.
                            if (v.replaceAll(' ', '').length == 9 && _password.text.isEmpty) {
                              _passwordFocus.requestFocus();
                            }
                          },
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _GlassField(
                    focused: _passwordFocus.hasFocus,
                    invalid: _error != null,
                    error: _error,
                    trailingInset: true,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: Brand.textSecondary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('login-password'),
                          controller: _password,
                          focusNode: _passwordFocus,
                          style: fieldText,
                          cursorColor: Brand.accent,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          decoration: _fieldDecoration(t.password),
                          onChanged: (_) => _changed(),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      IconButton(
                        key: const Key('toggle-password'),
                        tooltip: _obscure ? t.showPassword : t.hidePassword,
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        color: Brand.textSecondary,
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _LinkButton(
                      key: const Key('forgot-password'),
                      label: t.forgotPassword,
                      weight: FontWeight.w500,
                      onPressed: _forgotPassword,
                    ),
                  ),
                  GradientPillButton(
                    key: const Key('login-submit'),
                    label: t.signIn,
                    icon: Icons.arrow_forward_rounded,
                    height: 56,
                    fontSize: 17,
                    loading: _busy,
                    onPressed: _filled ? _submit : null,
                  ),
                  // While typing only the fields and the button stay, so the keyboard never covers them.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: keyboard
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_faceId && AppConfig.showUpcoming) ...[
                                const SizedBox(height: 16),
                                _OrDivider(t.orDivider),
                                const SizedBox(height: 14),
                                _FaceIdButton(label: t.signInWithFaceId, onTap: () => _Stub.faceId(context)),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(t.noAccountQuestion, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
                                  _LinkButton(
                                    key: const Key('open-register'),
                                    label: t.registerLink,
                                    weight: FontWeight.w600,
                                    onPressed: () =>
                                        Navigator.of(context)
                                            .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Brand.textTertiary, fontSize: 16, letterSpacing: 0),
    isCollapsed: true,
    filled: false,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
  );
}

/// Keeps up to 9 local digits as «XX XXX XX XX» (the +998 prefix is shown next to the field). An autofilled or
/// pasted +998 number loses its country code; backspace over a space removes the digit before it.
class UzPhoneFormatter extends TextInputFormatter {
  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String _group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5 || i == 7) b.write(' ');
      b.write(digits[i]);
    }
    return b.toString();
  }

  static String format(String input) {
    var digits = _digits(input);
    if (digits.length > 9 && digits.startsWith('998')) digits = digits.substring(3);
    return _group(digits.length > 9 ? digits.substring(0, 9) : digits);
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final end = newValue.selection.end;
    var digits = _digits(newValue.text);
    var cursor = _digits(newValue.text.substring(0, end < 0 ? newValue.text.length : end)).length;
    if (newValue.text.length < oldValue.text.length && digits == _digits(oldValue.text) && cursor > 0) {
      digits = digits.substring(0, cursor - 1) + digits.substring(cursor);
      cursor--;
    }
    if (digits.length > 9 && digits.startsWith('998')) {
      digits = digits.substring(3);
      cursor = math.max(0, cursor - 3);
    }
    if (digits.length > 9) digits = digits.substring(0, 9);
    cursor = math.min(cursor, digits.length);
    final text = _group(digits);
    var offset = 0;
    for (var seen = 0; offset < text.length && seen < cursor; offset++) {
      if (text[offset] != ' ') seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Logo with the club caption over three faint concentric rings; shrinks and then hides as the form takes the space.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final h = c.maxHeight;
      final caption = h >= 110;
      final logo = (caption ? h - 56 : h - 12).clamp(0.0, 54.0);
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final (d, a) in const [(460.0, 0.05), (340.0, 0.07), (220.0, 0.09)])
            IgnorePointer(
              child: OverflowBox(
                maxWidth: d,
                maxHeight: d,
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: a)),
                  ),
                ),
              ),
            ),
          if (logo >= 24)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/ff-logo-white.png',
                  height: logo,
                  fit: BoxFit.contain,
                  semanticLabel: 'Fitness Formula',
                ),
                if (caption) ...[
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).clubApp,
                    style: TextStyle(
                      color: Brand.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ],
            ),
        ],
      );
    },
  );
}

/// Form sheet pinned to the bottom: radius 36 on top, white 10% → 3% glass, blur and a stroke fading down the sides.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  static const _radius = BorderRadius.vertical(top: Radius.circular(36));

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: _radius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 40,
          offset: const Offset(0, -10),
          blurStyle: BlurStyle.outer,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: CustomPaint(
          foregroundPainter: const _TopStrokePainter(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)],
              ),
            ),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    ),
  );
}

class _TopStrokePainter extends CustomPainter {
  const _TopStrokePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0)],
        stops: [0, math.min(1, 90 / size.height)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect.deflate(0.5),
        topLeft: const Radius.circular(36),
        topRight: const Radius.circular(36),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TopStrokePainter oldDelegate) => false;
}

/// 56 high input row: white 6% fill, accent outline with a soft glow when focused, red outline and text on error.
class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.focused,
    required this.invalid,
    this.error,
    this.trailingInset = false,
    required this.children,
  });
  final bool focused, invalid;
  final String? error;

  /// The row ends with an icon button that brings its own padding.
  final bool trailingInset;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final border = invalid
        ? Brand.red
        : focused
        ? Brand.accent.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          padding: EdgeInsets.only(left: 16, right: trailingInset ? 4 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              if (focused)
                BoxShadow(
                  color: (invalid ? Brand.red : Brand.accent).withValues(alpha: 0.25),
                  blurRadius: 16,
                  blurStyle: BlurStyle.outer,
                ),
            ],
          ),
          child: Row(children: children),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(error!, style: const TextStyle(color: Brand.redText, fontSize: 12)),
                ),
        ),
      ],
    );
  }
}

/// Accent text action with a 44 pt touch target.
class _LinkButton extends StatelessWidget {
  const _LinkButton({super.key, required this.label, required this.weight, required this.onPressed});
  final String label;
  final FontWeight weight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: Brand.accent,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    child: Text(
      label,
      style: TextStyle(color: Brand.accent, fontSize: 14, fontWeight: weight),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.12)));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: TextStyle(color: Brand.textTertiary, fontSize: 13)),
        ),
        line,
      ],
    );
  }
}

/// Glass capsule (52 high) with a scan-face glyph.
class _FaceIdButton extends StatelessWidget {
  const _FaceIdButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
    child: GlassCard(
      key: const Key('face-id'),
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomPaint(size: Size.square(24), painter: _FaceIdGlyph()),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Corner brackets with eyes, nose and a smile, drawn on a 24×24 grid.
class _FaceIdGlyph extends CustomPainter {
  const _FaceIdGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = Brand.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (x, y) in const [(1.0, 1.0), (23.0, 1.0), (1.0, 23.0), (23.0, 23.0)]) {
      final dx = x < 12 ? 1.0 : -1.0, dy = y < 12 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * 6)
          ..lineTo(x, y + dy * 2.5)
          ..quadraticBezierTo(x, y, x + dx * 2.5, y)
          ..lineTo(x + dx * 6, y),
        p,
      );
    }
    canvas.drawLine(const Offset(8, 8.5), const Offset(8, 10.5), p);
    canvas.drawLine(const Offset(16, 8.5), const Offset(16, 10.5), p);
    canvas.drawPath(
      Path()
        ..moveTo(12, 8.5)
        ..lineTo(12, 13)
        ..lineTo(11, 13),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8.5, 16)
        ..quadraticBezierTo(12, 18.8, 15.5, 16),
      p,
    );
  }

  @override
  bool shouldRepaint(_FaceIdGlyph oldDelegate) => false;
}

class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller});
  final TextEditingController controller;

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
        return Validators.normalizePhone(v) == null ? t.validationPhone : null;
      },
    );
  }
}
