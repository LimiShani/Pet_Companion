// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'health_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class HealthL10nHe extends HealthL10n {
  HealthL10nHe([String locale = 'he']) : super(locale);

  @override
  String get tabTitle => 'בריאות';

  @override
  String get sectionOverview => 'סקירה';

  @override
  String get sectionSchedule => 'לוח זמנים';

  @override
  String get sectionHistory => 'היסטוריה';

  @override
  String get sectionInsights => 'תובנות';

  @override
  String get quickLog => 'רישום מהיר';

  @override
  String loadFailedHealth(String name) {
    return 'לא הצלחנו לטעון את נתוני הבריאות של \u2068$name\u2069';
  }

  @override
  String get safetyLine =>
      'PetLoop אף פעם לא יוצרת קשר עם אף אחד בעצמה, ואינה תחליף לייעוץ וטרינרי.';

  @override
  String clearField(String label) {
    return 'ניקוי השדה ״\u2068$label\u2069״';
  }

  @override
  String labelWithValue(String label, String value) {
    return '\u2068$label\u2069: \u2068$value\u2069';
  }

  @override
  String weekdayAndDate(String weekday, String date) {
    return '\u2068$weekday\u2069 \u2068$date\u2069';
  }

  @override
  String weekdayAndTime(String weekday, String time) {
    return '\u2068$weekday\u2069 \u2068$time\u2069';
  }

  @override
  String dayAndTime(String day, String time) {
    return '\u2068$day\u2069 · \u2068$time\u2069';
  }

  @override
  String sectionDetailDay(String day) {
    return '· \u2068$day\u2069';
  }

  @override
  String get change => 'החלפה';

  @override
  String get details => 'פרטים';

  @override
  String get notes => 'הערות';

  @override
  String get notesOptional => 'הערות (לא חובה)';

  @override
  String get notAddedYet => 'עדיין לא נוסף';

  @override
  String get notSet => 'לא נקבע';

  @override
  String get remove => 'הסרה';

  @override
  String removeNamed(String name) {
    return 'הסרת \u2068$name\u2069';
  }

  @override
  String get couldNotOpenShareSheet =>
      'לא הצלחנו לפתוח את חלון השיתוף במכשיר הזה.';

  @override
  String fileSizeMb(String value) {
    return '\u2068$value\u2069 מ״ב';
  }

  @override
  String fileSizeKb(String value) {
    return '\u2068$value\u2069 ק״ב';
  }

  @override
  String fileSizeBytes(String value) {
    return '\u2068$value\u2069 בייט';
  }

  @override
  String countAndLabel(int count, String label) {
    return '$count \u2068$label\u2069';
  }

  @override
  String get weight => 'משקל';

  @override
  String weightDownSince(String weight, String date) {
    return 'ירידה של \u2068$weight\u2069 מאז \u2068$date\u2069';
  }

  @override
  String weightUpSince(String weight, String date) {
    return 'עלייה של \u2068$weight\u2069 מאז \u2068$date\u2069';
  }

  @override
  String weightNoChangeSince(String date) {
    return 'ללא שינוי מאז \u2068$date\u2069';
  }

  @override
  String get daysEveryDay => 'כל יום';

  @override
  String get daysWeekdays => 'ימי חול';

  @override
  String get daysWeekends => 'סוף שבוע';

  @override
  String get dayMon => 'ב׳';

  @override
  String get dayTue => 'ג׳';

  @override
  String get dayWed => 'ד׳';

  @override
  String get dayThu => 'ה׳';

  @override
  String get dayFri => 'ו׳';

  @override
  String get daySat => 'ש׳';

  @override
  String get daySun => 'א׳';

  @override
  String get chooseAtLeastOneDay => 'צריך לבחור לפחות יום אחד.';

  @override
  String get loadFailedContacts => 'לא הצלחנו לטעון את אנשי הקשר';

  @override
  String get loadFailedEmergencyCard => 'לא הצלחנו לטעון את כרטיס החירום';

  @override
  String get loadFailedKit => 'לא הצלחנו לטעון את ערכת החירום';

  @override
  String get loadFailedProfile => 'לא הצלחנו לטעון את פרופיל הבריאות';

  @override
  String get loadFailedVets => 'לא הצלחנו לטעון את הווטרינרים';

  @override
  String get loadFailedRecord => 'לא הצלחנו לטעון את הרשומה';

  @override
  String get loadFailedDocuments => 'לא הצלחנו לטעון את המסמכים';

  @override
  String get loadFailedPhoto => 'לא הצלחנו לטעון את התמונה';

  @override
  String get errOffline =>
      'אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get errSessionEnded => 'החיבור לחשבון הסתיים. צריך להיכנס שוב.';

  @override
  String get errNotAllowed => 'אין הרשאה לפעולה הזאת. כדאי להיכנס שוב לחשבון.';

  @override
  String get errInvalid => 'חלק מהפרטים לא תקינים. כדאי לבדוק אותם ולנסות שוב.';

  @override
  String get errPetNotStored =>
      'החיה הזאת עדיין לא שמורה בחשבון שלך, ולכן אי אפשר לשמור עבורה נתונים.';

  @override
  String get errPetGone => 'החיה הזאת כבר לא ברשימה שלך.';

  @override
  String get errItemGone =>
      'הפריט הזה כבר לא קיים. אפשר לחזור ולפתוח אותו שוב.';

  @override
  String get errRecordGone => 'הרשומה הזאת כבר לא קיימת.';

  @override
  String get errVetGone => 'הווטרינר הזה כבר לא קיים.';

  @override
  String get errMedicineGone => 'התרופה הזאת כבר לא קיימת.';

  @override
  String get errReminderGone => 'התזכורת הזאת כבר לא קיימת.';

  @override
  String get errEntryGone => 'הרישום הזה כבר לא קיים.';

  @override
  String get errFileType => 'אפשר לצרף רק תמונות (JPEG, PNG, WebP) וקובצי PDF.';

  @override
  String get errFileEmpty => 'הקובץ הזה ריק.';

  @override
  String get errFileTooLarge =>
      'הקובץ הזה גדול מ־5 מ״ב. אפשר לבחור קובץ קטן יותר.';

  @override
  String get errFileGone => 'הקובץ הזה כבר לא זמין.';

  @override
  String get errFileNotStored => 'לא הצלחנו לשמור את הקובץ. אפשר לנסות שוב.';

  @override
  String get errFileUnreadable => 'לא הצלחנו לקרוא את הקובץ הזה.';

  @override
  String get errCamera => 'לא הצלחנו לפתוח את המצלמה.';

  @override
  String get errPhotos => 'לא הצלחנו לפתוח את התמונות שלך.';

  @override
  String get errFiles => 'לא הצלחנו לפתוח את הקבצים שלך.';

  @override
  String get errPdf => 'לא הצלחנו להכין את ה־PDF. אפשר לנסות שוב.';

  @override
  String get errLostCard => 'לא הצלחנו להכין את הכרטיס. אפשר לנסות שוב.';

  @override
  String get emergencyButton => 'חירום';

  @override
  String get emergencyContacts => 'אנשי קשר לחירום';

  @override
  String emergencyContactsFor(String name) {
    return 'אנשי קשר לחירום עבור \u2068$name\u2069';
  }

  @override
  String get emergencyContactsNoPhone =>
      'אנשי קשר לחירום. עדיין לא נשמר מספר טלפון';

  @override
  String emergencyContactsForNoPhone(String name) {
    return 'אנשי קשר לחירום עבור \u2068$name\u2069. עדיין לא נשמר מספר טלפון';
  }

  @override
  String emergencySheetTitle(String name) {
    return 'חירום · \u2068$name\u2069';
  }

  @override
  String get emergencySheetSubtitle =>
      'חיוג או הודעה. האפליקציה רק פותחת את החייגן או את ההודעות. החיוג והשליחה בידיים שלך.';

  @override
  String openEmergencyCardOf(String name) {
    return 'לכרטיס החירום של \u2068$name\u2069';
  }

  @override
  String get vetRoleRegular => 'וטרינר קבוע';

  @override
  String get vetRoleEmergency => 'וטרינר חירום (24 שעות)';

  @override
  String get emergencyContact => 'איש קשר לחירום';

  @override
  String addPetsVet(String name) {
    return 'הוספת וטרינר עבור \u2068$name\u2069';
  }

  @override
  String get vetPromptNote => 'טלפון וכתובת, מוכנים למקרה חירום';

  @override
  String noVetSavedFor(String name) {
    return 'עדיין לא נשמר וטרינר עבור \u2068$name\u2069';
  }

  @override
  String get noVetSavedNote =>
      'כדאי להוסיף עכשיו את הטלפון של הווטרינר, כדי שחיוג או הודעה יהיו במרחק שתי לחיצות ברגע שצריך.';

  @override
  String get useSavedVet => 'בחירה בווטרינר שכבר שמרת';

  @override
  String get addNewVet => 'הוספת וטרינר חדש';

  @override
  String get actionCall => 'חיוג';

  @override
  String get actionMessage => 'הודעה';

  @override
  String get actionMap => 'מפה';

  @override
  String get addPhoneNumber => 'הוספת מספר טלפון';

  @override
  String get couldNotOpenPhone => 'לא הצלחנו לפתוח את החייגן';

  @override
  String get copyNumber => 'העתקת המספר';

  @override
  String get couldNotOpenMaps => 'לא הצלחנו לפתוח את אפליקציית המפות';

  @override
  String get copyAddress => 'העתקת הכתובת';

  @override
  String messageTo(String name) {
    return 'הודעה אל \u2068$name\u2069';
  }

  @override
  String get whatIsHappening => 'מה קורה?';

  @override
  String get messagePreviewLabel => 'זה מה שייכתב בהודעה';

  @override
  String greetingOwner(String pet) {
    return 'שלום, אני הבעלים של \u2068$pet\u2069.';
  }

  @override
  String greetingNamed(String owner, String pet) {
    return 'שלום, כאן \u2068$owner\u2069, הבעלים של \u2068$pet\u2069.';
  }

  @override
  String get greetingOwnerNoPet => 'שלום, אני הבעלים של החיה.';

  @override
  String greetingNamedNoPet(String owner) {
    return 'שלום, כאן \u2068$owner\u2069, הבעלים של החיה.';
  }

  @override
  String messagePetLine(String name, String facts) {
    return '\u2068$name\u2069: \u2068$facts\u2069';
  }

  @override
  String messageAllergies(String list) {
    return 'אלרגיות: \u2068$list\u2069';
  }

  @override
  String messageConditions(String list) {
    return 'מחלות רקע: \u2068$list\u2069';
  }

  @override
  String messageMedicines(String list) {
    return 'תרופות: \u2068$list\u2069';
  }

  @override
  String messageMicrochip(String number) {
    return 'שבב: \u2068$number\u2069';
  }

  @override
  String get messageNoneKnown => 'לא ידוע על כאלה';

  @override
  String messageMedicineLine(String name, String instructions) {
    return '\u2068$name\u2069, \u2068$instructions\u2069';
  }

  @override
  String messageDetailsNotLoaded(String name) {
    return 'לא הצלחנו לטעון את הפרטים של \u2068$name\u2069, ולכן יישלחו רק המילים שכתבת.';
  }

  @override
  String get messageDetailsNotLoadedNoPet =>
      'לא הצלחנו לטעון את פרטי החיה, ולכן יישלחו רק המילים שכתבת.';

  @override
  String get removeThisLine => 'הסרת השורה';

  @override
  String get putRemovedLinesBack => 'החזרת השורות שהוסרו';

  @override
  String get openInMessages => 'פתיחה באפליקציית ההודעות';

  @override
  String get openInWhatsApp => 'פתיחה ב־WhatsApp';

  @override
  String get messageFinePrint =>
      'שום דבר לא נשלח עד ללחיצה על ״שליחה״ באפליקציה שנפתחת. במקרה חירום, חיוג מהיר יותר.';

  @override
  String get couldNotOpenWhatsApp => 'לא הצלחנו לפתוח את WhatsApp';

  @override
  String get couldNotOpenMessaging => 'לא הצלחנו לפתוח את אפליקציית ההודעות';

  @override
  String get copyMessage => 'העתקת ההודעה';

  @override
  String get emergencyCardTitle => 'כרטיס חירום';

  @override
  String get shareSummary => 'שיתוף סיכום';

  @override
  String get allergies => 'אלרגיות';

  @override
  String get conditions => 'מחלות רקע';

  @override
  String get noneKnown => 'לא ידוע על כאלה';

  @override
  String get activeMedicines => 'תרופות פעילות';

  @override
  String get microchip => 'שבב';

  @override
  String get notChipped => 'אין שבב';

  @override
  String get allergiesAndConditions => 'אלרגיות ומחלות רקע';

  @override
  String get nothingSavedTapProfile =>
      'עדיין לא נשמר כלום. לחיצה כאן פותחת את פרופיל הבריאות למילוי.';

  @override
  String petsVets(String name) {
    return 'הווטרינרים של \u2068$name\u2069';
  }

  @override
  String get editHealthProfile => 'עריכת פרופיל הבריאות';

  @override
  String get emergencyCardFinePrint =>
      'האפליקציה רק פותחת את החייגן או את ההודעות. החיוג והשליחה בידיים שלך. PetLoop אף פעם לא יוצרת קשר עם אף אחד בעצמה, ואינה תחליף לייעוץ וטרינרי.';

  @override
  String get emergencyKit => 'ערכת חירום';

  @override
  String petsEmergencyKit(String name) {
    return 'ערכת החירום של \u2068$name\u2069';
  }

  @override
  String kitAllReady(int total) {
    return 'כל $total הפריטים מוכנים';
  }

  @override
  String kitSomeReady(int ready, int total) {
    return '$ready מתוך $total מוכנים';
  }

  @override
  String get kitWhatToHaveReady => 'מה כדאי שיהיה מוכן';

  @override
  String get kitSummaryNote =>
      'לאזעקות, למעבר מהיר למרחב המוגן או ליציאה מהירה מהבית.';

  @override
  String get kitCarrierDog => 'כלוב נשיאה, רצועה ורתמה';

  @override
  String get kitCarrier => 'כלוב נשיאה';

  @override
  String get kitTravelCage => 'כלוב נסיעות';

  @override
  String get kitTravelBox => 'קופסת נשיאה';

  @override
  String get kitCarrierOrCage => 'כלוב נשיאה או כלוב נסיעות';

  @override
  String get kitCarrierNote => 'בהישג יד, ליד הדלת.';

  @override
  String get kitFoodWater => 'אוכל ומים לשלושה ימים';

  @override
  String get kitFoodWaterNote => 'עם קערה, בתיק אחד.';

  @override
  String get kitDocuments => 'מסמכים';

  @override
  String get kitDocumentsNoteDog => 'פנקס חיסונים ורישיון, על נייר או בתמונות.';

  @override
  String get kitDocumentsNote =>
      'פנקס חיסונים ומסמכים מהווטרינר, על נייר או בתמונות.';

  @override
  String get kitMicrochip => 'פרטי השבב מעודכנים';

  @override
  String kitMicrochipNumber(String number) {
    return '\u2068$number\u2069 · מספר הטלפון שלך במאגר השבבים מעודכן.';
  }

  @override
  String get kitMicrochipNotChipped => 'בפרופיל הבריאות מסומן שאין שבב.';

  @override
  String get kitMicrochipNone => 'עדיין לא נשמר מספר שבב.';

  @override
  String get kitMedicines => 'תרופות';

  @override
  String kitMedicinesNote(String names) {
    return '\u2068$names\u2069 · מלאי רזרבי בערכה.';
  }

  @override
  String get kitShelterPlan => 'תוכנית למרחב המוגן';

  @override
  String kitShelterPlanNote(String name) {
    return 'מי לוקח את \u2068$name\u2069, ואיפה נמצא כלוב הנשיאה.';
  }

  @override
  String kitDocumentsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מסמכים שמורים כאן',
      two: 'שני מסמכים שמורים כאן',
      one: 'מסמך אחד שמור כאן',
    );
    return '$_temp0';
  }

  @override
  String get healthProfile => 'פרופיל בריאות';

  @override
  String kitTicked(String date) {
    return 'סומן בתאריך \u2068$date\u2069';
  }

  @override
  String get kitOurPlan => 'התוכנית שלנו (לא חובה)';

  @override
  String get kitFinePrint =>
      'זו רשימה אישית שלך, לא הנחיה רשמית. בזמן חירום צריך לפעול לפי הנחיות פיקוד העורף.';

  @override
  String petsHealthProfile(String name) {
    return 'פרופיל הבריאות של \u2068$name\u2069';
  }

  @override
  String get identification => 'זיהוי';

  @override
  String get microchipNumberOptional => 'מספר שבב (לא חובה)';

  @override
  String validNumberTooLong(int count) {
    return 'צריך מספר קצר מ־$count תווים.';
  }

  @override
  String get knownAllergies => 'אלרגיות ידועות, אחת בכל שורה';

  @override
  String get medicalConditions => 'מחלות רקע';

  @override
  String get knownConditions => 'מחלות רקע ידועות, אחת בכל שורה';

  @override
  String get validKeepShorter => 'צריך טקסט קצר יותר.';

  @override
  String get emergencyContactHeading => 'איש קשר לחירום (למקרה שצריך עזרה)';

  @override
  String get nameOptional => 'שם (לא חובה)';

  @override
  String get phoneOptional => 'טלפון (לא חובה)';

  @override
  String get validPhone => 'זה לא נראה כמו מספר טלפון.';

  @override
  String get anythingElseForVet => 'עוד משהו שכדאי שווטרינר ידע';

  @override
  String get saveProfile => 'שמירת הפרופיל';

  @override
  String get profileFinePrint =>
      'כל הפרטים כאן הם לא חובה. הם מופיעים בכרטיס החירום ובהודעה לווטרינר.';

  @override
  String get vet => 'וטרינר';

  @override
  String get addVet => 'הוספת וטרינר';

  @override
  String get editVet => 'עריכת וטרינר';

  @override
  String get deleteVet => 'מחיקת הווטרינר';

  @override
  String get deleteVetTitle => 'למחוק את הווטרינר הזה?';

  @override
  String deleteVetMessage(String name) {
    return '״\u2068$name\u2069״ יוסר מהחשבון שלך ומכל חיה שמשתמשת בו.';
  }

  @override
  String get whoIsIt => 'מי זה?';

  @override
  String get vetOrClinicName => 'שם הווטרינר או המרפאה';

  @override
  String get validVetName => 'צריך להזין את שם הווטרינר או המרפאה.';

  @override
  String validNameTooLong(int count) {
    return 'צריך שם קצר מ־$count תווים.';
  }

  @override
  String get howToReachThem => 'איך יוצרים קשר';

  @override
  String get fieldPhone => 'טלפון';

  @override
  String get validWhatsAppNumber => 'צריך להזין את המספר שמחובר ל־WhatsApp.';

  @override
  String validWhatsAppCountryCode(String example) {
    return 'ל־WhatsApp צריך להתחיל בקידומת המדינה, למשל \u2068$example\u2069.';
  }

  @override
  String get onWhatsApp => 'המספר הזה מחובר ל־WhatsApp';

  @override
  String onWhatsAppNote(String example) {
    return 'מוסיף כפתור WhatsApp ליד הודעת הטקסט. צריך קידומת מדינה, למשל \u2068$example\u2069.';
  }

  @override
  String get fieldAddress => 'כתובת';

  @override
  String get addressOptional => 'כתובת (לא חובה)';

  @override
  String get openingHours => 'שעות פתיחה';

  @override
  String get openingHoursOptional => 'שעות פתיחה (לא חובה)';

  @override
  String get saveVet => 'שמירת הווטרינר';

  @override
  String get vetFormFinePrint =>
      'נשמר פעם אחת בחשבון שלך, כך שאפשר לבחור באותו וטרינר גם לשאר החיות שלך.';

  @override
  String get chooseRegularVet => 'בחירת הווטרינר הקבוע';

  @override
  String get chooseEmergencyVet => 'בחירת וטרינר החירום';

  @override
  String get vetPickerNote =>
      'אפשר לבחור וטרינר ששמרת בעבר לכל אחת מהחיות שלך.';

  @override
  String removeVetFromPet(String name) {
    return 'הסרת \u2068$name\u2069 מהחיה הזאת';
  }

  @override
  String get noPhoneYet => 'עדיין אין מספר טלפון';

  @override
  String get inUse => 'בשימוש';

  @override
  String get useVet => 'בחירה';

  @override
  String get addEmergencyVet => 'הוספת וטרינר חירום';

  @override
  String get emergencyVetPromptNote =>
      'מרפאה שפתוחה 24 שעות, ללילות ולסופי שבוע';

  @override
  String get vetsFinePrint =>
      'הווטרינרים נשמרים פעם אחת בחשבון שלך, כך שאפשר לבחור בהם גם לשאר החיות שלך.';

  @override
  String editNamed(String name) {
    return 'עריכת \u2068$name\u2069';
  }

  @override
  String petIsLost(String name) {
    return 'מחפשים את \u2068$name\u2069';
  }

  @override
  String get lostCardSection => 'מה יופיע בכרטיס';

  @override
  String get lostNoPhoto => 'אין תמונה בכרטיס';

  @override
  String lostPetsPhoto(String name) {
    return 'התמונה של \u2068$name\u2069';
  }

  @override
  String get lostPhotoChosen => 'נבחרה רק לכרטיס הזה';

  @override
  String get lostPhotoFromProfile => 'מתוך הפרופיל של החיה';

  @override
  String get lostPhotoHint => 'תמונה עדכנית וברורה עוזרת הכי הרבה';

  @override
  String get lostDescription => 'תיאור';

  @override
  String lostDescriptionHint(String name) {
    return 'צבע, גודל, קולר, וההתנהגות של \u2068$name\u2069 עם זרים';
  }

  @override
  String get lostArea => 'איפה ראו לאחרונה (אזור)';

  @override
  String get lostAreaExact =>
      'זה נראה כמו כתובת מדויקת. שכונה או פינת רחוב בטוחות יותר.';

  @override
  String get lostAreaHint => 'מספיק שכונה או פינת רחוב. לא כתובת הבית שלך.';

  @override
  String get lostWhen => 'מתי ראו לאחרונה';

  @override
  String get lostWhenHelp => 'מתי ראו לאחרונה';

  @override
  String get lostTimeHelp => 'בערך באיזו שעה?';

  @override
  String get lostYourPhone => 'מספר הטלפון שלך';

  @override
  String get lostExtra => 'עוד משהו (לא חובה)';

  @override
  String get lostExtraHint => 'לדוגמה: תרופה יומית קבועה';

  @override
  String get lostLanguage => 'שפת הכרטיס';

  @override
  String get lostPreviewLabel => 'זה מה שישותף';

  @override
  String lostShowPhone(String phone) {
    return 'להציג את מספר הטלפון הזה בכרטיס: \u2068$phone\u2069';
  }

  @override
  String get lostAddPhoneFirst =>
      'קודם צריך להוסיף את מספר הטלפון שלך, ואז לאשר אותו כאן.';

  @override
  String get shareAsImage => 'שיתוף כתמונה';

  @override
  String get shareAsPdf => 'שיתוף כ־PDF להדפסה';

  @override
  String petIsBackHome(String name) {
    return '\u2068$name\u2069 שוב בבית';
  }

  @override
  String get lostGoodNews => 'חדשות טובות. הכרטיס נשמר בצד.';

  @override
  String get lostFinePrint =>
      'האפליקציה לא מפרסמת שום דבר. ההחלטה לאן הכרטיס נשלח היא שלך. מספר השבב והווטרינר אף פעם לא מופיעים בו.';

  @override
  String lostCardHeading(String name) {
    return 'מחפשים את \u2068$name\u2069';
  }

  @override
  String get lostCardArea => 'אזור';

  @override
  String get lostCardWhen => 'מתי';

  @override
  String get lostCardMicrochip => 'שבב';

  @override
  String get lostCardMicrochipped => 'יש שבב';

  @override
  String lostCardCall(String name) {
    return 'ראיתם את \u2068$name\u2069? התקשרו';
  }

  @override
  String get lostCardFooter => 'הוכן באפליקציית PetLoop';

  @override
  String lostCardAround(String date, String time) {
    return '\u2068$date\u2069, בסביבות \u2068$time\u2069';
  }

  @override
  String get overviewNoCareDue => 'אין טיפול מתוכנן כרגע';

  @override
  String overviewLastRecord(String date) {
    return 'רשומה אחרונה: \u2068$date\u2069';
  }

  @override
  String get comingUp => 'בקרוב';

  @override
  String get recordDose => 'רישום';

  @override
  String remindersNeedReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תזכורות ממתינות לעדכון',
      two: 'שתי תזכורות ממתינות לעדכון',
      one: 'תזכורת אחת ממתינה לעדכון',
    );
    return '$_temp0';
  }

  @override
  String get addRecord => 'הוספת רשומה';

  @override
  String get medicines => 'תרופות';

  @override
  String medicinesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פעילות',
      two: 'שתיים פעילות',
      one: 'אחת פעילה',
    );
    return '$_temp0';
  }

  @override
  String get noDoseYet => 'עדיין לא נרשמה מנה';

  @override
  String lastDoseToday(String time) {
    return 'המנה האחרונה שנרשמה: היום בשעה \u2068$time\u2069';
  }

  @override
  String lastDoseYesterday(String time) {
    return 'המנה האחרונה שנרשמה: אתמול בשעה \u2068$time\u2069';
  }

  @override
  String lastDoseOn(String day, String time) {
    return 'המנה האחרונה שנרשמה: \u2068$day\u2069 בשעה \u2068$time\u2069';
  }

  @override
  String get smallWeightChart => 'תרשים משקל קטן';

  @override
  String get medicalRecords => 'תיק רפואי';

  @override
  String get vaccinations => 'חיסונים';

  @override
  String get vetVisits => 'ביקורי וטרינר';

  @override
  String get documents => 'מסמכים';

  @override
  String get startWithOneThing => 'אפשר להתחיל מדבר אחד';

  @override
  String startNote(String name) {
    return 'אין צורך להזין את כל ההיסטוריה של \u2068$name\u2069. אפשר להוסיף דברים כשהם עולים.';
  }

  @override
  String get startDocument => 'הוספת מסמך שכבר יש לך';

  @override
  String get startDocumentNote =>
      'תמונה או PDF של פנקס החיסונים או של מכתב מהווטרינר';

  @override
  String get startAppointment => 'הוספת תור קרוב';

  @override
  String get startAppointmentNote => 'כדי שיופיע תחת ״בקרוב״';

  @override
  String get startMedicine => 'יצירת תזכורת לתרופה';

  @override
  String get startMedicineNote => 'עם הוראות הווטרינר והשעות';

  @override
  String get addToSchedule => 'הוספה ללוח הזמנים';

  @override
  String get addAppointment => 'תור או תאריך יעד';

  @override
  String get addAppointmentNote => 'ביקור אצל וטרינר, חיסון, טיפול';

  @override
  String get medicine => 'תרופה';

  @override
  String get addMedicineNote => 'הוראות הווטרינר ושעות התזכורת';

  @override
  String get routine => 'שגרה';

  @override
  String get addRoutineNote => 'האכלה, טיולים, טיפוח, ניקיון';

  @override
  String get scheduleEmpty => 'עדיין אין שום דבר בלוח הזמנים';

  @override
  String scheduleEmptyNote(String name) {
    return 'תורים, תזכורות לתרופות ושגרות יומיות עבור \u2068$name\u2069 יופיעו כאן.';
  }

  @override
  String get nothingDueToday => 'אין שום דבר להיום.';

  @override
  String get allAnsweredToday => 'כל מה שהיה להיום כבר עודכן.';

  @override
  String get upcoming => 'בקרוב';

  @override
  String get noUpcoming => 'אין תורים או תאריכי יעד קרובים.';

  @override
  String get needsReview => 'ממתינות לעדכון';

  @override
  String needsReviewNote(int days) {
    return 'לא נרשמה תשובה לתזכורות האלה. שום דבר לא נחשב כהחמצה; תזכורת לתרופה יורדת מהרשימה אחרי $days ימים.';
  }

  @override
  String get medicinesAndRoutines => 'תרופות ושגרות';

  @override
  String markNamedAsDone(String title) {
    return 'סימון \u2068$title\u2069 כבוצע';
  }

  @override
  String dueAt(String time) {
    return 'בשעה \u2068$time\u2069';
  }

  @override
  String doneTodayCount(int count) {
    return 'בוצע היום · $count';
  }

  @override
  String doneLineGivenAt(String title, String time) {
    return '\u2068$title\u2069: ניתנה בשעה \u2068$time\u2069';
  }

  @override
  String doneLineGiven(String title) {
    return '\u2068$title\u2069: ניתנה';
  }

  @override
  String doneLineNotGiven(String title) {
    return '\u2068$title\u2069: לא ניתנה';
  }

  @override
  String doneLineNotSure(String title) {
    return '\u2068$title\u2069: לא ידוע';
  }

  @override
  String doneLineAt(String title, String time) {
    return '\u2068$title\u2069 \u2068$time\u2069';
  }

  @override
  String doneLineSkipped(String title) {
    return '\u2068$title\u2069: לא בוצע';
  }

  @override
  String get undo => 'ביטול הסימון';

  @override
  String get dateGivenByVet => 'תאריך שנתן הווטרינר';

  @override
  String followUpDue(String title) {
    return '\u2068$title\u2069: המועד הבא';
  }

  @override
  String get noAnswerRecorded => 'לא נרשמה תשובה';

  @override
  String get notMarkedAsDone => 'לא סומן כבוצע';

  @override
  String get given => 'ניתנה';

  @override
  String givenAt(String time) {
    return 'ניתנה בשעה \u2068$time\u2069';
  }

  @override
  String get notGiven => 'לא ניתנה';

  @override
  String get notSure => 'לא ידוע';

  @override
  String get movedToHistory => 'הועבר להיסטוריה.';

  @override
  String get itHappened => 'זה התקיים';

  @override
  String get changeOrDelete => 'שינוי או מחיקה';

  @override
  String get onlyWhenNeeded => 'רק לפי הצורך';

  @override
  String medicineEnded(String date) {
    return 'הסתיימה בתאריך \u2068$date\u2069';
  }

  @override
  String medicineStarts(String date) {
    return 'מתחילה בתאריך \u2068$date\u2069';
  }

  @override
  String get medicineNotActive => 'לא פעילה';

  @override
  String get paused => 'מושהית';

  @override
  String get newMedicine => 'תרופה חדשה';

  @override
  String get editMedicine => 'עריכת תרופה';

  @override
  String get deleteMedicine => 'מחיקת התרופה';

  @override
  String get deleteMedicineTitle => 'למחוק את התרופה הזאת?';

  @override
  String deleteMedicineMessage(String name) {
    return '״\u2068$name\u2069״, התזכורות שלה ויומן המנות שלה יימחקו. אי אפשר לבטל את הפעולה הזאת.';
  }

  @override
  String get fromVetInstructions => 'לפי הוראות הווטרינר';

  @override
  String get fieldName => 'שם';

  @override
  String get validMedicineName => 'צריך להזין את שם התרופה.';

  @override
  String get strengthOptional => 'חוזק (לא חובה)';

  @override
  String get strengthHint => '50 מ״ג';

  @override
  String get doseOptional => 'מינון (לא חובה)';

  @override
  String get doseHint => 'טבליה אחת';

  @override
  String get howItIsGiven => 'איך נותנים';

  @override
  String get routeByMouth => 'דרך הפה';

  @override
  String get routeOnSkin => 'על העור';

  @override
  String get routeInEye => 'בעין';

  @override
  String get routeInEar => 'באוזן';

  @override
  String get routeInjection => 'זריקה';

  @override
  String get routeOther => 'אחר';

  @override
  String medicineDoseAndRoute(String dose, String route) {
    return '\u2068$dose\u2069 \u2068$route\u2069';
  }

  @override
  String medicineHowAndOften(String how, String often) {
    return '\u2068$how\u2069, \u2068$often\u2069';
  }

  @override
  String get howOftenOptional => 'באיזו תדירות (לא חובה)';

  @override
  String get howOftenHint => 'פעמיים ביום, עם האוכל';

  @override
  String get fieldStart => 'התחלה';

  @override
  String get endOptional => 'סיום (לא חובה)';

  @override
  String get noEnd => 'ללא סיום';

  @override
  String get firstDayOfMedicine => 'היום הראשון של התרופה';

  @override
  String get lastDayOfMedicine => 'היום האחרון של התרופה';

  @override
  String get prescribedByOptional => 'מי רשם את התרופה (לא חובה)';

  @override
  String get reminders => 'תזכורות';

  @override
  String get reminderTime => 'שעת התזכורת';

  @override
  String get addATime => 'הוספת שעה';

  @override
  String get medicineNoTimesNote =>
      'בלי שעות תזכורת: תרופה שניתנת רק לפי הצורך.';

  @override
  String get medicineReminderNote =>
      'תזכורת שלא עודכנה מחכה תחת ״ממתינות לעדכון״. היא אף פעם לא נחשבת כהחמצה.';

  @override
  String get validLastBeforeFirst =>
      'היום האחרון לא יכול להיות לפני היום הראשון.';

  @override
  String get validReminderDays => 'צריך לבחור לפחות יום אחד לתזכורות.';

  @override
  String get saveMedicine => 'שמירת התרופה';

  @override
  String get medicineFinePrint =>
      'האפליקציה שומרת רק את מה שהזנת. היא אף פעם לא מציעה מינון.';

  @override
  String get doseLog => 'יומן מנות';

  @override
  String get noDoseRecordedYet => 'עדיין לא נרשמה מנה.';

  @override
  String doseLogReminder(String time) {
    return 'תזכורת של \u2068$time\u2069';
  }

  @override
  String get doseLogWhenNeeded => 'לפי הצורך';

  @override
  String doseLoggedBy(String name) {
    return 'נרשם על ידי \u2068$name\u2069';
  }

  @override
  String get doseLoggedByYou => 'נרשם על ידך';

  @override
  String doseGivenWhenNeeded(String name) {
    return 'ניתנת לפי הצורך · \u2068$name\u2069';
  }

  @override
  String reminderForToday(String time) {
    return 'תזכורת להיום · \u2068$time\u2069';
  }

  @override
  String reminderForYesterday(String time) {
    return 'תזכורת מאתמול · \u2068$time\u2069';
  }

  @override
  String reminderForDay(String day, String time) {
    return 'תזכורת עבור \u2068$day\u2069 · \u2068$time\u2069';
  }

  @override
  String vetsInstructions(String text) {
    return 'הוראות הווטרינר: \u2068$text\u2069.';
  }

  @override
  String givenNowAt(String time) {
    return 'ניתנה עכשיו · \u2068$time\u2069';
  }

  @override
  String get givenAtAnotherTime => 'ניתנה בשעה אחרת';

  @override
  String get whenWasItGiven => 'מתי היא ניתנה?';

  @override
  String get noteOptional => 'הערה (לא חובה)';

  @override
  String get doseNoteHint => 'לדוגמה: הוסתרה בתוך גבינה';

  @override
  String get validTimeAhead =>
      'השעה הזאת עוד לא הגיעה. אפשר לרשום את המנה אחרי שהיא ניתנת.';

  @override
  String get doseRecordedGiven => 'המנה נרשמה: ניתנה.';

  @override
  String get doseRecordedNotGiven => 'המנה נרשמה: לא ניתנה.';

  @override
  String get doseRecordedNotSure => 'המנה נרשמה: לא ידוע.';

  @override
  String doseFinePrintNamed(String name) {
    return 'נשמר עם השם \u2068$name\u2069 ועם השעה. אם יש ספק לגבי מנה, כדאי לשאול את הווטרינר.';
  }

  @override
  String get doseFinePrintYou =>
      'נשמר כרישום שלך, עם השעה. אם יש ספק לגבי מנה, כדאי לשאול את הווטרינר.';

  @override
  String get newRoutine => 'שגרה חדשה';

  @override
  String get editRoutine => 'עריכת שגרה';

  @override
  String get deleteRoutine => 'מחיקת השגרה';

  @override
  String get deleteRoutineTitle => 'למחוק את השגרה הזאת?';

  @override
  String deleteRoutineMessage(String title) {
    return '״\u2068$title\u2069״ תרד מלוח הזמנים. מה שכבר סומן נשאר ביומן.';
  }

  @override
  String get whatKindOfRoutine => 'איזו שגרה?';

  @override
  String get careFeeding => 'האכלה';

  @override
  String get careWalk => 'טיול';

  @override
  String get careGrooming => 'טיפוח';

  @override
  String get careCleaning => 'ניקיון';

  @override
  String get careLitterCleaning => 'ניקוי ארגז החול';

  @override
  String get careLitterChange => 'החלפת החול';

  @override
  String get careCageCleaning => 'ניקוי הכלוב';

  @override
  String get careEnclosureCleaning => 'ניקוי הטרריום';

  @override
  String get careOther => 'אחר';

  @override
  String get fieldTitle => 'כותרת';

  @override
  String get routineTitleHint => 'ארוחת בוקר, טיול ערב...';

  @override
  String get validRoutineTitle => 'צריך לתת לשגרה כותרת.';

  @override
  String validTitleTooLong(int count) {
    return 'צריך כותרת קצרה מ־$count תווים.';
  }

  @override
  String get fieldTime => 'שעה';

  @override
  String get timeOfRoutine => 'שעת השגרה';

  @override
  String get fieldDays => 'ימים';

  @override
  String get showInSchedule => 'להציג בלוח הזמנים';

  @override
  String get routineOn => 'פעילה';

  @override
  String get routinePausedNote =>
      'מושהית: נשמרת כאן, אבל לא מופיעה בלוח הזמנים';

  @override
  String get saveRoutine => 'שמירת השגרה';

  @override
  String get historyEmpty => 'עדיין אין רשומות';

  @override
  String historyEmptyNote(String name) {
    return 'ביקורי וטרינר, חיסונים, טיפולים ומסמכים יבנו כאן את ההיסטוריה של \u2068$name\u2069.';
  }

  @override
  String get addARecord => 'הוספת רשומה';

  @override
  String searchRecords(String name) {
    return 'חיפוש ברשומות של \u2068$name\u2069';
  }

  @override
  String get clearSearch => 'ניקוי החיפוש';

  @override
  String get filterAll => 'הכול';

  @override
  String get kindCheckup => 'ביקור וטרינר';

  @override
  String get kindVaccination => 'חיסון';

  @override
  String get kindPreventive => 'טיפול מונע';

  @override
  String get kindProcedure => 'טיפול';

  @override
  String get kindMedicine => 'תרופה';

  @override
  String get kindDocument => 'מסמך';

  @override
  String get kindOther => 'הערה';

  @override
  String get kindsPreventive => 'טיפולים מונעים';

  @override
  String get kindsProcedure => 'טיפולים';

  @override
  String get kindsMedicine => 'תרופות';

  @override
  String recordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count רשומות',
      two: 'שתי רשומות',
      one: 'רשומה אחת',
    );
    return '$_temp0';
  }

  @override
  String recordsShown(int shown, int total) {
    return '$shown מתוך $total רשומות';
  }

  @override
  String get nothingMatches => 'לא נמצאו התאמות';

  @override
  String get nothingMatchesNote => 'אין רשומה שמתאימה לחיפוש ולסינון האלה.';

  @override
  String get showAllRecords => 'הצגת כל הרשומות';

  @override
  String nextDue(String date) {
    return 'המועד הבא: \u2068$date\u2069';
  }

  @override
  String costSemantics(String amount) {
    return 'עלות: \u2068$amount\u2069';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קבצים מצורפים',
      two: 'שני קבצים מצורפים',
      one: 'קובץ מצורף אחד',
    );
    return '$_temp0';
  }

  @override
  String get record => 'רשומה';

  @override
  String get newRecord => 'רשומה חדשה';

  @override
  String get newAppointment => 'תור חדש';

  @override
  String get editRecord => 'עריכת רשומה';

  @override
  String get deleteRecord => 'מחיקת הרשומה';

  @override
  String get deleteRecordTitle => 'למחוק את הרשומה הזאת?';

  @override
  String deleteRecordMessage(String title) {
    return '״\u2068$title\u2069״ והקבצים המצורפים אליה יימחקו. אי אפשר לבטל את הפעולה הזאת.';
  }

  @override
  String get whatKindOfRecord => 'איזו רשומה?';

  @override
  String get validRecordTitle => 'צריך לתת לרשומה כותרת.';

  @override
  String get productOptional => 'תכשיר (לא חובה)';

  @override
  String get product => 'תכשיר';

  @override
  String get plannedFor => 'מועד מתוכנן';

  @override
  String get dateGiven => 'תאריך מתן';

  @override
  String get fieldDate => 'תאריך';

  @override
  String get recordAheadNote =>
      'התאריך הזה עוד לא הגיע, ולכן הרשומה נשמרת כפריט קרוב בלוח הזמנים.';

  @override
  String get nextDueOptional => 'המועד הבא (לא חובה)';

  @override
  String get nextDueHelp => 'המועד הבא, לפי הווטרינר';

  @override
  String get nextDueNote =>
      'כאן מזינים את התאריך שנתן הווטרינר. הוא יופיע בלוח הזמנים.';

  @override
  String get nextDueFromVet => 'המועד הבא (לפי הווטרינר)';

  @override
  String get validNextDueAfter => 'המועד הבא צריך להיות אחרי תאריך המתן.';

  @override
  String get vetOrClinicOptional => 'וטרינר או מרפאה (לא חובה)';

  @override
  String get vetOrClinic => 'וטרינר או מרפאה';

  @override
  String get costOptional => 'עלות (לא חובה)';

  @override
  String get expectedCostOptional => 'עלות צפויה (לא חובה)';

  @override
  String get cost => 'עלות';

  @override
  String get expectedCost => 'עלות צפויה';

  @override
  String get validAmount => 'צריך להזין סכום, למשל 120 או 89.90.';

  @override
  String get costNotePaid =>
      'הסכום ששולם. הוא נשמר רק ברשומות שלך ולא נכלל בשום דבר שמשותף עם וטרינר.';

  @override
  String get costNoteExpected =>
      'הסכום הצפוי לתשלום. הוא נשמר רק ברשומות שלך ולא נכלל בשום דבר שמשותף עם וטרינר.';

  @override
  String get notesHint => 'כל מה שכדאי לזכור';

  @override
  String get validNotesTooLong => 'צריך הערות קצרות יותר.';

  @override
  String get attachments => 'קבצים מצורפים';

  @override
  String get addPhotoOrPdf => 'הוספת תמונה או PDF';

  @override
  String get saveRecord => 'שמירת הרשומה';

  @override
  String savedButFileNotAttached(String problem) {
    return 'הרשומה נשמרה, אבל קובץ לא צורף. \u2068$problem\u2069';
  }

  @override
  String savedButNextDueNotPlanned(String problem) {
    return 'הרשומה נשמרה, אבל המועד הבא לא נוסף ללוח הזמנים. \u2068$problem\u2069 שמירה נוספת תנסה שוב.';
  }

  @override
  String savedButRemindersNotSet(String problem) {
    return 'התרופה נשמרה, אבל לא כל התזכורות שלה נקבעו. \u2068$problem\u2069 שמירה נוספת תנסה שוב.';
  }

  @override
  String get removeFileTitle => 'להסיר את הקובץ הזה?';

  @override
  String removeFileMessage(String name) {
    return '״\u2068$name\u2069״ יוסר מהרשומה.';
  }

  @override
  String get recordGone => 'הרשומה הזאת כבר לא קיימת';

  @override
  String get recordGoneNote => 'היא נמחקה.';

  @override
  String fileAttached(String name) {
    return 'הקובץ \u2068$name\u2069 צורף.';
  }

  @override
  String get inTheSchedule => 'בלוח הזמנים';

  @override
  String get markAsDone => 'סימון כבוצע';

  @override
  String get noAttachmentsNote =>
      'עדיין אין תמונות או קובצי PDF. תמונה נפתחת על מסך מלא; PDF נפתח בתוכנת התצוגה של הטלפון.';

  @override
  String get shareThisRecord => 'שיתוף הרשומה';

  @override
  String get deleteInsideEdit =>
      'המחיקה נמצאת בתוך ״עריכה״, ותמיד מבקשת אישור קודם.';

  @override
  String get attachSheetNote =>
      'עמוד מהפנקס, מכתב מהווטרינר, תוצאת מעבדה. עד 5 מ״ב.';

  @override
  String get takeAPhoto => 'צילום תמונה';

  @override
  String get withTheCamera => 'במצלמה';

  @override
  String get chooseAPhoto => 'בחירת תמונה';

  @override
  String get fromYourPhotos => 'מהתמונות שלך';

  @override
  String get chooseAPdf => 'בחירת קובץ PDF';

  @override
  String get fromPhoneFiles => 'מהקבצים בטלפון';

  @override
  String get fileKindPdf => 'PDF';

  @override
  String get fileKindPhoto => 'תמונה';

  @override
  String get couldNotOpenFile => 'לא הצלחנו לפתוח את הקובץ במכשיר הזה.';

  @override
  String get shareThisPhoto => 'שיתוף התמונה';

  @override
  String petsDocuments(String name) {
    return 'המסמכים של \u2068$name\u2069';
  }

  @override
  String get noDocumentsYet => 'עדיין אין מסמכים';

  @override
  String get noDocumentsNote => 'תמונות וקובצי PDF שצורפו לרשומה יופיעו כאן.';

  @override
  String get documentsFinePrint =>
      'תמונה נפתחת על מסך מלא; PDF נפתח בתוכנת התצוגה של הטלפון.';

  @override
  String get insightsEmpty => 'עדיין לא נרשם כלום';

  @override
  String insightsEmptyNote(String name) {
    return 'משקל, תיאבון, אנרגיה וכל דבר אחר ששמת לב אליו אצל \u2068$name\u2069 יבנו כאן תמונה.';
  }

  @override
  String get openQuickLog => 'פתיחת הרישום המהיר';

  @override
  String get observations => 'יומן תצפיות';

  @override
  String get groupBody => 'גוף';

  @override
  String get groupBehaviour => 'התנהגות';

  @override
  String get insightsFinePrint =>
      'מה ששמת לב אליו, במילים שלך. האפליקציה לא מפרשת את זה.';

  @override
  String get logWeight => 'רישום משקל';

  @override
  String get noWeightYet => 'עדיין לא נרשם משקל.';

  @override
  String weighIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שקילות',
      two: 'שתי שקילות',
      one: 'שקילה אחת',
    );
    return '$_temp0';
  }

  @override
  String weightHighest(String value) {
    return 'הגבוה ביותר: \u2068$value\u2069';
  }

  @override
  String weightLowest(String value) {
    return 'הנמוך ביותר: \u2068$value\u2069';
  }

  @override
  String weightTrendSemantics(
    String from,
    String fromDate,
    String to,
    String toDate,
  ) {
    return 'מגמת המשקל: מ־\u2068$from\u2069 בתאריך \u2068$fromDate\u2069 עד \u2068$to\u2069 בתאריך \u2068$toDate\u2069';
  }

  @override
  String get vetVisitMarker => 'ביקור וטרינר';

  @override
  String get noted => 'נרשם';

  @override
  String get levelUsual => 'כרגיל';

  @override
  String get levelLess => 'פחות מהרגיל';

  @override
  String get levelMore => 'יותר מהרגיל';

  @override
  String get levelDifferent => 'שונה מהרגיל';

  @override
  String get logAppetite => 'תיאבון';

  @override
  String get logEnergy => 'אנרגיה';

  @override
  String get logMobility => 'תנועה';

  @override
  String get logDigestion => 'עיכול';

  @override
  String get logSkinCoat => 'עור או פרווה';

  @override
  String get logDental => 'שיניים';

  @override
  String get logDrinking => 'שתייה';

  @override
  String get logDiet => 'תזונה';

  @override
  String get logDroppings => 'צואה';

  @override
  String get logFeathers => 'נוצות';

  @override
  String get logActivity => 'פעילות';

  @override
  String get logEnvironment => 'סביבה';

  @override
  String get logEating => 'אכילה';

  @override
  String get logFeeding => 'האכלה';

  @override
  String get logShedding => 'נשל';

  @override
  String get logTemperature => 'טמפרטורה';

  @override
  String get logHumidity => 'לחות';

  @override
  String get logLighting => 'תאורה';

  @override
  String get logOther => 'אחר';

  @override
  String get logSleep => 'שינה';

  @override
  String get logBarking => 'נביחות';

  @override
  String get logMeowing => 'יללות';

  @override
  String get logVocalisation => 'קולות';

  @override
  String get logBiting => 'נשיכות';

  @override
  String get logBitingScratching => 'נשיכות או שריטות';

  @override
  String get logLeftAlone => 'כשנשארים לבד';

  @override
  String get logLitterBox => 'שימוש בארגז החול';

  @override
  String get logOtherBehaviour => 'התנהגות אחרת';

  @override
  String quickLogFor(String name) {
    return 'רישום מהיר עבור \u2068$name\u2069';
  }

  @override
  String get whatDidYouNotice => 'למה שמת לב?';

  @override
  String get editEntry => 'עריכת רישום';

  @override
  String get weightInGrams => 'משקל בגרמים';

  @override
  String get weightInKilograms => 'משקל בקילוגרמים';

  @override
  String lastTimeWeight(String weight, String date) {
    return 'בפעם הקודמת: \u2068$weight\u2069 בתאריך \u2068$date\u2069';
  }

  @override
  String get fieldWhen => 'מתי';

  @override
  String get whenDidYouNotice => 'מתי שמת לב לזה?';

  @override
  String get validWeight => 'המשקל הזה לא נראה נכון. כדאי לבדוק את המספר.';

  @override
  String get saveToJournal => 'שמירה ביומן';

  @override
  String get saveChanges => 'שמירת השינויים';

  @override
  String get savedToJournal => 'נשמר ביומן.';

  @override
  String get entryUpdated => 'הרישום עודכן.';

  @override
  String get deleteThisEntry => 'מחיקת הרישום';

  @override
  String get deleteEntryTitle => 'למחוק את הרישום הזה?';

  @override
  String get deleteEntryMessage =>
      'הרישום יוסר מהיומן. אי אפשר לבטל את הפעולה הזאת.';

  @override
  String get looksUrgent => 'נראה דחוף? כדאי לפנות לווטרינר';

  @override
  String get quickLogFinePrint =>
      'תיעוד של מה ששמת לב אליו. האפליקציה לא מפרשת אותו.';

  @override
  String reportSummaryTitle(String name) {
    return '\u2068$name\u2069: סיכום בריאות';
  }

  @override
  String reportRecordTitle(String name, String title) {
    return '\u2068$name\u2069: \u2068$title\u2069';
  }

  @override
  String reportPrepared(String date) {
    return 'הוכן בתאריך \u2068$date\u2069 באפליקציית PetLoop';
  }

  @override
  String reportPreparedBy(String date, String owner) {
    return 'הוכן בתאריך \u2068$date\u2069 על ידי \u2068$owner\u2069 באפליקציית PetLoop';
  }

  @override
  String get reportEmergencyVet => 'וטרינר חירום';

  @override
  String reportMedicineLine(String name, String instructions) {
    return '\u2068$name\u2069: \u2068$instructions\u2069';
  }

  @override
  String get reportRecords => 'רשומות';

  @override
  String get reportRecentRecords => 'רשומות אחרונות';

  @override
  String get reportPlanned => 'מתוכנן';

  @override
  String get reportColumnKind => 'סוג';

  @override
  String get reportFooter =>
      'נכתב על ידי הבעלים באפליקציית PetLoop. זהו תיעוד של מה שהוזן, ולא ייעוץ וטרינרי.';
}
