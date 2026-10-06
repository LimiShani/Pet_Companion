// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'community_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class CommunityL10nHe extends CommunityL10n {
  CommunityL10nHe([String locale = 'he']) : super(locale);

  @override
  String get tabTitle => 'קהילה';

  @override
  String get sectionFeed => 'פיד';

  @override
  String get sectionChat => 'צ׳אט';

  @override
  String get sectionGuides => 'מדריכים';

  @override
  String get newPost => 'פוסט חדש';

  @override
  String get scopeDogs => 'כלבים';

  @override
  String get scopeCats => 'חתולים';

  @override
  String get scopeEverything => 'הכול';

  @override
  String get tagOtherAnimals => 'חיות אחרות';

  @override
  String get forDogs => 'עבור כלבים';

  @override
  String get forCats => 'עבור חתולים';

  @override
  String get forOtherAnimals => 'עבור חיות אחרות';

  @override
  String roomsMatchedTo(String pet) {
    return 'מותאם עבור \u2068$pet\u2069. לחיצה על ״הכול״ מציגה את כל החדרים.';
  }

  @override
  String guidesMatchedTo(String pet) {
    return 'מותאם עבור \u2068$pet\u2069. לחיצה על ״הכול״ מציגה את כל המדריכים.';
  }

  @override
  String get roomsShownForDogs => 'מוצגים חדרים עבור כלבים.';

  @override
  String get roomsShownForCats => 'מוצגים חדרים עבור חתולים.';

  @override
  String get roomsShownForAll => 'מוצגים החדרים של כל החיות.';

  @override
  String get guidesShownForDogs => 'מוצגים מדריכים עבור כלבים.';

  @override
  String get guidesShownForCats => 'מוצגים מדריכים עבור חתולים.';

  @override
  String get guidesShownForAll => 'מוצגים המדריכים של כל החיות.';

  @override
  String get noRoomsForDogs =>
      'עדיין אין חדרים עבור כלבים. לחיצה על ״הכול״ מציגה את כל החדרים.';

  @override
  String get noRoomsForCats =>
      'עדיין אין חדרים עבור חתולים. לחיצה על ״הכול״ מציגה את כל החדרים.';

  @override
  String get feedLoadFailed => 'לא הצלחנו לטעון את הפיד';

  @override
  String get noPostsTitle => 'עדיין אין פוסטים';

  @override
  String get noPostsMessage =>
      'הפוסט הראשון יכול להיות שלך: תמונה או סיפור על החיה שלך.';

  @override
  String get writeAPost => 'כתיבת פוסט';

  @override
  String postWithPet(String pet) {
    return 'עם \u2068$pet\u2069';
  }

  @override
  String get memberFallbackName => 'אוהבי חיות';

  @override
  String get timeJustNow => 'ממש עכשיו';

  @override
  String timeMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'לפני $minutes דקות',
      two: 'לפני שתי דקות',
      one: 'לפני דקה',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'לפני $hours שעות',
      two: 'לפני שעתיים',
      one: 'לפני שעה',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'לפני $days ימים',
      two: 'לפני יומיים',
      one: 'לפני יום',
    );
    return '$_temp0';
  }

  @override
  String get postOptions => 'אפשרויות הפוסט';

  @override
  String get report => 'דיווח';

  @override
  String get like => 'לייק';

  @override
  String get unlike => 'ביטול הלייק';

  @override
  String get comments => 'תגובות';

  @override
  String likeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count לייקים',
      two: 'שני לייקים',
      one: 'לייק אחד',
      zero: 'אין לייקים',
    );
    return '$_temp0';
  }

  @override
  String commentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תגובות',
      two: 'שתי תגובות',
      one: 'תגובה אחת',
      zero: 'אין תגובות',
    );
    return '$_temp0';
  }

  @override
  String get photoLabel => 'תמונה';

  @override
  String get reportThanks => 'תודה. הסתרנו את הפוסט ונבדוק אותו.';

  @override
  String get deletePostTitle => 'למחוק את הפוסט?';

  @override
  String get deletePostBody =>
      'התגובות והלייקים שלו יימחקו יחד איתו. אי אפשר לבטל את הפעולה הזאת.';

  @override
  String get postDeleted => 'הפוסט שלך נמחק.';

  @override
  String get reportTitle => 'דיווח על הפוסט';

  @override
  String get reportBody => 'מה לא בסדר בפוסט? נסתיר אותו אצלך מיד ונבדוק אותו.';

  @override
  String get reportSpam => 'ספאם או פרסומת';

  @override
  String get reportAbusive => 'פוגעני או לא מכבד';

  @override
  String get reportInappropriate => 'לא הולם או מטריד';

  @override
  String get reportOther => 'משהו אחר';

  @override
  String get postButton => 'פרסום';

  @override
  String get composerAudience => 'הפוסט גלוי לכל הקהילה';

  @override
  String get composerHint => 'מה חדש אצל החיה שלך?';

  @override
  String get composerAbout => 'על מי הפוסט';

  @override
  String get composerPhoto => 'תמונה';

  @override
  String get composerPhotoPreview => 'התמונה של הפוסט';

  @override
  String get removePhoto => 'הסרת התמונה';

  @override
  String get gallery => 'גלריה';

  @override
  String get camera => 'מצלמה';

  @override
  String get discardTitle => 'לוותר על הפוסט?';

  @override
  String get discardBody => 'מה שכתבת לא יישמר.';

  @override
  String get keepWriting => 'להמשיך לכתוב';

  @override
  String get discard => 'לוותר';

  @override
  String get postTitle => 'פוסט';

  @override
  String get postGoneTitle => 'הפוסט כבר לא זמין';

  @override
  String get postGoneMessage => 'ייתכן שהוא נמחק.';

  @override
  String get backToFeed => 'חזרה לפיד';

  @override
  String get commentHint => 'הוספת תגובה';

  @override
  String get sendComment => 'שליחת התגובה';

  @override
  String get commentsLoadFailed => 'לא הצלחנו לטעון את התגובות.';

  @override
  String get noComments => 'עדיין אין תגובות. התגובה הראשונה יכולה להיות שלך.';

  @override
  String messageHint(String room) {
    return 'הודעה בחדר ״\u2068$room\u2069״';
  }

  @override
  String get sendMessage => 'שליחת ההודעה';

  @override
  String get chatLoadFailed => 'לא הצלחנו לטעון את השיחה';

  @override
  String get noMessagesTitle => 'עדיין אין הודעות';

  @override
  String get noMessagesMessage => 'אפשר לכתוב שלום ולהתחיל את השיחה.';

  @override
  String get ownMessage => 'ההודעה שלך';

  @override
  String get roomsLoadFailed => 'לא הצלחנו לטעון את חדרי הצ׳אט';

  @override
  String get noRoomsTitle => 'עדיין אין חדרי צ׳אט';

  @override
  String get noRoomsMessage => 'חדרים יופיעו כאן ברגע שייפתחו.';

  @override
  String get roomGeneral => 'כללי';

  @override
  String get roomGeneralAbout => 'אפשר להגיד שלום ולשתף איך עבר היום';

  @override
  String get roomPuppies => 'גורים';

  @override
  String get roomPuppiesAbout => 'השבועות הראשונים, בקיעת שיניים ושינה';

  @override
  String get roomTraining => 'טיפים לאילוף';

  @override
  String get roomTrainingAbout => 'מה עובד, צעד קטן בכל פעם';

  @override
  String get roomSeniors => 'כלבים מבוגרים';

  @override
  String get roomSeniorsAbout => 'נוחות וטיפול לחברים הוותיקים';

  @override
  String get roomKittens => 'גורי חתולים';

  @override
  String get roomKittensAbout => 'השבועות הראשונים, הרגלי ארגז החול ומשחק';

  @override
  String get roomCatLitter => 'חול וניקיון';

  @override
  String get roomCatLitterAbout => 'חול, ריח וכמה ארגזים צריך';

  @override
  String get roomCatBehaviour => 'התנהגות ומשחק של חתולים';

  @override
  String get roomCatBehaviourAbout => 'שריטות, מרץ בלילה, חתול שני בבית';

  @override
  String get roomSeniorCats => 'חתולים מבוגרים';

  @override
  String get roomSeniorCatsAbout => 'נוחות וטיפול לחתולים מבוגרים';

  @override
  String get roomHealth => 'שאלות בריאות';

  @override
  String get roomHealthAbout =>
      'אפשר לשאול בעלי חיות אחרים. בכל דבר דחוף כדאי לפנות לווטרינר';

  @override
  String get guidesLoadFailed => 'לא הצלחנו לטעון את המדריכים';

  @override
  String get searchGuides => 'חיפוש מדריכים';

  @override
  String get clearSearch => 'ניקוי החיפוש';

  @override
  String get categoryAll => 'הכול';

  @override
  String get categoryStart => 'צעדים ראשונים';

  @override
  String get categoryHome => 'בית וניקיון';

  @override
  String get categoryBehaviour => 'אילוף והתנהגות';

  @override
  String get categoryNutrition => 'תזונה';

  @override
  String get categoryHealth => 'בריאות וטיפוח';

  @override
  String get categorySenior => 'טיפול בגיל מבוגר';

  @override
  String get noGuidesForDogsMatch => 'לא נמצאו מדריכים מתאימים עבור כלבים';

  @override
  String get noGuidesForCatsMatch => 'לא נמצאו מדריכים מתאימים עבור חתולים';

  @override
  String matchesElsewhere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'יש $count התאמות במדריכים של כל החיות.',
      two: 'יש שתי התאמות במדריכים של כל החיות.',
      one: 'יש התאמה אחת במדריכים של כל החיות.',
    );
    return '$_temp0';
  }

  @override
  String get searchEverything => 'חיפוש בכל המדריכים';

  @override
  String get noGuidesMatchTitle => 'לא נמצאו מדריכים מתאימים';

  @override
  String get noGuidesMatchMessage => 'אפשר לנסות מילה אחרת או קטגוריה אחרת.';

  @override
  String readTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes דקות קריאה',
      two: 'שתי דקות קריאה',
      one: 'דקת קריאה',
    );
    return '$_temp0';
  }

  @override
  String guideBy(String author) {
    return 'מאת \u2068$author\u2069';
  }

  @override
  String guideUpdated(String date) {
    return 'עודכן בתאריך \u2068$date\u2069';
  }

  @override
  String get tagEnglishOnly => 'באנגלית בלבד';

  @override
  String get tagReviewed => 'נבדק';

  @override
  String get guideTitle => 'מדריך';

  @override
  String get guideNotFoundTitle => 'המדריך לא נמצא';

  @override
  String get guideNotFoundMessage => 'המדריך הזה כבר לא נמצא בספרייה.';

  @override
  String get backToGuides => 'חזרה למדריכים';

  @override
  String get aboutThisGuide => 'על המדריך הזה';

  @override
  String get writtenBy => 'נכתב על ידי';

  @override
  String get professionalReview => 'בדיקה מקצועית';

  @override
  String get notReviewedByVet => 'לא נבדק על ידי וטרינר';

  @override
  String get reviewedBy => 'נבדק על ידי';

  @override
  String reviewedOn(String date) {
    return 'נבדק בתאריך \u2068$date\u2069';
  }

  @override
  String get lastUpdated => 'עדכון אחרון';

  @override
  String get sources => 'מקורות';

  @override
  String get noSources => 'לא צוינו מקורות';

  @override
  String get noSourcesDetail => 'מידע כללי ומקובל על טיפול בחיות.';

  @override
  String sourceWithPublisher(String title, String publisher) {
    return '\u2068$title\u2069, \u2068$publisher\u2069';
  }

  @override
  String get sourceOpenFailed => 'לא הצלחנו לפתוח את המקור כרגע.';

  @override
  String get guideDisclaimer =>
      'המדריך נותן מידע כללי ואינו תחליף לייעוץ של וטרינר.';

  @override
  String get adviceNotice =>
      'חברי הקהילה משתפים מניסיון אישי, לא ייעוץ מקצועי.';

  @override
  String get contactProfessional => 'פנייה לאיש מקצוע';

  @override
  String get errUnreachable => 'לא הצלחנו להתחבר לקהילה כרגע. אפשר לנסות שוב.';

  @override
  String get errChatUnreachable =>
      'לא הצלחנו להתחבר לצ׳אט כרגע. אפשר לנסות שוב.';

  @override
  String get errOffline =>
      'אין חיבור לקהילה כרגע. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get errPostGone => 'הפוסט הזה כבר לא זמין.';

  @override
  String get errEmptyPost => 'צריך לכתוב משהו לפני הפרסום.';

  @override
  String get errEmptyMessage => 'צריך לכתוב משהו לפני השליחה.';

  @override
  String get errNotYourPost => 'אפשר למחוק רק פוסטים שלך.';

  @override
  String get errSignInAgain => 'צריך להיכנס שוב לחשבון.';

  @override
  String get errNotAllowed => 'אין הרשאה לפעולה הזאת.';

  @override
  String get errTextInvalid => 'הטקסט ריק או ארוך מדי.';

  @override
  String get errGone => 'התוכן הזה כבר לא זמין.';

  @override
  String get errNotSetUp => 'הקהילה עדיין לא הוגדרה בשרת.';

  @override
  String get errPhotoTooLarge =>
      'התמונה גדולה מדי. אפשר לבחור תמונה קטנה יותר.';

  @override
  String get errPhotoUnsupported => 'צריך לבחור תמונה מסוג JPEG, PNG או WebP.';

  @override
  String get errPhotoUpload => 'לא הצלחנו להעלות את התמונה. אפשר לנסות שוב.';

  @override
  String get errCameraNotAllowed =>
      'אי אפשר לפתוח את המצלמה. כדאי לבדוק שיש ל־PetLoop הרשאה להשתמש בה.';

  @override
  String get errPhotosNotAllowed =>
      'אי אפשר לפתוח את התמונות שלך. כדאי לבדוק שיש ל־PetLoop הרשאה לראות אותן.';
}
