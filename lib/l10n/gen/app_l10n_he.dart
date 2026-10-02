// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appName => 'PetLoop';

  @override
  String get navHome => 'בית';

  @override
  String get navHealth => 'בריאות';

  @override
  String get navCommunity => 'קהילה';

  @override
  String get navStore => 'חנות';

  @override
  String get commonSave => 'שמירה';

  @override
  String get commonCancel => 'ביטול';

  @override
  String get commonDelete => 'מחיקה';

  @override
  String get commonEdit => 'עריכה';

  @override
  String get commonAdd => 'הוספה';

  @override
  String get commonBack => 'חזרה';

  @override
  String get commonClose => 'סגירה';

  @override
  String get commonContinue => 'המשך';

  @override
  String get commonShare => 'שיתוף';

  @override
  String get commonTryAgain => 'לנסות שוב';

  @override
  String get commonToday => 'היום';

  @override
  String get commonTomorrow => 'מחר';

  @override
  String get commonYesterday => 'אתמול';

  @override
  String get errorGeneric => 'משהו השתבש. אפשר לנסות שוב.';

  @override
  String get discardChangesTitle => 'לוותר על השינויים?';

  @override
  String get discardChangesBody => 'השינויים שעשית לא יישמרו.';

  @override
  String get discardChangesKeepEditing => 'להמשיך לערוך';

  @override
  String get discardChangesDiscard => 'לוותר';

  @override
  String get petSelectorAdd => 'הוספת חיה';

  @override
  String placeholderComingSoon(String title) {
    return '\u2068$title\u2069: בקרוב';
  }

  @override
  String get authWelcomeBack => 'טוב לראות אותך שוב';

  @override
  String get authSignInSubtitle => 'כניסה קצרה, ואפשר לראות מה שלום החיות שלך היום.';

  @override
  String get authEmail => 'אימייל';

  @override
  String get authPassword => 'סיסמה';

  @override
  String get authPasswordHint => 'הסיסמה שלך';

  @override
  String get authForgotPassword => 'שכחתי סיסמה';

  @override
  String get authSignIn => 'כניסה';

  @override
  String get authNewHere => 'פעם ראשונה כאן?';

  @override
  String get authCreateAnAccount => 'יצירת חשבון';

  @override
  String get authForgotNeedsEmail => 'קודם צריך להזין למעלה את כתובת האימייל, ואז ללחוץ על ״שכחתי סיסמה״.';

  @override
  String authResetSent(String email) {
    return 'אם יש חשבון עם הכתובת \u2068$email\u2069, קישור לאיפוס הסיסמה כבר בדרך.';
  }

  @override
  String get authResetFailed => 'לא הצלחנו לשלוח קישור לאיפוס. אפשר לנסות שוב.';

  @override
  String get authCreateTitle => 'יצירת חשבון חדש';

  @override
  String get authCreateSubtitle => 'חשבון אחד לכל החיות שלך.';

  @override
  String get authYourName => 'השם שלך';

  @override
  String get authYourNameHint => 'איך לקרוא לך?';

  @override
  String authPasswordMinHint(int count) {
    return 'לפחות $count תווים';
  }

  @override
  String get authRepeatPassword => 'חזרה על הסיסמה';

  @override
  String get authRepeatPasswordHint => 'אותה סיסמה כמו למעלה';

  @override
  String get authCreateAccount => 'יצירת חשבון';

  @override
  String get authTerms => 'יצירת חשבון היא הסכמה לתנאי השימוש ולמדיניות הפרטיות.';

  @override
  String get authShowPassword => 'הצגת הסיסמה';

  @override
  String get authHidePassword => 'הסתרת הסיסמה';

  @override
  String get validEmailEmpty => 'צריך להזין כתובת אימייל.';

  @override
  String get validEmailInvalid => 'זה לא נראה כמו כתובת אימייל.';

  @override
  String get validPasswordEmpty => 'צריך להזין סיסמה.';

  @override
  String validMinLength(int count) {
    return 'צריך לפחות $count תווים.';
  }

  @override
  String get validConfirmEmpty => 'צריך להזין את הסיסמה שוב.';

  @override
  String get validConfirmMismatch => 'הסיסמאות לא זהות.';

  @override
  String get validNameEmpty => 'צריך שם, כדי שנדע איך לקרוא לך.';

  @override
  String get authErrNoAccount => 'אין חשבון עם כתובת האימייל הזאת.';

  @override
  String get authErrWrongPassword => 'הסיסמה לא נכונה. אפשר לנסות שוב.';

  @override
  String get authErrEmailTaken => 'כבר יש חשבון עם כתובת האימייל הזאת.';

  @override
  String get authErrInvalidCredentials => 'האימייל או הסיסמה לא נכונים. אפשר לנסות שוב.';

  @override
  String get authErrEmailNotConfirmed => 'קודם צריך לאשר את כתובת האימייל. הקישור מחכה בתיבת הדואר שלך.';

  @override
  String get authErrRateLimited => 'יותר מדי ניסיונות. כדאי לחכות רגע ולנסות שוב.';

  @override
  String get authErrWeakPassword => 'צריך סיסמה ארוכה יותר.';

  @override
  String get authErrNetwork => 'אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get authErrSignInIncomplete => 'הכניסה לא הושלמה. אפשר לנסות שוב.';

  @override
  String get authErrSignUpIncomplete => 'ההרשמה לא הושלמה. אפשר לנסות שוב.';

  @override
  String get authErrConfirmEmailSent => 'כמעט שם: צריך לפתוח את אימייל האישור ששלחנו עכשיו, ואז להיכנס.';

  @override
  String get accountSignOut => 'יציאה מהחשבון';

  @override
  String get accountLanguage => 'שפה';

  @override
  String get languageFollowPhone => 'לפי שפת המכשיר';

  @override
  String languageFollowPhoneNow(String language) {
    return 'כרגע: \u2068$language\u2069';
  }

  @override
  String get languagePreviewTag => 'בהרצה';

  @override
  String get languageNote => 'אפשר לשנות בכל רגע. מה שכתבו חברי הקהילה נשאר בשפה שבה נכתב.';

  @override
  String languageSwitchTo(String language) {
    return 'החלפת שפה: \u2068$language\u2069';
  }

  @override
  String get menuMyPets => 'החיות שלי';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsSummary => 'שפה, שבוע';

  @override
  String get settingsWeek => 'שבוע';

  @override
  String get settingsFirstDay => 'היום הראשון בשבוע';

  @override
  String get settingsDaySaturday => 'שבת';

  @override
  String get settingsDaySunday => 'ראשון';

  @override
  String get settingsDayMonday => 'שני';

  @override
  String get settingsWeekdays => 'ימי חול';

  @override
  String get settingsWeekdaysSunThu => 'ראשון עד חמישי';

  @override
  String get settingsWeekdaysMonFri => 'שני עד שישי';

  @override
  String settingsWeekendIs(String days) {
    return 'סוף השבוע: \u2068$days\u2069';
  }

  @override
  String get settingsWeekNote => 'השבוע שלך: איזה יום ראשון בסדר, ואילו ימים הם ימי חול. הימים המעומעמים הם סוף השבוע. לוח הזמנים בבריאות מתאים את עצמו לבחירה הזו: סדר הימים, ומה נחשב שם ״ימי חול״ ו״סוף שבוע״.';

  @override
  String get settingsSavedNote => 'ההגדרות נשמרות בטלפון הזה.';

  @override
  String get homeMenu => 'תפריט';

  @override
  String get homeAccount => 'חשבון';

  @override
  String homePetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חיות',
      one: 'חיה אחת',
    );
    return '$_temp0';
  }

  @override
  String get homeBreed => 'גזע';

  @override
  String get homeAge => 'גיל';

  @override
  String get homeWeight => 'משקל';

  @override
  String homeWeightKg(String value) {
    return '\u2068$value\u2069 ק״ג';
  }

  @override
  String get homeFeeding => 'האכלה';

  @override
  String get homeNoGoal => 'עוד לא נקבע יעד';

  @override
  String homeGoal(String goal) {
    return 'יעד: \u2068$goal\u2069 קלוריות ביום';
  }

  @override
  String get homeCalToday => 'קלוריות היום';

  @override
  String get homeCaloriesSemantics => 'קלוריות מתוך היעד היומי';

  @override
  String homeCaloriesOfGoal(int eaten, int goal) {
    return '$eaten מתוך $goal';
  }

  @override
  String homeNextFeeding(String time) {
    return 'ההאכלה הבאה · \u2068$time\u2069';
  }

  @override
  String get homeNextFeedingUnset => 'ההאכלה הבאה · עוד לא נקבעה';

  @override
  String get homeActivity => 'פעילות';

  @override
  String get homeSteps => 'צעדים';

  @override
  String get homeActivityTime => 'זמן פעילות';

  @override
  String homeNextWalk(String time) {
    return 'הטיול הבא · \u2068$time\u2069';
  }

  @override
  String get homeNextWalkUnset => 'הטיול הבא · עוד לא נקבע';

  @override
  String get homeHealth => 'בריאות';

  @override
  String get homeUpcoming => 'בקרוב';

  @override
  String get homeNoHealthEvents => 'עדיין אין אירועי בריאות';
}
