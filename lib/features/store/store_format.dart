import 'package:intl/intl.dart';

/// Text formatting shared by the Store screens.
abstract final class StoreFormat {
  static final _date = DateFormat('dd.MM.yy');

  /// `₪179`, `₪39.90`: the currency's symbol, with decimals only when the
  /// amount has them.
  static String money(double amount, String currency) {
    final whole = amount == amount.roundToDouble();
    final format = NumberFormat.simpleCurrency(name: currency, decimalDigits: whole ? 0 : null);
    return format.format(amount);
  }

  static String date(DateTime when) => _date.format(when);

  /// "3 hours ago", "Yesterday", or the date once it is over a month old.
  static String timeAgo(DateTime then, DateTime now) {
    final gap = now.difference(then);
    if (gap.inMinutes < 1) return 'Just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
    if (gap.inHours < 24) return gap.inHours == 1 ? '1 hour ago' : '${gap.inHours} hours ago';
    if (gap.inDays < 2) return 'Yesterday';
    if (gap.inDays <= 30) return '${gap.inDays} days ago';
    return date(then);
  }

  /// "12.10.26 · 12 days left" while the deal runs, "No end date" when the
  /// seller gave none, "Ended 28.09.26" once it is over.
  static String ends(DateTime? expiresAt, DateTime now) {
    if (expiresAt == null) return 'No end date';
    if (!expiresAt.isAfter(now)) return 'Ended ${date(expiresAt)}';
    final days = DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inHours;
    // Whole calendar days; hours keep this right across a clock change.
    final left = (days / 24).round();
    final tail = switch (left) {
      0 => 'ends today',
      1 => '1 day left',
      _ => '$left days left',
    };
    return '${date(expiresAt)} · $tail';
  }
}
