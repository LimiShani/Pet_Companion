import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../services/store/data/deal.dart';
import '../../presentation/store_strings.dart';

/// Money, amounts and times as the Store shows them, in the language on
/// screen: the numbers from [AppFormat], the words around them from the
/// strings files.
///
/// In a widget: `StoreFormat.of(context)`.
///
/// Numbers inside right-to-left text are kept in one piece with invisible
/// direction marks ("-40%" would otherwise read "40%-"). A left-to-right
/// line needs none, so the English texts stay free of them.
@immutable
class StoreFormat {
  const StoreFormat(this.l10n, this.app);

  factory StoreFormat.of(BuildContext context) =>
      StoreFormat(context.storeL10n, AppFormat.of(context));

  /// For code and tests without a screen.
  factory StoreFormat.forLocale(Locale locale) =>
      StoreFormat(lookupStoreL10n(locale), AppFormat.forLocale(locale));

  final StoreL10n l10n;
  final AppFormat app;

  bool get _leftToRight => app.localeName == 'en';

  String _tidy(String text) => _leftToRight ? stripBidiMarks(text) : text;

  /// `₪179`, `₪39.90` (Hebrew: `179 ₪`): the currency's sign, with decimals
  /// only when the amount has them.
  String money(double amount, String currency) {
    // Rounded to the cent first, so 26.999 reads "₪27" and not "₪27.00".
    final cents = (amount * 100).round();
    return _tidy(app.money(cents / 100, currency));
  }

  /// The sign of [currency], e.g. `₪`.
  String currencySymbol(String currency) =>
      NumberFormat.simpleCurrency(name: currency).currencySymbol;

  /// "12.06.25", the same in every language.
  String date(DateTime when) => app.date(when);

  /// "-40%": a discount, with its minus in front in every direction.
  String discount(int percent) => _tidy(app.percent(-percent));

  /// "10 kg", "500 ml", "300 units".
  String package(PackageSize size) => l10n.packageSize(
    app.decimal(size.amount, decimals: 3),
    size.unit,
    one: size.amount == 1,
  );

  /// "₪18.90 per kg", "₪5.98 per litre", "₪0.07 each".
  String unitPrice(UnitPrice price, String currency) =>
      // Never "₪0 each": the smallest amount shown is one hundredth.
      l10n.unitPriceOf(
        money(price.amount < 0.01 ? 0.01 : price.amount, currency),
        price.kind,
      );

  /// "3 hours ago", "Yesterday", or the date once it is over a month old.
  String timeAgo(DateTime then, DateTime now) {
    final gap = now.difference(then);
    if (gap.inMinutes < 1) return l10n.timeJustNow;
    if (gap.inMinutes < 60) return l10n.timeMinutesAgo(gap.inMinutes);
    if (gap.inHours < 24) return l10n.timeHoursAgo(gap.inHours);
    if (gap.inDays < 2) return l10n.timeYesterday;
    if (gap.inDays <= 30) return l10n.timeDaysAgo(gap.inDays);
    return date(then);
  }

  /// "12.10.26 · 12 days left" while the deal runs, "No end date" when the
  /// seller gave none, "Ended 28.09.26" once it is over.
  String ends(DateTime? expiresAt, DateTime now) {
    if (expiresAt == null) return l10n.noEndDate;
    if (!expiresAt.isAfter(now)) return l10n.endedOn(date(expiresAt));
    return l10n.endsOn(date(expiresAt), _calendarDays(now, expiresAt));
  }

  /// "29.09.26 · yesterday": the day a price was checked and how long ago
  /// that was, in calendar days.
  String checked(DateTime checkedAt, DateTime now) {
    final days = _calendarDays(checkedAt, now);
    final when = switch (days) {
      <= 0 => l10n.checkedToday,
      1 => l10n.checkedYesterday,
      _ => l10n.checkedDaysAgo(days),
    };
    return l10n.checkedOn(date(checkedAt), when);
  }

  // Whole calendar days from one day to another; hours keep this right
  // across a clock change.
  static int _calendarDays(DateTime from, DateTime to) {
    final hours = DateTime(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime(from.year, from.month, from.day)).inHours;
    return (hours / 24).round();
  }
}
