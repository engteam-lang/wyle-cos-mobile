import 'package:intl/intl.dart';

class FormatUtils {
  FormatUtils._();

  /// Format AED currency: "AED 1,250" or "AED 14,000"
  static String aed(double? amount) {
    if (amount == null) return '';
    return 'AED ${NumberFormat('#,##0', 'en_US').format(amount)}';
  }

  /// Format minutes as hours string: 270 → "4.5h"
  static String minutesToHours(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes / 60;
    if (h == h.truncate()) return '${h.truncate()}h';
    return '${h.toStringAsFixed(1)}h';
  }

  /// Format days until due as a label
  static String daysLabel(int days) {
    if (days == 0) return 'TODAY';
    if (days == 1) return '1 DAY';
    return '$days DAYS';
  }

  /// Short days label for compact cards
  static String daysShort(int days) {
    if (days == 0) return 'TODAY';
    return '$days';
  }

  /// Format obligation type to a readable string
  static String obligationType(String type) {
    return type.replaceAll('_', ' ').split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Capitalize first letter
  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Truncate with ellipsis
  static String truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }

  /// Format number with commas
  static String number(num value) {
    return NumberFormat('#,##0', 'en_US').format(value);
  }

  /// Reliability display: 99 → "99%"
  static String percentage(num value) => '${value.toStringAsFixed(0)}%';
}

class DateUtils {
  DateUtils._();

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String timeString() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  /// Returns 'morning' or 'evening'
  static String briefTimeOfDay() {
    final h = DateTime.now().hour;
    return h >= 17 ? 'evening' : 'morning';
  }

  /// Key like "morning_2024-01-15" used to deduplicate briefs
  static String briefKey() {
    final tod = briefTimeOfDay();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${tod}_$date';
  }

  /// Check if brief key is stale (different from the current period)
  static bool isBriefStale(String? lastBriefKey) {
    return lastBriefKey == null || lastBriefKey != briefKey();
  }

  /// Format a date to "Mon 15 Jan"
  static String shortDate(DateTime dt) {
    return DateFormat('EEE d MMM').format(dt);
  }

  /// Format a date to "15 Jan 2024"
  static String mediumDate(DateTime dt) {
    return DateFormat('d MMM yyyy').format(dt);
  }

  /// Format a time to "09:30 AM"
  static String shortTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  /// Relative time: "2 hours ago", "in 3 days"
  static String relative(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) {
      final d = diff.inDays.abs();
      if (d > 0) return '$d day${d == 1 ? '' : 's'} ago';
      final h = diff.inHours.abs();
      if (h > 0) return '$h hour${h == 1 ? '' : 's'} ago';
      return 'just now';
    } else {
      final d = diff.inDays;
      if (d > 0) return 'in $d day${d == 1 ? '' : 's'}';
      final h = diff.inHours;
      if (h > 0) return 'in $h hour${h == 1 ? '' : 's'}';
      return 'soon';
    }
  }
}
