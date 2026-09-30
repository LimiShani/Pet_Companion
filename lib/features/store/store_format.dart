import 'package:intl/intl.dart';

import 'data/deal.dart';
import 'store_strings.dart';

/// Formatting of money, amounts and times for the Store screens. The words
/// around the numbers come from [StoreStrings].
abstract final class StoreFormat {
  static final _date = DateFormat('dd.MM.yy');
  static final _amount = NumberFormat('#,##0.###');

  /// `₪179`, `₪39.90`: the currency's symbol, with decimals only when the
  /// amount has them.
  static String money(double amount, String currency) {
    // Decide on the rounded value, so 26.999 reads "₪27" and not "₪27.00".
    final cents = (amount * 100).round();
    final format = NumberFormat.simpleCurrency(name: currency, decimalDigits: cents % 100 == 0 ? 0 : null);
    return format.format(cents / 100);
  }

  /// The symbol of [currency], e.g. `₪`.
  static String currencySymbol(String currency) => NumberFormat.simpleCurrency(name: currency).currencySymbol;

  static String date(DateTime when) => _date.format(when);

  /// "10 kg", "500 ml", "300 units".
  static String package(PackageSize size) =>
      StoreStrings.packageSize(_amount.format(size.amount), size.unit, one: size.amount == 1);

  /// "₪18.90 per kg", "₪5.98 per litre", "₪0.07 each".
  static String unitPrice(UnitPrice price, String currency) =>
      // Never "₪0 each": the smallest amount shown is one hundredth.
      StoreStrings.unitPrice(money(price.amount < 0.01 ? 0.01 : price.amount, currency), price.kind);

  /// "3 hours ago", "Yesterday", or the date once it is over a month old.
  static String timeAgo(DateTime then, DateTime now) {
    final gap = now.difference(then);
    if (gap.inMinutes < 1) return StoreStrings.justNow;
    if (gap.inMinutes < 60) return StoreStrings.minutesAgo(gap.inMinutes);
    if (gap.inHours < 24) return StoreStrings.hoursAgo(gap.inHours);
    if (gap.inDays < 2) return StoreStrings.yesterday;
    if (gap.inDays <= 30) return StoreStrings.daysAgo(gap.inDays);
    return date(then);
  }

  /// "12.10.26 · 12 days left" while the deal runs, "No end date" when the
  /// seller gave none, "Ended 28.09.26" once it is over.
  static String ends(DateTime? expiresAt, DateTime now) {
    if (expiresAt == null) return StoreStrings.noEndDate;
    if (!expiresAt.isAfter(now)) return StoreStrings.ended(date(expiresAt));
    return StoreStrings.endsOn(date(expiresAt), _calendarDays(now, expiresAt));
  }

  /// "29.09.26 · yesterday": the day a price was checked and how long ago
  /// that was, in calendar days.
  static String checked(DateTime checkedAt, DateTime now) {
    final days = _calendarDays(checkedAt, now);
    return StoreStrings.checkedOn(date(checkedAt), days < 0 ? 0 : days);
  }

  // Whole calendar days from one day to another; hours keep this right
  // across a clock change.
  static int _calendarDays(DateTime from, DateTime to) {
    final hours = DateTime(to.year, to.month, to.day).difference(DateTime(from.year, from.month, from.day)).inHours;
    return (hours / 24).round();
  }
}
