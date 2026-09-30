import 'package:intl/intl.dart';

final _date = DateFormat('dd.MM.yy');
final _time = DateFormat('HH:mm');

/// "just now", "12 min ago", "5 h ago", "Yesterday", "3 days ago", then the
/// date. Used on posts and comments.
String relativeTime(DateTime when, DateTime now) {
  final elapsed = now.difference(when);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 7) return '${elapsed.inDays} days ago';
  return _date.format(when);
}

/// A date as the app writes it everywhere, e.g. "30.09.26".
String shortDate(DateTime when) => _date.format(when);

/// Clock time of a chat message, e.g. "09:41".
String clockTime(DateTime when) => _time.format(when);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Heading above the first chat message of a day: "Today", "Yesterday" or
/// the date.
String dayLabel(DateTime when, DateTime now) {
  if (isSameDay(when, now)) return 'Today';
  if (isSameDay(when, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return _date.format(when);
}
