import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/locale_controller.dart';

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  static const _labels = {'ru': 'Русский', 'uz': 'O‘zbekcha'};

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
            tooltip: _labels[l.languageCode],
          ),
      ],
      selected: {controller.locale.languageCode},
      onSelectionChanged: (s) => controller.set(Locale(s.first)),
    );
  }
}
