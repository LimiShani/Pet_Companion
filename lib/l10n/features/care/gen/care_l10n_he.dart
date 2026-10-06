// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'care_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class CareL10nHe extends CareL10n {
  CareL10nHe([String locale = 'he']) : super(locale);

  @override
  String get fed => 'האכלתי';

  @override
  String get walkAction => 'טיול';

  @override
  String get playAction => 'משחק';

  @override
  String get walksTodayLabel => 'טיולים היום';

  @override
  String get playTodayLabel => 'פעילויות היום';

  @override
  String get minutesLabel => 'דקות פעילות';

  @override
  String nextFeedingTomorrow(String time) {
    return 'ההאכלה הבאה · מחר \u2068$time\u2069';
  }

  @override
  String nextWalkTomorrow(String time) {
    return 'הטיול הבא · מחר \u2068$time\u2069';
  }

  @override
  String goalMinutesLine(String minutes) {
    return 'יעד: \u2068$minutes\u2069 דקות ביום';
  }

  @override
  String get inviteWalkTimes => 'הוסיפו שעות טיול כדי לעקוב אחרי הפעילות';

  @override
  String get invitePlay => 'רשמו משחק כדי לעקוב אחרי הפעילות';

  @override
  String get addFoodToCount => 'הוסיפו את המזון כדי לספור קלוריות';

  @override
  String walkRunning(String time) {
    return 'בטיול · \u2068$time\u2069';
  }

  @override
  String playRunning(String time) {
    return 'במשחק · \u2068$time\u2069';
  }

  @override
  String get finish => 'סיום';

  @override
  String savedMinutes(String minutes) {
    return 'נשמרו \u2068$minutes\u2069 דקות';
  }

  @override
  String doseToday(String time) {
    return 'היום · \u2068$time\u2069';
  }

  @override
  String medicineItem(String name) {
    return 'תרופה: \u2068$name\u2069';
  }

  @override
  String get openFeeding => 'פתיחת ההאכלה';

  @override
  String get openActivity => 'פתיחת הפעילות';

  @override
  String get openHealth => 'פתיחת הבריאות';

  @override
  String get loadFailed => 'הטעינה נכשלה. הקישו כדי לנסות שוב.';

  @override
  String feedingTitle(String name) {
    return 'האכלה · \u2068$name\u2069';
  }

  @override
  String get today => 'היום';

  @override
  String caloriesOfGoal(String eaten, String goal) {
    return '\u2068$eaten\u2069 / \u2068$goal\u2069 קלוריות';
  }

  @override
  String caloriesOnly(String eaten) {
    return '\u2068$eaten\u2069 קלוריות';
  }

  @override
  String mealAmount(String grams, String calories) {
    return '\u2068$grams\u2069 ג׳ · \u2068$calories\u2069 קל׳';
  }

  @override
  String gramsValue(String grams) {
    return '\u2068$grams\u2069 ג׳';
  }

  @override
  String get mealNotEaten => 'לא נאכלה';

  @override
  String get mealDone => 'בוצע';

  @override
  String get extraMeal => 'חטיף או ארוחה נוספת';

  @override
  String get thisWeek => 'השבוע';

  @override
  String weekGoalLine(String goal, String average) {
    return 'יעד: \u2068$goal\u2069 · ממוצע: \u2068$average\u2069';
  }

  @override
  String weekAverageLine(String average) {
    return 'ממוצע: \u2068$average\u2069';
  }

  @override
  String get foodAndPortion => 'המזון והמנה';

  @override
  String foodSummary(String kcal) {
    return '\u2068$kcal\u2069 קלוריות ל־100 ג׳';
  }

  @override
  String portionSummary(String grams) {
    return '\u2068$grams\u2069 ג׳ לארוחה';
  }

  @override
  String get mealTimes => 'שעות האכלה';

  @override
  String get noMealTimes => 'עוד אין שעות האכלה';

  @override
  String get addMealTime => 'הוספת שעת האכלה';

  @override
  String get sameAsSchedule => 'אותן שעות כמו בבריאות · לוח זמנים.';

  @override
  String get noMealsToday => 'עוד אין ארוחות היום';

  @override
  String get removeEntry => 'הסרת הרישום';

  @override
  String get removeEntryQuestion => 'להסיר את הרישום? השעה תחזור להיות פתוחה.';

  @override
  String get remove => 'הסרה';

  @override
  String get logMealTitle => 'רישום ארוחה';

  @override
  String get whichMeal => 'איזו ארוחה';

  @override
  String get extra => 'תוספת';

  @override
  String get howMuch => 'כמה';

  @override
  String get wholePortion => 'כל המנה';

  @override
  String get halfPortion => 'חצי';

  @override
  String get notEaten => 'לא נאכלה';

  @override
  String equalsCalories(String calories) {
    return '= \u2068$calories\u2069 קלוריות';
  }

  @override
  String get time => 'שעה';

  @override
  String get less => 'פחות';

  @override
  String get more => 'יותר';

  @override
  String get mealTitleExtra => 'ארוחה נוספת';

  @override
  String get foodName => 'שם המזון';

  @override
  String get foodNameHint => 'מזון יבש';

  @override
  String get kcalPer100g => 'קלוריות ל־100 ג׳';

  @override
  String get gramsPerCup => 'גרם בכוס (רשות)';

  @override
  String get portion => 'מנה רגילה לארוחה (גרם)';

  @override
  String portionCups(String cups) {
    return '\u2068$cups\u2069 כוסות';
  }

  @override
  String get dailyGoal => 'יעד יומי';

  @override
  String goalEstimateNote(String kg) {
    return 'מחושב לפי המשקל (\u2068$kg\u2069 ק״ג), הגיל והעיקור. זו הערכה כללית: הווטרינר יכול לתת יעד מדויק.';
  }

  @override
  String get goalNoWeight =>
      'הוסיפו משקל בפרופיל כדי לקבל הערכה, או קבעו יעד משלכם.';

  @override
  String get goalNoSpecies => 'אין הערכה לסוג החיה הזה. קבעו יעד משלכם.';

  @override
  String get goalByEstimate => 'לפי החישוב';

  @override
  String get goalOwn => 'יעד שלי';

  @override
  String get caloriesADay => 'קלוריות ביום';

  @override
  String get foodBagNote => 'הקלוריות מופיעות על השקית.';

  @override
  String numberRange(String min, String max) {
    return 'הקלידו מספר בין \u2068$min\u2069 ל־\u2068$max\u2069';
  }

  @override
  String get save => 'שמירה';

  @override
  String get cancel => 'ביטול';

  @override
  String activityTitle(String name) {
    return 'פעילות · \u2068$name\u2069';
  }

  @override
  String minutesOfGoal(String minutes, String goal) {
    return '\u2068$minutes\u2069 / \u2068$goal\u2069 דקות';
  }

  @override
  String minutesValue(String minutes) {
    return '\u2068$minutes\u2069 דק׳';
  }

  @override
  String get start => 'התחלה';

  @override
  String get extraWalk => 'טיול או משחק נוסף';

  @override
  String get extraPlay => 'רישום משחק';

  @override
  String get weekMinutes => 'השבוע (דקות)';

  @override
  String get activityGoal => 'יעד פעילות יומי';

  @override
  String get walkTimes => 'שעות טיול';

  @override
  String get noWalkTimes => 'עוד אין שעות טיול';

  @override
  String get addWalkTime => 'הוספת שעת טיול';

  @override
  String get noWalksToday => 'עוד אין טיולים היום';

  @override
  String get noPlayToday => 'עוד לא נרשם משחק היום';

  @override
  String get goalSheetTitle => 'דקות פעילות ביום';

  @override
  String get skipped => 'דילוג';

  @override
  String get walkTitle => 'טיול';

  @override
  String get playTitle => 'משחק';

  @override
  String get startNow => 'יוצאים עכשיו';

  @override
  String get startPlayNow => 'מתחילים לשחק עכשיו';

  @override
  String get startNowNote =>
      'השעון ממשיך גם כשהאפליקציה סגורה. ״סיום״ שומר את הדקות.';

  @override
  String get logPast => 'או: רישום של מה שכבר היה';

  @override
  String get whichWalk => 'איזה טיול';

  @override
  String get howLong => 'כמה זמן (דקות)';

  @override
  String get otherMinutes => 'אחר';

  @override
  String get activityType => 'סוג';

  @override
  String get typeWalk => 'טיול';

  @override
  String get typePlay => 'משחק';

  @override
  String get typeRun => 'ריצה';

  @override
  String get when => 'מתי';

  @override
  String todayAt(String time) {
    return 'היום · \u2068$time\u2069';
  }

  @override
  String get cancelWalk => 'ביטול הטיול';
}
