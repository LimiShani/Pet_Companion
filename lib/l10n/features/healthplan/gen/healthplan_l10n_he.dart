// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'healthplan_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class HealthPlanL10nHe extends HealthPlanL10n {
  HealthPlanL10nHe([String locale = 'he']) : super(locale);

  @override
  String insightShorterWalks(String pet) {
    return 'הטיולים של \u2068$pet\u2069 היו קצרים יותר מבחודש שעבר. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String insightWeightUp(String pet, int percent) {
    return 'המשקל של \u2068$pet\u2069 עלה בכ־$percent% בשבועות האחרונים. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String insightWeightDown(String pet, int percent) {
    return 'המשקל של \u2068$pet\u2069 ירד בכ־$percent% בשבועות האחרונים. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String insightAppetiteLess(String pet, int count) {
    return 'בשבועיים האחרונים נרשם $count פעמים שהתיאבון של \u2068$pet\u2069 היה פחות מהרגיל. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String get insightSeeWalks => 'לטיולים';

  @override
  String get insightSeeWeight => 'למשקל';

  @override
  String get insightSeeJournal => 'ליומן התצפיות';

  @override
  String get planAddRow => 'תוכנית שנתית';

  @override
  String get planAddRowNote => 'חיסונים וטיפולים';

  @override
  String planTitle(String pet) {
    return 'התוכנית השנתית של \u2068$pet\u2069';
  }

  @override
  String get planIntroDog => 'תוכנית מקובלת לכלבים בישראל. הווטרינר יכול להציע תוכנית אחרת.';

  @override
  String get planIntroCat => 'תוכנית מקובלת לחתולים בישראל. הווטרינר יכול להציע תוכנית אחרת.';

  @override
  String get planNoPlan => 'עדיין אין תוכנית שנתית לסוג החיה הזה.';

  @override
  String get planRequired => 'חובה לפי החוק';

  @override
  String get planRecommended => 'מומלץ';

  @override
  String planFirstDate(String date) {
    return 'מועד ראשון \u2068$date\u2069';
  }

  @override
  String get planFirstDateToday => 'מועד ראשון היום';

  @override
  String planLastTime(String date) {
    return 'בפעם הקודמת: \u2068$date\u2069';
  }

  @override
  String planOverdue(String date) {
    return 'בפעם הקודמת: \u2068$date\u2069 · הגיע הזמן';
  }

  @override
  String get planNoHistory => 'אין רישום. כדאי לבדוק קודם בפנקס החיסונים.';

  @override
  String planFromWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מגיל $count שבועות',
    );
    return '$_temp0';
  }

  @override
  String planFromMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מגיל $count חודשים',
      two: 'מגיל חודשיים',
      one: 'מגיל חודש',
    );
    return '$_temp0';
  }

  @override
  String planSeriesTwo(int first, int second) {
    return 'אחר כך בגיל $first ו־$second שבועות, ואז פעם בשנה';
  }

  @override
  String planSeriesOne(int weeks) {
    return 'אחר כך בגיל $weeks שבועות, ואז פעם בשנה';
  }

  @override
  String get planSeriesLast => 'ואז פעם בשנה';

  @override
  String planAlreadyPlanned(String date) {
    return 'כבר בלוח הזמנים ל־\u2068$date\u2069';
  }

  @override
  String planEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'כל $count חודשים',
      one: 'כל חודש',
    );
    return '$_temp0';
  }

  @override
  String get planSources => 'על מה זה מבוסס';

  @override
  String planSourcesIntro(String pet) {
    return 'התוכנית מבוססת על המקורות האלה. הווטרינר מכיר את \u2068$pet\u2069 הכי טוב.';
  }

  @override
  String get planFinePrint => 'אינה תחליף לייעוץ של וטרינר.';

  @override
  String planAddDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הוספת $count מועדים ללוח הזמנים',
      one: 'הוספת מועד אחד ללוח הזמנים',
    );
    return '$_temp0';
  }

  @override
  String planAdded(String pet) {
    return 'נוסף ללוח הזמנים של \u2068$pet\u2069';
  }

  @override
  String planAddedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נוספו $count מועדים. כשמסמנים אחד כבוצע, הבא מתוכנן מעצמו.',
      one: 'נוסף מועד אחד. כשמסמנים אותו כבוצע, הבא מתוכנן מעצמו.',
    );
    return '$_temp0';
  }

  @override
  String get planAddToCalendar => 'הוספה ליומן שלי';

  @override
  String get planCalendarNote => 'משתף קובץ יומן. PetLoop לא קוראת את היומן שלך.';

  @override
  String get planDone => 'סיום';

  @override
  String planInvite(String pet) {
    return 'עדיין אין חיסונים ברשומות של \u2068$pet\u2069. תוכנית שנתית מכניסה את המועדים הבאים ללוח הזמנים.';
  }

  @override
  String get planInviteAction => 'תכנון השנה';

  @override
  String planFromPlan(String pet) {
    return 'מהתוכנית השנתית של \u2068$pet\u2069';
  }
}
