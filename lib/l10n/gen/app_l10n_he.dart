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
  String get authTerms => 'יצירת חשבון היא הסכמה ל[תנאי השימוש] ול[מדיניות הפרטיות].';

  @override
  String get authShowPassword => 'הצגת הסיסמה';

  @override
  String get authHidePassword => 'הסתרת הסיסמה';

  @override
  String get resetPasswordTitle => 'סיסמה חדשה';

  @override
  String get resetPasswordIntro => 'בחרו סיסמה חדשה לחשבון שלכם.';

  @override
  String get resetPasswordLabel => 'סיסמה חדשה';

  @override
  String get resetPasswordConfirm => 'אימות סיסמה';

  @override
  String get resetPasswordTooShort => 'לפחות 8 תווים';

  @override
  String get resetPasswordMismatch => 'הסיסמאות אינן זהות';

  @override
  String get resetPasswordSave => 'שמירת הסיסמה';

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
  String get accountDelete => 'מחיקת החשבון';

  @override
  String get accountDeleteTitle => 'למחוק את החשבון?';

  @override
  String get accountDeleteBody => 'זה מוחק את החשבון לצמיתות: החיות שלכם, הרשומות והמסמכים שלהן, התמונות, הפוסטים וההודעות. אין דרך חזרה.';

  @override
  String get accountDeleteWord => 'מחיקה';

  @override
  String accountDeleteHint(String word) {
    return 'הקלידו \u2068$word\u2069 לאישור';
  }

  @override
  String get accountDeleteConfirm => 'למחוק את החשבון שלי';

  @override
  String get accountDeleted => 'החשבון נמחק.';

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
  String get youTitle => 'החשבון שלי';

  @override
  String get youCommunitySafetySummary => 'כללים, חברים שחסמתי';

  @override
  String get youAdminTools => 'כלי ניהול';

  @override
  String get youAdminToolsSummary => 'הרשאות לתכונות, בדיקת המאגר, הצעות לגינות, שימוש';

  @override
  String get adminUsage => 'שימוש';

  @override
  String get adminUsageSummary => 'אילו פעולות חוזרות';

  @override
  String get usageTitle => 'שימוש';

  @override
  String get usageDaysTitle => '28 הימים האחרונים';

  @override
  String get usageColumnDay => 'יום';

  @override
  String get usageColumnActive => 'פעילים';

  @override
  String get usageColumnTicks => 'סימונים ב״היום״';

  @override
  String get usageNote => 'פעילים: חשבונות שהשתמשו באפליקציה באותו יום. סימונים ב״היום״: כמה מהם סימנו שורה ברשימת היום.';

  @override
  String get usageKindsTitle => 'פעולות';

  @override
  String get usageColumnWeek => '7 ימים';

  @override
  String get usageColumnMonth => '28 ימים';

  @override
  String get usageEmptyTitle => 'עדיין אין נתוני שימוש';

  @override
  String get usageEmptyMessage => 'הטלפונים שולחים את הספירה פעם ביום, אז כל יום מופיע למחרת.';

  @override
  String get usageErrorTitle => 'לא הצלחנו לטעון את נתוני השימוש';

  @override
  String get usageErrorMessage => 'כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get usageKindTodayTick => 'סימונים ברשימת היום';

  @override
  String get usageKindCareLogged => 'רישומי טיפול';

  @override
  String get usageKindDoseRecorded => 'מנות תרופה שנרשמו';

  @override
  String get usageKindRecordAdded => 'רשומות בריאות חדשות';

  @override
  String get usageKindQuickLog => 'רישום מהיר';

  @override
  String get usageKindMeetupJoined => 'הצטרפות למפגשים';

  @override
  String get usageKindMeetupPosted => 'מפגשים שפורסמו';

  @override
  String get usageKindPostCreated => 'פוסטים';

  @override
  String get usageKindCommentCreated => 'תגובות';

  @override
  String get usageKindChatMessageSent => 'הודעות צ׳אט';

  @override
  String get usageKindDealOpened => 'מבצעים שנפתחו';

  @override
  String get usageKindDealShared => 'מבצעים ששותפו';

  @override
  String get usageKindBasketBoughtAgain => 'קניתי שוב';

  @override
  String get usageKindExpenseAdded => 'הוצאות שנוספו';

  @override
  String get usageKindEmergencyOpened => 'פתיחות של חירום';

  @override
  String get usageKindFindVetOpened => 'פתיחות של חיפוש וטרינר';

  @override
  String get usageKindHouseholdInviteSent => 'הזמנות לבית';

  @override
  String get usageKindAppOpened => 'פתיחות של האפליקציה';

  @override
  String get aboutTitle => 'על PetLoop';

  @override
  String aboutVersion(String version) {
    return 'גרסה \u2068$version\u2069';
  }

  @override
  String get menuMyPets => 'החיות שלי';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsSummary => 'שפה, שבוע, התראות';

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
  String get settingsWeekNote => 'השבוע שלך: היום הראשון וימי החול. לוח הזמנים בבריאות מתאים את עצמו לבחירה הזו.';

  @override
  String get settingsSavedNote => 'ההגדרות נשמרות בטלפון הזה.';

  @override
  String settingsLanguageFollowing(String language) {
    return 'לפי שפת המכשיר · \u2068$language\u2069';
  }

  @override
  String settingsWeekSummary(String day, String weekdays) {
    return 'מתחיל ביום \u2068$day\u2069 · \u2068$weekdays\u2069';
  }

  @override
  String get legalTerms => 'תנאי השימוש';

  @override
  String get legalPrivacy => 'מדיניות הפרטיות';

  @override
  String get legalOpensInBrowser => 'נפתח בדפדפן.';

  @override
  String get legalOpenFailed => 'לא הצלחנו לפתוח את הדף. נסו שוב מאוחר יותר.';

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
