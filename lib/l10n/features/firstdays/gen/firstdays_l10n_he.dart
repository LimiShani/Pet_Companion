// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'firstdays_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class FirstDaysL10nHe extends FirstDaysL10n {
  FirstDaysL10nHe([String locale = 'he']) : super(locale);

  @override
  String pageTitle(String name) {
    return '30 הימים הראשונים · \u2068$name\u2069';
  }

  @override
  String arrivedOn(String date) {
    return 'הגעה הביתה: \u2068$date\u2069';
  }

  @override
  String dayOfTotal(String day, String total) {
    return 'יום \u2068$day\u2069 מתוך \u2068$total\u2069';
  }

  @override
  String doneCount(String count) {
    return '\u2068$count\u2069 בוצעו';
  }

  @override
  String get firstWeek => 'השבוע הראשון';

  @override
  String get laterWeeks => 'שבועות 2–4';

  @override
  String get tickedForYou => 'בוצע באפליקציה';

  @override
  String get markDone => 'סימון כבוצע';

  @override
  String get markNotDone => 'ביטול הסימון';

  @override
  String get closePath => 'סגירת 30 הימים הראשונים';

  @override
  String get closeQuestion => 'לסגור את 30 הימים הראשונים?';

  @override
  String closeMessage(String name) {
    return 'הכרטיס יירד מהבית, והרשימה תישאר כסיכום בפרופיל של \u2068$name\u2069.';
  }

  @override
  String get closeConfirm => 'סגירה';

  @override
  String closedOn(String date) {
    return 'נסגר בתאריך \u2068$date\u2069';
  }

  @override
  String get overLine => '30 הימים הסתיימו';

  @override
  String get allDoneLine => 'הכול בוצע. כל הכבוד.';

  @override
  String get summaryNote => 'מבט לאחור על 30 הימים הראשונים.';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את 30 הימים הראשונים';

  @override
  String notStarted(String name) {
    return '30 הימים הראשונים עדיין לא התחילו עבור \u2068$name\u2069.';
  }

  @override
  String cardTitle(String name) {
    return '30 הימים הראשונים של \u2068$name\u2069';
  }

  @override
  String cardDay(String day) {
    return 'יום \u2068$day\u2069';
  }

  @override
  String cardNext(String task) {
    return 'הבא בתור: \u2068$task\u2069';
  }

  @override
  String get open => 'פתיחה';

  @override
  String get openTapLabel => 'פתיחת 30 הימים הראשונים';

  @override
  String get arrivedQuestion => 'ההגעה הביתה הייתה ממש לאחרונה?';

  @override
  String get answerYes => 'כן';

  @override
  String get answerNo => 'לא';

  @override
  String get arrivalDay => 'יום ההגעה';

  @override
  String get arrivalNote => 'נכין רשימה קצרה ל־30 הימים הראשונים.';

  @override
  String get sectionTitle => '30 הימים הראשונים';

  @override
  String get startPath => 'התחלת 30 הימים הראשונים';

  @override
  String get startNote => 'רשימה קצרה לחיה שהגיעה הביתה לאחרונה.';

  @override
  String get viewSummary => 'צפייה';

  @override
  String get taskDogBasics => 'לדאוג לבסיס: מיטה, קערות, רצועה ומזון';

  @override
  String get taskDogRestSpot => 'להכין פינה שקטה למנוחה';

  @override
  String get taskFood => 'להישאר בינתיים עם המזון המוכר, ולהוסיף אותו כאן';

  @override
  String get taskMealTimes => 'לקבוע שעות קבועות לארוחות';

  @override
  String get taskWalkTimes => 'לתכנן שעות קבועות לטיולים';

  @override
  String get taskDogNameTag => 'קולר עם תג שם ומספר טלפון';

  @override
  String get taskFirstVet => 'לקבוע בדיקה ראשונה אצל וטרינר';

  @override
  String get taskDogGuide => 'לקרוא את המדריך על השבוע הראשון בבית';

  @override
  String get taskMicrochip => 'לבדוק את השבב ולרשום בו את הפרטים שלך';

  @override
  String get taskVaccines => 'לתכנן חיסונים יחד עם הווטרינר';

  @override
  String get taskDogFirstWalks =>
      'טיולים ראשונים קצרים והיכרות רגועה עם אנשים וכלבים';

  @override
  String get taskDogHouseRules => 'לסכם חוקי בית עם כל בני הבית';

  @override
  String get taskCatBasics => 'לדאוג לבסיס: ארגז חול, קערות ומזון';

  @override
  String get taskCatSafeRoom => 'חדר שקט להתאקלמות, עם כל מה שצריך בהישג יד';

  @override
  String get taskCatGuide => 'לקרוא את המדריך על השבוע הראשון של חתול בבית';

  @override
  String get taskCatScratching => 'עמוד גירוד ליד פינה אהובה';

  @override
  String get taskCatExplore => 'לפתוח בהדרגה את שאר הבית, חדר אחרי חדר';

  @override
  String get taskCatPlay => 'משחק קצר בכל יום';

  @override
  String get taskOtherHome =>
      'להכין מקום מגורים: כלוב, אקווריום או פינה, עם מזון ומים';

  @override
  String get taskOtherQuiet => 'כמה ימים שקטים להתאקלמות';

  @override
  String get taskCleaning => 'לתכנן שגרת ניקוי למקום המגורים';

  @override
  String get taskGuides => 'להציץ במדריכים בקהילה';

  @override
  String get actionDeals => 'מבצעים';

  @override
  String get actionFood => 'מזון';

  @override
  String get actionFeeding => 'האכלה';

  @override
  String get actionActivity => 'פעילות';

  @override
  String get actionAddVisit => 'הוספת ביקור';

  @override
  String get actionMicrochip => 'שבב';

  @override
  String get actionSchedule => 'לוח זמנים';

  @override
  String get actionRoutine => 'שגרה';

  @override
  String get actionRead => 'קריאה';

  @override
  String get actionGuides => 'מדריכים';
}
