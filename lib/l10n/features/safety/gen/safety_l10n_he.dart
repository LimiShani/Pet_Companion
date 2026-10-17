// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'safety_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class SafetyL10nHe extends SafetyL10n {
  SafetyL10nHe([String locale = 'he']) : super(locale);

  @override
  String get emergencyLead => 'קודם מתקשרים. השורות למטה עוזרות להחליט ולהתכונן.';

  @override
  String get confirmOpen => 'כדאי להתקשר ולוודא שפתוח';

  @override
  String get urgentRow => 'זה דחוף?';

  @override
  String get urgentRowNote => 'סימנים שמחייבים לנסוע לווטרינר עכשיו';

  @override
  String foodRow(String name) {
    return 'זה בטוח עבור \u2068$name\u2069?';
  }

  @override
  String get foodRowNote => 'מזונות וצמחים: בטוח, רק מעט או מסוכן';

  @override
  String get lostRow => 'מצב אבדה';

  @override
  String get lostRowNote => 'הודעה לשכנים וכרטיס לשיתוף';

  @override
  String get lostRowCardNote => 'כרטיס לשיתוף';

  @override
  String lostRowActive(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דיווחים',
      two: 'שני דיווחים',
      one: 'דיווח אחד',
      zero: 'עוד אין דיווחים',
    );
    return 'מחפשים את \u2068$name\u2069 · $_temp0';
  }

  @override
  String lostRowActiveNote(String when) {
    return 'הפעם האחרונה שראינו: \u2068$when\u2069';
  }

  @override
  String get findClinicNote => 'מרפאות חירום באזור';
}
