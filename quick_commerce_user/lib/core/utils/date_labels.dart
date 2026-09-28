/// Date and clock labels in the app's display format. Pure Dart, so Domain can
/// use it too — the project has no `intl` dependency and these are the only
/// formats the UI actually needs.
abstract final class DateLabels {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', //
    'Thursday', 'Friday', 'Saturday',
  ];

  static const _weekdaysShort = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  static String month(int month1Based) => _months[(month1Based - 1) % 12];

  /// `0` = Sunday, matching the backend's `daysOfWeek` convention.
  static String weekday(int sundayZero) => _weekdays[sundayZero % 7];

  static String weekdayShort(int sundayZero) => _weekdaysShort[sundayZero % 7];

  /// `3 Sep`
  static String dayMonth(DateTime date) =>
      '${date.day} ${month(date.month)}';

  /// `3 Sep 2026`
  static String dayMonthYear(DateTime date) =>
      '${date.day} ${month(date.month)} ${date.year}';

  /// `7:05 AM`
  static String clock(DateTime time) =>
      _clock(time.hour, time.minute);

  /// `3 Sep, 7:05 AM`
  static String dayMonthClock(DateTime time) =>
      '${dayMonth(time)}, ${clock(time)}';

  /// `3 Sep 2026, 7:05 AM`
  static String full(DateTime time) =>
      '${dayMonthYear(time)}, ${clock(time)}';

  /// `"07:00"` (the backend's 24h wire format) → `7:00 AM`. Returns the input
  /// unchanged if it is not the expected shape, so a bad value is visible
  /// rather than silently replaced with a wrong time.
  static String clockFromWire(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return hhmm;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return hhmm;
    return _clock(hour, minute);
  }

  static String _clock(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Calendar-day difference, ignoring the time of day — `Today`/`Tomorrow`
  /// must not flip just because one value is 23:00 and the other 01:00.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// `Today` / `Tomorrow` / `Yesterday`, else `Mon, 3 Sep`.
  static String relativeDay(DateTime date, {DateTime? now}) {
    final days = daysBetween(now ?? DateTime.now(), date);
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    return '${weekdayShort(date.weekday % 7)}, ${dayMonth(date)}';
  }
}
