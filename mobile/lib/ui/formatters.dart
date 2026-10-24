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
  String weekdayDate(DateTime instant) => DateFormat('EEEE, d MMMM', locale).format(toClub(instant));

  /// Today's date in the club time zone.
  DateTime clubToday() {
    final now = toClub(DateTime.now());
    return DateTime(now.year, now.month, now.day);
  }
}
