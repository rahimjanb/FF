import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/locale_controller.dart';
import '../theme.dart';
import 'glass.dart';

const _languageNames = {'ru': 'Русский', 'uz': 'O‘zbekcha'};

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        for (final l in LocaleController.supported)
          ButtonSegment(
            value: l.languageCode,
            label: Text(l.languageCode.toUpperCase()),
            tooltip: _languageNames[l.languageCode],
          ),
      ],
      selected: {controller.locale.languageCode},
      onSelectionChanged: (s) => controller.set(Locale(s.first)),
    );
  }
}

/// RU / UZ glass capsule (40 high) with a gradient thumb under the selected language. Each segment is 52×48 to tap.
class GlassLanguageSwitch extends StatelessWidget {
  const GlassLanguageSwitch({super.key});

  static const _segment = 52.0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    final codes = [for (final l in LocaleController.supported) l.languageCode];
    final index = codes.indexOf(controller.locale.languageCode);
    return SizedBox(
      width: _segment * codes.length + 8,
      height: 48,
      child: Stack(
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: GlassCard(
              radius: 20,
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: _segment * index,
                    top: 0,
                    bottom: 0,
                    width: _segment,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: Brand.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Brand.accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (var i = 0; i < codes.length; i++)
                  Semantics(
                    button: true,
                    selected: i == index,
                    label: _languageNames[codes[i]],
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i == index) return;
                        HapticFeedback.selectionClick();
                        controller.set(Locale(codes[i]));
                      },
                      child: SizedBox(
                        width: _segment,
                        height: 48,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: i == index ? Colors.white : Brand.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            child: Text(codes[i].toUpperCase()),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
