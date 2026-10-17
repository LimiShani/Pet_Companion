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

  @override
  String get urgentLead => 'כל אחד מהסימנים האלה אומר לנסוע לווטרינר עכשיו. מתקשרים בדרך.';

  @override
  String get urgentSectionDog => 'סימנים אצל כלבים';

  @override
  String get urgentSectionCat => 'סימנים אצל חתולים';

  @override
  String get urgentSectionAny => 'סימנים אצל כל חיה';

  @override
  String get urgentOtherNote => 'סימנים שנוגעים רק לכלבים או לחתולים לא מופיעים כאן.';

  @override
  String get noVetFindClinic => 'אין וטרינר שמור? חיפוש מרפאה קרובה';

  @override
  String get sourcesTitle => 'מקורות';

  @override
  String get foodSearchHint => 'חיפוש מזון או צמח';

  @override
  String get foodSearchClear => 'ניקוי החיפוש';

  @override
  String get animalMenuTooltip => 'איזו חיה';

  @override
  String get animalDog => 'כלב';

  @override
  String get animalCat => 'חתול';

  @override
  String get animalBird => 'ציפור';

  @override
  String get animalOther => 'חיות אחרות';

  @override
  String get kindFoods => 'מזונות';

  @override
  String get kindPlants => 'צמחים';

  @override
  String get kindHousehold => 'בבית';

  @override
  String get levelSafe => 'בטוח';

  @override
  String get levelLittle => 'רק מעט';

  @override
  String get levelDangerous => 'מסוכן';

  @override
  String get levelAsk => 'כדאי לשאול את הווטרינר';

  @override
  String get levelNotListed => 'לא ברשימה';

  @override
  String get forDogs => 'לכלבים';

  @override
  String get forCats => 'לחתולים';

  @override
  String get forBirds => 'לציפורים';

  @override
  String forAnimal(String animal, String level) {
    return '\u2068$animal\u2069: \u2068$level\u2069';
  }

  @override
  String foodAlso(String names) {
    return 'גם: \u2068$names\u2069';
  }

  @override
  String get foodCallVet => 'חיוג לווטרינר';

  @override
  String get foodNotSure => 'יש ספק? כדאי להתקשר לווטרינר';

  @override
  String get foodEatenAlready => 'כבר נאכל? כדאי להתקשר גם אם הכול נראה בסדר.';

  @override
  String foodNothing(String text) {
    return 'לא מצאנו ״\u2068$text\u2069״.';
  }

  @override
  String lostStep(int step, int total) {
    return 'שלב $step מתוך $total';
  }

  @override
  String get lostChangePet => 'החלפה';

  @override
  String get lostWhichPet => 'על מי מדובר?';

  @override
  String get lostLastSeen => 'הפעם האחרונה שראינו';

  @override
  String get lostTown => 'יישוב';

  @override
  String get lostTownChoose => 'בחירת יישוב';

  @override
  String get lostTownHint => 'שם היישוב';

  @override
  String get lostTownNeeded => 'צריך לבחור יישוב';

  @override
  String get lostWhere => 'איפה בדיוק?';

  @override
  String get lostWhereHint => 'מקום ציבורי, לא כתובת';

  @override
  String get lostNote => 'משהו שחשוב לדעת?';

  @override
  String get lostNoteHint => 'למשל: לא לרדוף, לקרוא בשם';

  @override
  String get lostNext => 'המשך';

  @override
  String get lostPreviewTitle => 'מה יראו בקהילה';

  @override
  String get lostPostTag => 'אבדה או מציאה';

  @override
  String get lostNow => 'עכשיו';

  @override
  String lostUsePhoto(String name) {
    return 'עם התמונה של \u2068$name\u2069';
  }

  @override
  String lostWhoHears(String town) {
    return 'אנשים באזור \u2068$town\u2069 שמשתמשים ב־PetLoop יקבלו הודעה אחת. דיווחים מגיעים כתגובות.';
  }

  @override
  String get lostCardNext => 'הכרטיס לשיתוף';

  @override
  String get lostCardNextNote => 'מגיע מיד אחר כך, ממולא';

  @override
  String get lostStart => 'הפעלת מצב אבדה';

  @override
  String get lostStarted => 'מצב אבדה פעיל. אנשים באזור מקבלים הודעה.';

  @override
  String lostAlertTitle(String name) {
    return 'מחפשים את \u2068$name\u2069';
  }

  @override
  String lostSince(String when) {
    return 'מאז \u2068$when\u2069';
  }

  @override
  String get lostSightings => 'דיווחים';

  @override
  String get lostNoSightings => 'עוד אין דיווחים. שיתוף הכרטיס יגיע לעוד אנשים.';

  @override
  String get lostSightingsFailed => 'לא הצלחנו לטעון את התגובות';

  @override
  String get lostOpenPost => 'לפוסט';

  @override
  String get lostShareCard => 'שיתוף הכרטיס';

  @override
  String lostHome(String name) {
    return '\u2068$name\u2069 בבית';
  }

  @override
  String get lostClose => 'סגירת ההתראה';

  @override
  String get lostCloseQuestion => 'לסגור את ההתראה בלי ״נמצא״?';

  @override
  String get lostCloseNote => 'אם עוד אף אחד לא הגיב, גם הפוסט יוסר.';

  @override
  String get lostCloseConfirm => 'סגירה';

  @override
  String get lostKeepLooking => 'ממשיכים לחפש';

  @override
  String get lostFoundDone => 'חדשות טובות. ההתראה נסגרה.';

  @override
  String get lostClosedDone => 'ההתראה נסגרה.';

  @override
  String lostErrActive(String name) {
    return 'כבר יש התראה פתוחה עבור \u2068$name\u2069.';
  }

  @override
  String get lostErrRate => 'כבר נפתחו היום שלוש התראות. אפשר לנסות שוב מחר.';

  @override
  String get lostErrInvalid => 'משהו כאן לא תקין. כדאי לבדוק את המקום ואת השעה.';

  @override
  String get lostErrNotAllowed => 'מצב אבדה לא זמין בחשבון הזה.';

  @override
  String get lostErrGeneric => 'לא הצלחנו. אפשר לנסות שוב.';
}
