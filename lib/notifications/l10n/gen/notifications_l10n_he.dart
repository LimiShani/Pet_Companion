// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'notifications_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class NotificationsL10nHe extends NotificationsL10n {
  NotificationsL10nHe([String locale = 'he']) : super(locale);

  @override
  String title(String pet) {
    return 'PetLoop · \u2068$pet\u2069';
  }

  @override
  String mealBody(String meal) {
    return '\u2068$meal\u2069 · זמן להאכיל';
  }

  @override
  String get walkFallback => 'זמן לטיול';

  @override
  String medicineBody(String medicine, String dose) {
    return '\u2068$medicine\u2069 · \u2068$dose\u2069';
  }

  @override
  String medicineNoDose(String medicine) {
    return '\u2068$medicine\u2069 · זמן לתת מנה';
  }

  @override
  String appointmentToday(String time, String title) {
    return 'היום \u2068$time\u2069: \u2068$title\u2069';
  }

  @override
  String appointmentTomorrow(String time, String title) {
    return 'מחר \u2068$time\u2069: \u2068$title\u2069';
  }

  @override
  String appointmentOn(String date, String time, String title) {
    return '\u2068$date\u2069 \u2068$time\u2069: \u2068$title\u2069';
  }

  @override
  String withPlace(String text, String place) {
    return '\u2068$text\u2069 · \u2068$place\u2069';
  }

  @override
  String get snooze => 'עוד 15 דק׳';

  @override
  String get done => 'בוצע';

  @override
  String get sectionTitle => 'התראות';

  @override
  String get masterTitle => 'תזכורות בטלפון הזה';

  @override
  String get masterNote => 'PetLoop מצלצלת בזמן של כל תזכורת';

  @override
  String get masterDoneNote => 'אפשר לסמן ארוחות, טיולים ותרופות כבוצעו ישירות מההתראה';

  @override
  String get meals => 'ארוחות';

  @override
  String get walks => 'טיולים';

  @override
  String get medicines => 'תרופות';

  @override
  String get appointments => 'תורים וחיסונים';

  @override
  String get appointmentsNote => 'בערב שלפני (18:00) ושעתיים לפני';

  @override
  String get basket => 'סל: עומד להיגמר';

  @override
  String get basketNote => '5 ימים לפני';

  @override
  String get quietHours => 'שעות שקטות, 22:00–07:00';

  @override
  String get quietHoursNote => 'תרופות מצלצלות גם בשעות השקטות';

  @override
  String get quietHoursMoved => 'ארוחות, טיולים והסל מחכים עד 07:00';

  @override
  String get exactTitle => 'בדיוק בזמן';

  @override
  String get exactNote => 'כדי שתזכורת לתרופה תגיע בדקה המדויקת, אנדרואיד מבקש את ההרשאה ״שעונים מעוררים ותזכורות״.';

  @override
  String get exactAllowed => 'יש הרשאה';

  @override
  String get exactMissing => 'עדיין אין הרשאה: תזכורת יכולה להגיע באיחור, עד שעה.';

  @override
  String get exactAllow => 'מתן הרשאה';

  @override
  String get blockedTitle => 'אין הרשאה להציג התראות';

  @override
  String get blockedNote => 'ההתראות של PetLoop כבויות בהגדרות הטלפון, ולכן אף תזכורת לא תצלצל.';

  @override
  String get openPhoneSettings => 'פתיחת הגדרות הטלפון';

  @override
  String get summaryQuietOff => 'תזכורות פועלות · שעות שקטות כבויות';

  @override
  String get summaryQuietOn => 'תזכורות פועלות · שעות שקטות פועלות';

  @override
  String get summaryOff => 'התזכורות כבויות';

  @override
  String get summaryBlocked => 'חסומות בהגדרות הטלפון';

  @override
  String get askTitle => 'תזכורות בזמן';

  @override
  String get askIntro => 'PetLoop יכולה לצלצל כשמגיע הזמן של:';

  @override
  String get askMeals => 'ארוחות וטיולים';

  @override
  String get askMedicines => 'מנות של תרופות';

  @override
  String get askAppointments => 'תורים לווטרינר וחיסונים, בערב שלפני ושעתיים לפני';

  @override
  String get askFoot => 'בהגדרות אפשר לבחור מה מצלצל ולהוסיף שעות שקטות.';

  @override
  String get askAllow => 'הפעלת תזכורות';

  @override
  String get askLater => 'לא עכשיו';

  @override
  String get askExactTitle => 'ועוד דבר: בדקה המדויקת';

  @override
  String get askExactAllow => 'פתיחת ״שעונים מעוררים ותזכורות״';

  @override
  String get communityChannel => 'קהילה';

  @override
  String get weekly => 'סיכום שבועי';

  @override
  String get weeklyNote => 'הודעה אחת בשבוע לכל חיה: טיולים, מנות ומה מתוכנן בהמשך';

  @override
  String get weeklyDay => 'יום';

  @override
  String get weeklyTime => 'שעה';

  @override
  String weeklyTitle(String pet) {
    return 'השבוע של \u2068$pet\u2069';
  }

  @override
  String weeklyLastWeek(String numbers) {
    return 'בשבוע שעבר: \u2068$numbers\u2069';
  }

  @override
  String weeklyWalks(int done, int planned) {
    return '$done מתוך $planned טיולים';
  }

  @override
  String weeklyWalksLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count טיולים',
      one: 'טיול אחד',
    );
    return '$_temp0';
  }

  @override
  String weeklyDoses(int given, int planned) {
    return '$given מתוך $planned מנות ניתנו';
  }

  @override
  String weeklyDueToday(String title) {
    return '\u2068$title\u2069: היום';
  }

  @override
  String weeklyDueTomorrow(String title) {
    return '\u2068$title\u2069: מחר';
  }

  @override
  String weeklyDueInDays(String title, int count) {
    return '\u2068$title\u2069 בעוד $count ימים';
  }

  @override
  String weeklyDueInWeeks(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '\u2068$title\u2069 בעוד $count שבועות',
      two: '\u2068$title\u2069 בעוד שבועיים',
      one: '\u2068$title\u2069 בעוד שבוע',
    );
    return '$_temp0';
  }

  @override
  String weeklyDueOn(String title, String date) {
    return '\u2068$title\u2069 בתאריך \u2068$date\u2069';
  }
}
