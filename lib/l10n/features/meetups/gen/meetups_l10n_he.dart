// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'meetups_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class MeetupsL10nHe extends MeetupsL10n {
  MeetupsL10nHe([String locale = 'he']) : super(locale);

  @override
  String get areaQuestion => 'באיזה אזור יוצאים?';

  @override
  String get problemOutsideRegion => 'בינתיים יש שותפים רק בישראל. אפשר לבחור עיר בישראל.';

  @override
  String get safetyStrip => 'נפגשים במקום ציבורי ולא משתפים כתובת בית.';

  @override
  String get newAd => 'מודעה חדשה';

  @override
  String get myAds => 'המודעות שלי';

  @override
  String myAdsCount(int count) {
    return 'המודעות שלי ($count)';
  }

  @override
  String get kindAll => 'הכול';

  @override
  String get kindWalk => 'טיול';

  @override
  String get kindPlay => 'משחק';

  @override
  String get whenToday => 'היום';

  @override
  String get whenThisWeek => 'השבוע';

  @override
  String get whenRecurring => 'קבוע';

  @override
  String get atMyParks => 'בגינות שלי';

  @override
  String get filters => 'סינון';

  @override
  String filtersCount(int count) {
    return 'סינון · $count';
  }

  @override
  String filtersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'סינון: $count מסננים פעילים',
      two: 'סינון: שני מסננים פעילים',
      one: 'סינון: מסנן אחד פעיל',
      zero: 'סינון: אין מסננים פעילים',
    );
    return '$_temp0';
  }

  @override
  String get filtersTitle => 'אילו מודעות להציג';

  @override
  String get filterKind => 'טיול או משחק';

  @override
  String get filterAnimal => 'חיה';

  @override
  String get filterWhen => 'מתי';

  @override
  String get filterWhere => 'איפה';

  @override
  String get filtersClearAll => 'ניקוי הכול';

  @override
  String filtersShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הצגת $count מודעות',
      two: 'הצגת שתי מודעות',
      one: 'הצגת מודעה אחת',
      zero: 'אין מודעות להצגה',
    );
    return '$_temp0';
  }

  @override
  String get filtersDone => 'סיום';

  @override
  String get sampleAds => 'מודעות לדוגמה';

  @override
  String get emptyTitle => 'עדיין אין כאן מודעות';

  @override
  String get emptyBody => 'אפשר לפרסם את הראשונה, וחברים מהאזור יוכלו לענות.';

  @override
  String get emptyFiltered => 'אין מודעות שמתאימות לסינון.';

  @override
  String get clearFilters => 'ניקוי הסינון';

  @override
  String get lookFurther => 'חיפוש עד 25 ק״מ';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את המודעות.';

  @override
  String get noPet => 'בלי חיה';

  @override
  String get sizeSmall => 'גודל קטן';

  @override
  String get sizeMedium => 'גודל בינוני';

  @override
  String get sizeLarge => 'גודל גדול';

  @override
  String suitsLine(String sizes) {
    return 'לכלבים \u2068$sizes\u2069';
  }

  @override
  String get suitsSmall => 'קטנים';

  @override
  String get suitsMedium => 'בינוניים';

  @override
  String get suitsLarge => 'גדולים';

  @override
  String suitsTwo(String first, String second) {
    return '\u2068$first\u2069 ו\u2068$second\u2069';
  }

  @override
  String distanceAbout(String distance) {
    return 'כ־\u2068$distance\u2069';
  }

  @override
  String get distanceNear => 'פחות מק״מ';

  @override
  String answers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תשובות',
      two: 'שתי תשובות',
      one: 'תשובה אחת',
      zero: 'עדיין אין תשובות',
    );
    return '$_temp0';
  }

  @override
  String get join => 'אני רוצה להצטרף';

  @override
  String get answeredTag => 'ענית';

  @override
  String get openChat => 'לשיחה';

  @override
  String get yourAd => 'המודעה שלך';

  @override
  String get manage => 'ניהול';

  @override
  String get hiddenTag => 'מוסתרת אחרי דיווחים';

  @override
  String get endedTag => 'הסתיימה';

  @override
  String get closedTag => 'סגורה';

  @override
  String get more => 'עוד';

  @override
  String get menuReport => 'דיווח על המודעה';

  @override
  String menuBlock(String name) {
    return 'חסימה של \u2068$name\u2069';
  }

  @override
  String get reportTitle => 'לדווח על המודעה?';

  @override
  String get reportBody => 'מה לא בסדר? אחרי שלושה דיווחים המודעה מוסתרת עד שמנהלי הקהילה בודקים אותה.';

  @override
  String get reportThanks => 'תודה, המודעה דווחה.';

  @override
  String get dayPartMorning => 'בוקר';

  @override
  String get dayPartNoon => 'צהריים';

  @override
  String get dayPartEvening => 'ערב';

  @override
  String get everyDay => 'כל יום';

  @override
  String get weekdays => 'ימי חול';

  @override
  String get weekends => 'סופי שבוע';

  @override
  String get tomorrow => 'מחר';

  @override
  String get formNewTitle => 'מודעה חדשה';

  @override
  String get formEditTitle => 'עריכת המודעה';

  @override
  String get withWhom => 'עם מי?';

  @override
  String get whatQ => 'מה?';

  @override
  String get whereQ => 'איפה?';

  @override
  String get wherePark => 'גינה';

  @override
  String get whereOther => 'מקום אחר';

  @override
  String get choosePark => 'בחירת גינה';

  @override
  String get changePark => 'החלפה';

  @override
  String get parkRequired => 'צריך לבחור גינה או מקום אחר.';

  @override
  String get cityLabel => 'עיר';

  @override
  String get placeLabel => 'איפה בדיוק?';

  @override
  String get placeHint => 'מקום ציבורי, למשל הכניסה לפארק הירקון';

  @override
  String get placeHelp => 'בלי כתובות בית.';

  @override
  String get placeRequired => 'צריך לבחור עיר ולכתוב איפה.';

  @override
  String get whenQ => 'מתי?';

  @override
  String get once => 'פעם אחת';

  @override
  String get weekly => 'קבוע';

  @override
  String get dateLabel => 'תאריך';

  @override
  String get fromLabel => 'משעה';

  @override
  String get toLabel => 'עד שעה';

  @override
  String get hoursProblem => 'המפגש צריך להסתיים אחרי שהוא מתחיל, תוך 12 שעות.';

  @override
  String get pastProblem => 'השעה הזו כבר עברה.';

  @override
  String get tooFarProblem => 'אפשר לפרסם עד 60 יום מראש.';

  @override
  String get daysProblem => 'צריך לבחור לפחות יום אחד.';

  @override
  String get partQ => 'חלק ביום';

  @override
  String get suitsQ => 'מתאים ל... (לא חובה)';

  @override
  String get sizeAny => 'כל גודל';

  @override
  String get sizeSmallChip => 'קטנים';

  @override
  String get sizeMediumChip => 'בינוניים';

  @override
  String get sizeLargeChip => 'גדולים';

  @override
  String get noteLabel => 'כמה מילים';

  @override
  String get noteHint => 'למשל: טיול רגוע של שעה, כל הגדלים מוזמנים';

  @override
  String get post => 'פרסום';

  @override
  String get save => 'שמירה';

  @override
  String get posted => 'המודעה פורסמה.';

  @override
  String get saved => 'נשמר.';

  @override
  String get recurringNote => 'מודעה קבועה מוצגת 30 יום, ואז אפשר לחדש אותה.';

  @override
  String get limitsNote => 'עד 3 מודעות חדשות ביום, ועד 5 פתוחות בבת אחת.';

  @override
  String get errRateLimited => 'היום כבר פורסמו שלוש מודעות. אפשר לנסות שוב מחר.';

  @override
  String get errTooManyOpen => 'כבר יש חמש מודעות פתוחות. אפשר לסגור אחת ולפרסם.';

  @override
  String get errNotOpen => 'המודעה כבר לא פתוחה.';

  @override
  String get errBlocked => 'אי אפשר לענות למודעה הזו.';

  @override
  String get errInvalid => 'משהו במודעה כבר לא מתאים (הגינה או השעה). כדאי לבדוק ולנסות שוב.';

  @override
  String get errUnavailable => 'אין חיבור. אפשר לנסות שוב בעוד רגע.';

  @override
  String get errOther => 'זה לא הצליח. אפשר לנסות שוב.';

  @override
  String joinTitle(String name) {
    return 'הודעה אל \u2068$name\u2069';
  }

  @override
  String joinBody(String name) {
    return 'תיפתח שיחה פרטית בין שניכם. התראה תגיע אל \u2068$name\u2069 כשההודעה תישלח.';
  }

  @override
  String get whoComing => 'עם מי באים?';

  @override
  String get justMe => 'רק אני';

  @override
  String draftWalkPet(String name, String place, String pet) {
    return 'היי \u2068$name\u2069, ראיתי את המודעה לטיול (\u2068$place\u2069). אשמח להצטרף עם \u2068$pet\u2069.';
  }

  @override
  String draftWalk(String name, String place) {
    return 'היי \u2068$name\u2069, ראיתי את המודעה לטיול (\u2068$place\u2069). אשמח להצטרף.';
  }

  @override
  String draftPlayPet(String name, String place, String pet) {
    return 'היי \u2068$name\u2069, ראיתי את המודעה למפגש משחק (\u2068$place\u2069). אשמח להצטרף עם \u2068$pet\u2069.';
  }

  @override
  String draftPlay(String name, String place) {
    return 'היי \u2068$name\u2069, ראיתי את המודעה למפגש משחק (\u2068$place\u2069). אשמח להצטרף.';
  }

  @override
  String get joinMessageLabel => 'ההודעה שלך';

  @override
  String get joinTip => 'בפעם הראשונה כדאי להיפגש במקום פתוח ומוכר.';

  @override
  String get joinSend => 'פתיחת השיחה עם ההודעה';

  @override
  String get edit => 'עריכה';

  @override
  String get closeAd => 'מצאתי, אפשר לסגור';

  @override
  String get closeConfirmTitle => 'לסגור את המודעה?';

  @override
  String get closeConfirmBody => 'היא תרד מהלוח. מודעה קבועה אפשר לחדש אחר כך.';

  @override
  String get closeConfirm => 'סגירה';

  @override
  String get closedDone => 'המודעה נסגרה.';

  @override
  String get renew => 'חידוש ל־30 יום';

  @override
  String get renewed => 'המודעה חודשה לעוד 30 יום.';

  @override
  String get postAgain => 'פרסום מחדש';

  @override
  String groupButton(int count) {
    return 'קבוצה לכל מי שענה ($count)';
  }

  @override
  String get groupNone => 'אין את מי לצרף: מי שענה כבר לא זמין.';

  @override
  String showsUntil(String date) {
    return 'מוצגת עד \u2068$date\u2069';
  }

  @override
  String get myAdsEmptyTitle => 'עדיין אין מודעות';

  @override
  String get myAdsEmptyBody => 'אפשר לפרסם מודעה ולמצוא שותפים לטיול או למשחק באזור.';

  @override
  String get sectionOpen => 'פתוחות';

  @override
  String get sectionEnded => 'הסתיימו';

  @override
  String get sectionClosed => 'סגורות';

  @override
  String get adTitle => 'מודעת שותפים';

  @override
  String get adGone => 'המודעה כבר לא מוצגת.';

  @override
  String get postHere => 'פרסום מודעה בגינה הזו';

  @override
  String get atThisPark => 'מפגשים בגינה הזו';

  @override
  String get noneAtPark => 'עדיין אין מפגשים בגינה הזו.';

  @override
  String get notifyHere => 'התראה על מודעה חדשה כאן';

  @override
  String get notifySaveFirst => 'אפשר לשמור את הגינה ב״הגינות שלי״ ולקבל התראה על מודעות חדשות כאן.';

  @override
  String get notifyFailed => 'לא הצלחנו לשמור. אפשר לנסות שוב.';

  @override
  String cardMeetupsWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מפגשים השבוע',
      two: 'שני מפגשים השבוע',
      one: 'מפגש אחד השבוע',
    );
    return '$_temp0';
  }

  @override
  String get cardMeetupToday => 'מפגש היום';

  @override
  String get memberAds => 'מודעות לטיול ולמשחק';

  @override
  String get addPlanWalk => 'תיאום טיול או משחק';

  @override
  String get goingSoonTitle => 'יציאה בקרוב?';

  @override
  String get goingSoonBody => 'עדכון למי ששמרו את הגינות שלך. מוצג 90 דקות.';

  @override
  String get goingNowButton => 'יציאה עכשיו';

  @override
  String get addGoingNow => 'יציאה עכשיו';

  @override
  String goingInTag(int minutes) {
    return 'בעוד $minutes דק׳';
  }

  @override
  String get goingOutTag => 'בחוץ עכשיו';

  @override
  String leavingAt(String time) {
    return 'יציאה ב־\u2068$time\u2069';
  }

  @override
  String get goingWhere => 'לאן';

  @override
  String get goingOtherPark => 'גינה אחרת';

  @override
  String get goingLeavingIn => 'יציאה בעוד';

  @override
  String goingMinutes(int minutes) {
    return '$minutes דק׳';
  }

  @override
  String goingWith(String pet) {
    return 'עם \u2068$pet\u2069';
  }

  @override
  String get goingNoteHint => 'משהו להוסיף? (לא חובה)';

  @override
  String get goingPost => 'פרסום';

  @override
  String get goingPosted => 'פורסם ל־90 הדקות הקרובות';

  @override
  String get goingPickPark => 'צריך לבחור גינה';

  @override
  String get errNowLimit => 'זה כבר שלוש היום. אפשר לפרסם שוב מחר.';
}
