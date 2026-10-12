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
  String get scopeMenuTooltip => 'בחירת סוג החיה';

  @override
  String get tagOtherAnimals => 'חיות אחרות';

  @override
  String get forDogs => 'עבור כלבים';

  @override
  String get forCats => 'עבור חתולים';

  @override
  String get forOtherAnimals => 'עבור חיות אחרות';

  @override
  String get noRoomsForDogs => 'עדיין אין חדרים עבור כלבים. בחירה ב״הכול״ מציגה את כל החדרים.';

  @override
  String get noRoomsForCats => 'עדיין אין חדרים עבור חתולים. בחירה ב״הכול״ מציגה את כל החדרים.';

  @override
  String get feedLoadFailed => 'לא הצלחנו לטעון את הפיד';

  @override
  String get noPostsTitle => 'עדיין אין פוסטים';

  @override
  String get noPostsMessage => 'הפוסט הראשון יכול להיות שלך: תמונה או סיפור על החיה שלך.';

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
  String get deletePostBody => 'התגובות והלייקים שלו יימחקו יחד איתו. אי אפשר לבטל את הפעולה הזאת.';

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
  String get roomHealthAbout => 'אפשר לשאול בעלי חיות אחרים. בכל דבר דחוף כדאי לפנות לווטרינר';

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
  String reviewedByName(String name) {
    return 'נבדק על ידי \u2068$name\u2069';
  }

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
  String get guideDisclaimer => 'המדריך נותן מידע כללי ואינו תחליף לייעוץ של וטרינר.';

  @override
  String get adviceNotice => 'חברי הקהילה משתפים מניסיון אישי, לא ייעוץ מקצועי.';

  @override
  String get adviceHide => 'הסתרה';

  @override
  String get contactProfessional => 'פנייה לאיש מקצוע';

  @override
  String get errUnreachable => 'לא הצלחנו להתחבר לקהילה כרגע. אפשר לנסות שוב.';

  @override
  String get errChatUnreachable => 'לא הצלחנו להתחבר לצ׳אט כרגע. אפשר לנסות שוב.';

  @override
  String get errOffline => 'אין חיבור לקהילה כרגע. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

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
  String get errPhotoTooLarge => 'התמונה גדולה מדי. אפשר לבחור תמונה קטנה יותר.';

  @override
  String get errPhotoUnsupported => 'צריך לבחור תמונה מסוג JPEG, PNG או WebP.';

  @override
  String get errPhotoUpload => 'לא הצלחנו להעלות את התמונה. אפשר לנסות שוב.';

  @override
  String get errCameraNotAllowed => 'אי אפשר לפתוח את המצלמה. כדאי לבדוק שיש ל־PetLoop הרשאה להשתמש בה.';

  @override
  String get errPhotosNotAllowed => 'אי אפשר לפתוח את התמונות שלך. כדאי לבדוק שיש ל־PetLoop הרשאה לראות אותן.';

  @override
  String get errSlowDown => 'רגע, זה היה מהר. כדאי לחכות דקה לפני שליחה נוספת.';

  @override
  String get errNotModerator => 'רק מנהלי הקהילה יכולים לעשות את זה.';

  @override
  String roomLastMine(String text) {
    return 'אני: \u2068$text\u2069';
  }

  @override
  String roomLastOther(String name, String text) {
    return '\u2068$name\u2069: \u2068$text\u2069';
  }

  @override
  String roomUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הודעות שלא נקראו',
      two: 'שתי הודעות שלא נקראו',
      one: 'הודעה אחת שלא נקראה',
    );
    return '$_temp0';
  }

  @override
  String get chatReply => 'תשובה';

  @override
  String get chatCopy => 'העתקה';

  @override
  String get chatCopied => 'ההודעה הועתקה';

  @override
  String get chatDeleteTitle => 'למחוק את ההודעה?';

  @override
  String get chatDeleteBody => 'היא תימחק אצל כל מי שבחדר.';

  @override
  String get chatDeleted => 'ההודעה נמחקה';

  @override
  String get chatReportTitle => 'דיווח על ההודעה';

  @override
  String get chatReportBody => 'מה לא בסדר בהודעה? נסתיר אותה אצלך מיד ונבדוק אותה.';

  @override
  String get chatReportThanks => 'תודה. הסתרנו את ההודעה ונבדוק אותה.';

  @override
  String get commentOptions => 'אפשרויות התגובה';

  @override
  String get commentReportTitle => 'דיווח על התגובה';

  @override
  String get commentReportBody => 'מה לא בסדר בתגובה? נסתיר אותה אצלך מיד ונבדוק אותה.';

  @override
  String get commentReportThanks => 'תודה. הסתרנו את התגובה ונבדוק אותה.';

  @override
  String get messageOptions => 'אפשרויות ההודעה';

  @override
  String replyingTo(String name) {
    return 'תשובה אל \u2068$name\u2069';
  }

  @override
  String get cancelReply => 'ביטול התשובה';

  @override
  String get replyUnavailable => 'ההודעה המקורית אינה זמינה';

  @override
  String get messageSending => 'בשליחה…';

  @override
  String get messageNotSent => 'לא נשלחה. אפשר להקיש כדי לנסות שוב.';

  @override
  String get messageNotSentTitle => 'ההודעה לא נשלחה';

  @override
  String newMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הודעות חדשות',
      two: 'שתי הודעות חדשות',
      one: 'הודעה חדשה',
    );
    return '$_temp0';
  }

  @override
  String get jumpToLatest => 'מעבר להודעה האחרונה';

  @override
  String get conversationStart => 'כאן מתחילה השיחה';

  @override
  String get addPhoto => 'הוספת תמונה';

  @override
  String get chatPhotoPreview => 'התמונה לשליחה';

  @override
  String get openPhoto => 'פתיחת התמונה';

  @override
  String reactWith(String emoji) {
    return 'סימון \u2068$emoji\u2069';
  }

  @override
  String reactionsSummary(String emoji, int count) {
    return '\u2068$emoji\u2069 $count';
  }

  @override
  String get roomInfo => 'על החדר';

  @override
  String blockMember(String name) {
    return 'חסימת \u2068$name\u2069';
  }

  @override
  String blockTitle(String name) {
    return 'לחסום את \u2068$name\u2069?';
  }

  @override
  String get blockBody => 'הפוסטים, התגובות וההודעות לא יופיעו אצלך יותר. אף אחד לא מקבל על כך הודעה. אפשר לבטל את החסימה בכל עת במסך ״בטיחות בקהילה״.';

  @override
  String get blockConfirm => 'חסימה';

  @override
  String blockedDone(String name) {
    return 'חסמת את \u2068$name\u2069';
  }

  @override
  String get unblock => 'ביטול החסימה';

  @override
  String unblockedDone(String name) {
    return 'החסימה של \u2068$name\u2069 בוטלה';
  }

  @override
  String get rulesTitle => 'כללי הקהילה';

  @override
  String get rulesIntro => 'PetLoop הוא מקום ידידותי לבעלי חיות. לפני השיתוף הראשון:';

  @override
  String get rule1 => 'שומרים על אדיבות. מתווכחים עם רעיונות, לא עם אנשים.';

  @override
  String get rule2 => 'בלי מכירת בעלי חיים, בלי פרסומות ובלי ספאם.';

  @override
  String get rule3 => 'משתפים ניסיון, לא אבחנות. בכל דבר דחוף פונים לווטרינר.';

  @override
  String get rule4 => 'פרטים אישיים נשארים פרטיים, שלך ושל אחרים.';

  @override
  String get rule5 => 'מדווחים על מה שמפר את הכללים. שלושה דיווחים מסתירים תוכן עד שמנהל קהילה יבדוק אותו.';

  @override
  String get rulesAgree => 'הסכמה והמשך';

  @override
  String get safetyTitle => 'בטיחות בקהילה';

  @override
  String get safetyIntro => 'חסימה ודיווח הם פרטיים: אף אחד לא יודע מי ביצע אותם.';

  @override
  String get blockedTitle => 'חשבונות חסומים';

  @override
  String get noBlocked => 'אין חשבונות חסומים.';

  @override
  String get blockedLoadFailed => 'אי אפשר לטעון את החשבונות החסומים';

  @override
  String get reviewReports => 'בדיקת דיווחים';

  @override
  String reviewWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דיווחים ממתינים',
      two: 'שני דיווחים ממתינים',
      one: 'דיווח אחד ממתין',
      zero: 'אין דיווחים ממתינים',
    );
    return '$_temp0';
  }

  @override
  String get reviewEmptyTitle => 'הכול נקי';

  @override
  String get reviewEmptyMessage => 'אין דיווחים שממתינים לבדיקה.';

  @override
  String get reviewLoadFailed => 'אי אפשר לטעון את הדיווחים';

  @override
  String get kindPost => 'פוסט';

  @override
  String get kindComment => 'תגובה';

  @override
  String get kindMessage => 'הודעה בצ׳אט';

  @override
  String get kindMeetup => 'מודעת שותפים';

  @override
  String reportCountLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דיווחים',
      two: 'שני דיווחים',
      one: 'דיווח אחד',
    );
    return '$_temp0';
  }

  @override
  String get hiddenTag => 'מוסתר';

  @override
  String inRoom(String room) {
    return 'בחדר ״\u2068$room\u2069״';
  }

  @override
  String get keepItem => 'השארה';

  @override
  String get removeItem => 'הסרה';

  @override
  String get removeItemTitle => 'להסיר את התוכן אצל כולם?';

  @override
  String get removeItemBody => 'התוכן יימחק ואי אפשר יהיה לשחזר אותו.';

  @override
  String get keptDone => 'התוכן נשאר ומוצג שוב לכולם.';

  @override
  String get removedDone => 'התוכן הוסר';

  @override
  String get kindMoment => 'רגע';

  @override
  String get kindQuestion => 'שאלה';

  @override
  String get kindTip => 'טיפ';

  @override
  String get kindRecommendation => 'המלצה';

  @override
  String get kindLostFound => 'אבדות ומציאות';

  @override
  String get kindsAll => 'כל הפוסטים';

  @override
  String get composerKind => 'איזה סוג פוסט?';

  @override
  String get composerHintQuestion => 'מה רוצים לשאול בעלי חיות אחרים?';

  @override
  String get composerHintTip => 'משהו שעבד אצלך ושכדאי לשתף';

  @override
  String get composerHintRecommendation => 'מקום, מוצר או איש מקצוע שמומלצים, ולמה';

  @override
  String get composerHintLostFound => 'תיאור החיה, איפה ומתי, ואיך אפשר ליצור קשר';

  @override
  String get searchPosts => 'חיפוש פוסטים';

  @override
  String get searchPostsHint => 'חיפוש פוסטים';

  @override
  String get noPostsMatchTitle => 'לא נמצאו פוסטים';

  @override
  String get noPostsMatchMessage => 'אפשר לנסות מילים אחרות, סוג פוסט אחר או ״הכול״.';

  @override
  String get loadingMorePosts => 'טוענים עוד פוסטים';

  @override
  String get editPost => 'עריכה';

  @override
  String get editPostTitle => 'עריכת הפוסט';

  @override
  String get saveChanges => 'שמירה';

  @override
  String get postEdited => 'נערך';

  @override
  String get postSaved => 'הפוסט עודכן';

  @override
  String get sharePost => 'שיתוף';

  @override
  String shareText(String name, String text) {
    return '\u2068$name\u2069 ב־PetLoop: \u2068$text\u2069';
  }

  @override
  String get answeredTag => 'נענתה';

  @override
  String get helpfulAnswer => 'תשובה מועילה';

  @override
  String get markHelpful => 'סימון כתשובה המועילה';

  @override
  String get unmarkHelpful => 'ביטול הסימון כתשובה מועילה';

  @override
  String get markedHelpful => 'סומנה כתשובה המועילה';

  @override
  String get likedByDoubleTap => 'לייק';

  @override
  String get activityTitle => 'פעילות';

  @override
  String get activityTooltip => 'פעילות';

  @override
  String get activityNew => 'יש פעילות חדשה';

  @override
  String get activityEmptyTitle => 'אין עדיין חדש';

  @override
  String get activityEmptyMessage => 'תגובות, לייקים ותשובות לפוסטים ולהודעות שלך יופיעו כאן.';

  @override
  String get activityLoadFailed => 'אי אפשר לטעון את הפעילות';

  @override
  String activityComment(String name) {
    return 'תגובה חדשה מ־\u2068$name\u2069 לפוסט שלך';
  }

  @override
  String activityLike(String name) {
    return 'לייק מ־\u2068$name\u2069 לפוסט שלך';
  }

  @override
  String activityReply(String name) {
    return 'תשובה מ־\u2068$name\u2069 להודעה שלך';
  }

  @override
  String get memberTitle => 'פרופיל';

  @override
  String memberSince(String date) {
    return 'בקהילה מאז \u2068$date\u2069';
  }

  @override
  String memberPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פוסטים',
      two: 'שני פוסטים',
      one: 'פוסט אחד',
      zero: 'עדיין אין פוסטים',
    );
    return '$_temp0';
  }

  @override
  String get memberPosts => 'פוסטים';

  @override
  String get memberLoadFailed => 'אי אפשר לטעון את הפרופיל';

  @override
  String get memberGoneTitle => 'הפרופיל לא נמצא';

  @override
  String get memberGoneMessage => 'ייתכן שהחשבון נמחק.';

  @override
  String openProfile(String name) {
    return 'פתיחת הפרופיל של \u2068$name\u2069';
  }

  @override
  String get editProfile => 'עריכת הפרופיל';

  @override
  String get profileBio => 'קצת עליי';

  @override
  String get profileBioHint => 'שורה שחברי הקהילה רואים, למשל על החיות שלך או על מה כיף לך לדבר';

  @override
  String get profileCity => 'עיר';

  @override
  String get profileCityHint => 'לא חובה';

  @override
  String get profileSaved => 'הפרופיל עודכן';

  @override
  String get profilePublicNote => 'חברי הקהילה רואים את זה. כדאי להשאיר בחוץ כל מה שעדיף שיישאר פרטי.';

  @override
  String get blockedMemberNote => 'החשבון הזה חסום אצלך.';

  @override
  String get muteRoom => 'השתקת החדר';

  @override
  String get unmuteRoom => 'ביטול ההשתקה';

  @override
  String get roomMuted => 'החדר מושתק: לא יוצג בו מספר הודעות שלא נקראו';

  @override
  String get roomUnmuted => 'ההשתקה בוטלה';

  @override
  String get mutedTag => 'מושתק';

  @override
  String get pushTitle => 'קהילה';

  @override
  String get pushReplies => 'תשובות להודעות שלי בצ׳אט';

  @override
  String get pushComments => 'תגובות לפוסטים שלי';

  @override
  String get pushLikes => 'לייקים לפוסטים שלי';

  @override
  String get pushLikesNote => 'לכל היותר אחת לכל פוסט בשעה.';

  @override
  String get pushNote => 'נשלח לטלפון הזה גם כשהאפליקציה סגורה. חשבונות שחסמת לא ישלחו לך התראות.';

  @override
  String get pushLoadFailed => 'אי אפשר לטעון את הבחירות שלך להתראות';

  @override
  String get errChatFull => 'בשיחה יכולים להיות עד 30 משתתפים.';

  @override
  String get errNotChatAdmin => 'רק מנהלי השיחה יכולים לעשות את זה.';

  @override
  String get errCannotInvite => 'את מי שבחרת אי אפשר להזמין לשיחה.';

  @override
  String get errChatClosed => 'השיחה הזו סגורה.';

  @override
  String get myChats => 'השיחות שלי';

  @override
  String get topicRooms => 'חדרי נושא';

  @override
  String get newChat => 'שיחה חדשה';

  @override
  String get noPrivateChats => 'אפשר לפתוח שיחה פרטית עם חברי הקהילה, כאן או מהדף של כל חבר.';

  @override
  String get privateChatsLoadFailed => 'אי אפשר לטעון את השיחות שלך';

  @override
  String get privateChat => 'שיחה פרטית';

  @override
  String participantCount(int count) {
    return 'משתתפים: $count';
  }

  @override
  String invitationFrom(String name) {
    return 'הזמנה מ־\u2068$name\u2069';
  }

  @override
  String invitationDirect(String name) {
    return '\u2068$name\u2069 רוצה לדבר איתך';
  }

  @override
  String get joinChat => 'הצטרפות';

  @override
  String get declineInvitation => 'לא, תודה';

  @override
  String get invitationDeclined => 'ההזמנה נדחתה';

  @override
  String get invitationJoinNote => 'אחרי ההצטרפות אפשר לראות את ההודעות ולכתוב.';

  @override
  String get invitationsTitle => 'הזמנות';

  @override
  String sysCreated(String name) {
    return 'השיחה נפתחה על ידי \u2068$name\u2069';
  }

  @override
  String get sysCreatedMine => 'פתחת את השיחה';

  @override
  String sysAdded(String name, String people) {
    return 'הזמנה מ־\u2068$name\u2069 אל \u2068$people\u2069';
  }

  @override
  String sysAddedMine(String people) {
    return 'הזמנת את \u2068$people\u2069';
  }

  @override
  String sysAddedYou(String name) {
    return 'קיבלת הזמנה מ־\u2068$name\u2069';
  }

  @override
  String sysAddedYouAnd(String name, String people) {
    return 'קיבלת הזמנה מ־\u2068$name\u2069, יחד עם \u2068$people\u2069';
  }

  @override
  String sysJoined(String name) {
    return '\u2068$name\u2069 בשיחה';
  }

  @override
  String get sysJoinedMine => 'הצטרפת לשיחה';

  @override
  String sysLeft(String name) {
    return '\u2068$name\u2069 כבר לא בשיחה';
  }

  @override
  String get sysLeftMine => 'יצאת מהשיחה';

  @override
  String sysRemoved(String name, String people) {
    return 'הסרה של \u2068$people\u2069 מהשיחה, על ידי \u2068$name\u2069';
  }

  @override
  String sysRemovedMine(String people) {
    return 'הסרת את \u2068$people\u2069 מהשיחה';
  }

  @override
  String sysAdmin(String name, String people) {
    return 'ניהול השיחה עבר גם אל \u2068$people\u2069, על ידי \u2068$name\u2069';
  }

  @override
  String sysAdminMine(String people) {
    return 'מינית את \u2068$people\u2069 לניהול השיחה';
  }

  @override
  String sysAdminYou(String name) {
    return 'קיבלת הרשאת ניהול מ־\u2068$name\u2069';
  }

  @override
  String sysRenamed(String name, String title) {
    return 'שם השיחה שונה ל־״\u2068$title\u2069״ על ידי \u2068$name\u2069';
  }

  @override
  String sysRenamedMine(String title) {
    return 'שינית את שם השיחה ל־״\u2068$title\u2069״';
  }

  @override
  String get chatDetails => 'פרטי השיחה';

  @override
  String get addParticipants => 'הוספת משתתפים';

  @override
  String get adminTag => 'ניהול';

  @override
  String get invitedTag => 'הזמנה נשלחה';

  @override
  String get youTag => 'אני';

  @override
  String get makeAdmin => 'מינוי לניהול השיחה';

  @override
  String get removeFromChat => 'הסרה מהשיחה';

  @override
  String get cancelInvitation => 'ביטול ההזמנה';

  @override
  String memberOptions(String name) {
    return 'אפשרויות עבור \u2068$name\u2069';
  }

  @override
  String removeMemberTitle(String name) {
    return 'להסיר את \u2068$name\u2069 מהשיחה?';
  }

  @override
  String get removeMemberBody => 'מי שמוסר מהשיחה כבר לא רואה אותה ואת ההודעות שבה.';

  @override
  String get memberRemovedDone => 'ההסרה בוצעה';

  @override
  String get muteChat => 'השתקת השיחה';

  @override
  String get chatMutedNote => 'מושתקת: בלי התראות ובלי מספר הודעות שלא נקראו';

  @override
  String get leaveChat => 'יציאה מהשיחה';

  @override
  String get leaveChatTitle => 'לצאת מהשיחה?';

  @override
  String get leaveChatBody => 'השיחה וההודעות שבה לא יופיעו אצלך יותר.';

  @override
  String get leave => 'יציאה';

  @override
  String get renameChat => 'שינוי שם';

  @override
  String get chatRenamed => 'שם השיחה שונה';

  @override
  String get chatNameLabel => 'שם השיחה';

  @override
  String get chatNameHint => 'למשל: טיולי בוקר בפארק';

  @override
  String invitationsSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ההזמנות נשלחו',
      one: 'ההזמנה נשלחה',
    );
    return '$_temp0';
  }

  @override
  String get searchPeople => 'חיפוש לפי שם';

  @override
  String selectedCount(int count) {
    return 'נבחרו: $count';
  }

  @override
  String get recentPeople => 'דיברת איתם לאחרונה';

  @override
  String get communityMembersTitle => 'חברי הקהילה';

  @override
  String get noPeopleFound => 'לא מצאנו אף אחד בשם הזה';

  @override
  String get peopleLoadFailed => 'אי אפשר לטעון את חברי הקהילה';

  @override
  String get nextStep => 'המשך';

  @override
  String get createChat => 'יצירת השיחה';

  @override
  String get groupNameTitle => 'שם לשיחה';

  @override
  String get groupNameNote => 'כל המשתתפים רואים את השם.';

  @override
  String removePerson(String name) {
    return 'הסרת \u2068$name\u2069';
  }

  @override
  String participantsLimit(int count) {
    return 'עד $count משתתפים בשיחה';
  }

  @override
  String get addToChat => 'הוספה';

  @override
  String get privateMessage => 'הודעה פרטית';

  @override
  String chatBlockedNote(String name) {
    return 'חסמת את \u2068$name\u2069. אחרי ביטול החסימה אפשר לכתוב כאן שוב.';
  }

  @override
  String otherLeftNote(String name) {
    return '\u2068$name\u2069 כבר לא בשיחה הזו.';
  }

  @override
  String get inviteAgain => 'הזמנה מחדש';

  @override
  String get chatGoneTitle => 'השיחה הזו כבר לא כאן';

  @override
  String get chatGoneMessage => 'אולי היא נמחקה, או שיצאת ממנה.';

  @override
  String get inPrivateChat => 'בשיחה פרטית';

  @override
  String get pushPrivateMessages => 'הודעות בשיחות הפרטיות שלי';

  @override
  String get pushChatInvites => 'הזמנות לשיחה';
}
