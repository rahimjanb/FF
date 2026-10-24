import 'package:intl/intl.dart';

import '../core/config.dart';

/// Formatting helpers bound to the current locale. Instants are shown in club time (Asia/Tashkent).
class Fmt {
  Fmt(this.locale);
  final String locale;

  DateTime toClub(DateTime instant) => instant.toUtc().add(AppConfig.clubUtcOffset);

  String date(DateTime d) => DateFormat('d MMMM y', locale).format(d);
  String shortDate(DateTime d) => DateFormat('d MMM', locale).format(d);
  String time(DateTime instant) => DateFormat('HH:mm').format(toClub(instant));
  String dateTime(DateTime instant) => DateFormat('d MMM, HH:mm', locale).format(toClub(instant));

  /// Uzbek number as "+998 90 123 45 67"; other formats are returned unchanged.
  static String phone(String e164) {
    final m = RegExp(r'^\+998(\d{2})(\d{3})(\d{2})(\d{2})$').firstMatch(e164);
    return m == null ? e164 : '+998 ${m[1]} ${m[2]} ${m[3]} ${m[4]}';
  }

  /// Calendar date as ДД.ММ.ГГГГ.
  String numericDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

  /// Whole amount with a space between thousands, e.g. "1 200 000 сум".
  String money(num amount, String currency) => '${NumberFormat('#,##0', 'ru').format(amount.round())} $currency';

  String weekdayDate(DateTime instant) => DateFormat('EEEE, d MMMM', locale).format(toClub(instant));

  /// Today's date in the club time zone.
  DateTime clubToday() {
    final now = toClub(DateTime.now());
    return DateTime(now.year, now.month, now.day);
  }
}
