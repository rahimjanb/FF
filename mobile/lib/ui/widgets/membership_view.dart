import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';

Color membershipColor(MembershipEffectiveStatus s) => switch (s) {
  MembershipEffectiveStatus.active => AppColors.accent,
  MembershipEffectiveStatus.upcoming || MembershipEffectiveStatus.frozen => AppColors.blue,
  MembershipEffectiveStatus.exhausted => AppColors.orange,
  MembershipEffectiveStatus.cancelled => AppColors.red,
  MembershipEffectiveStatus.expired => AppColors.textSecondary,
};

String membershipStatusText(AppLocalizations t, MembershipEffectiveStatus s) => switch (s) {
  MembershipEffectiveStatus.active => t.statusActive,
  MembershipEffectiveStatus.upcoming => t.statusUpcoming,
  MembershipEffectiveStatus.expired => t.statusExpired,
  MembershipEffectiveStatus.exhausted => t.statusExhausted,
  MembershipEffectiveStatus.frozen => t.statusFrozen,
  MembershipEffectiveStatus.cancelled => t.statusCancelled,
};
