import 'package:flutter/foundation.dart';

/// Client-side checks mirror the backend rules for fast feedback; the backend remains authoritative.
class Validators {
  /// Same normalization as the backend: +998XXXXXXXXX, 998XXXXXXXXX or a 9-digit local number.
  static String? normalizePhone(String input) {
    final trimmed = input.trim();
    final hasPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (!hasPlus) {
      if (digits.length == 9) {
        digits = '998$digits';
      } else if (!(digits.length == 12 && digits.startsWith('998'))) {
        return null;
      }
    }
    if (digits.startsWith('998') && digits.length != 12) return null;
    return digits.length >= 10 && digits.length <= 15 ? '+$digits' : null;
  }

  /// Login identifier: a phone, or in debug builds a short dev login ("1", "2", "3") that the Development API accepts.
  static String? loginId(String input) {
    final phone = normalizePhone(input);
    if (phone != null || !kDebugMode) return phone;
    final short = input.trim();
    return RegExp(r'^\d{1,2}$').hasMatch(short) ? short : null;
  }

  static bool isStrongPassword(String s) =>
      s.length >= 8 && s.length <= 128 && s.contains(RegExp(r'\p{L}', unicode: true)) && s.contains(RegExp(r'\d'));

  static bool isEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
}
