import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/nutrition_models.dart';
import '../../../data/nutrition_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'ai_consent.dart';
import 'nutrition_format.dart';

Future<void> openConsultant(BuildContext context, {NutritionProfile? profile}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ConsultantScreen(profile: profile)));

/// Chat with the AI nutrition consultant. The server answers from the client's real data (profile, diary, scans,
/// workouts); the conversation lives in this screen only.
class ConsultantScreen extends StatefulWidget {
  const ConsultantScreen({super.key, this.profile});
  final NutritionProfile? profile;

  @override
  State<ConsultantScreen> createState() => _ConsultantScreenState();
}

class _ConsultantScreenState extends State<ConsultantScreen> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final NutritionProfile? _profile = widget.profile;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send([String? text]) async {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty || _busy) return;
    _input.clear();
    setState(() => _messages.add(ChatMessage(fromUser: true, text: question)));
    await _ask();
  }

  Future<void> _ask() async {
    final lang = Localizations.localeOf(context).languageCode;
    final repo = context.read<NutritionRepository>();
    setState(() {
      _busy = true;
      _error = null;
    });
    _toBottom();
    try {
      final reply = await withAiConsent(context, _profile, () => repo.ask(List.of(_messages), lang));
      if (!mounted) return;
      if (reply == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() => _messages.add(ChatMessage(fromUser: false, text: reply.text, dataUsed: reply.dataUsed)));
      _toBottom();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final suggestions = [
      t.askEatenToday,
      t.askDinner,
      t.askPlov,
      t.askProteinLeft,
      t.askWhyOver,
      t.askCompare,
    ];
    return Scaffold(
      backgroundColor: Brand.background,
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, 8),
                child: Row(
                  children: [
                    GlassCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      iconSize: 18,
                      tooltip: t.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.consultantTitle,
                            style: const TextStyle(color: Brand.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          Text(t.consultantSubtitle, style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const Key('consultant-chat'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Brand.sidePadding, 8, Brand.sidePadding, 12),
                  children: [
                    if (_messages.isEmpty) ...[
                      GlassCard(
                        radius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.forum_rounded, color: Brand.clock),
                            const SizedBox(height: 10),
                            Text(t.consultantIntro, style: const TextStyle(color: Brand.textPrimary, fontSize: 14, height: 1.4)),
                            const SizedBox(height: 8),
                            Text(t.notMedicalAdvice, style: TextStyle(color: Brand.textTertiary, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < suggestions.length; i++)
                            ActionChip(
                              key: Key('suggestion-$i'),
                              label: Text(suggestions[i]),
                              labelStyle: const TextStyle(color: Brand.textPrimary, fontSize: 13),
                              backgroundColor: Colors.white.withValues(alpha: 0.06),
                              side: BorderSide(color: Brand.glassStroke),
                              shape: const StadiumBorder(),
                              onPressed: () => _send(suggestions[i]),
                            ),
                        ],
                      ),
                    ],
                    for (final m in _messages) _Bubble(message: m),
                    if (_busy) const _Typing(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          key: const Key('consultant-error'),
                          children: [
                            Text(
                              errorText(t, _error!),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Brand.redText, fontSize: 13),
                            ),
                            TextButton(onPressed: _ask, child: Text(t.retry)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Brand.sidePadding,
                  4,
                  Brand.sidePadding,
                  MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 12,
                ),
                child: GlassCard(
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('consultant-input'),
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(color: Brand.textPrimary),
                          decoration: InputDecoration(
                            hintText: t.consultantHintInput,
                            filled: false,
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('consultant-send'),
                        tooltip: t.send,
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.arrow_upward_rounded, color: Brand.accent),
                      ),
                    ],
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (user)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: Brand.buttonGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
                  ),
                )
              else
                GlassCard(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: SelectableText(
                    message.text,
                    style: const TextStyle(color: Brand.textPrimary, fontSize: 15, height: 1.4),
                  ),
                ),
              if (!user && message.dataUsed.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6),
                  child: Text(
                    t.basedOn(message.dataUsed.map((d) => dataUsedLabel(t, d)).join(', ')),
                    style: TextStyle(color: Brand.textTertiary, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three pulsing dots while the consultant thinks.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    key: const Key('consultant-typing'),
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Semantics(
          label: AppLocalizations.of(context).consultantTyping,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Opacity(
                    opacity: 0.3 + 0.7 * (1 - ((_c.value * 3 - i) % 3 - 0.5).abs().clamp(0.0, 1.0)),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Brand.clock, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
