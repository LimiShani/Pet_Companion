// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'pets_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class PetsL10nHe extends PetsL10n {
  PetsL10nHe([String locale = 'he']) : super(locale);

  @override
  String get myPetsTitle => 'החיות שלי';

  @override
  String get speciesDog => 'כלב';

  @override
  String get speciesCat => 'חתול';

  @override
  String get speciesBird => 'ציפור';

  @override
  String get speciesRabbit => 'ארנב';

  @override
  String get speciesReptile => 'זוחל';

  @override
  String get speciesOther => 'אחר';

  @override
  String get sexMale => 'זכר';

  @override
  String get sexFemale => 'נקבה';

  @override
  String get notSure => 'לא ידוע';

  @override
  String get answerYes => 'כן';

  @override
  String get answerNo => 'לא';

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שנים',
      two: 'שנתיים',
      one: 'שנה',
    );
    return '$_temp0';
  }

  @override
  String ageYearsExact(String years) {
    return '\u2068$years\u2069 שנים';
  }

  @override
  String ageMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חודשים',
      two: 'חודשיים',
      one: 'חודש',
    );
    return '$_temp0';
  }

  @override
  String ageWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שבועות',
      two: 'שבועיים',
      one: 'שבוע',
    );
    return '$_temp0';
  }

  @override
  String get ageUnderAWeek => 'פחות משבוע';

  @override
  String ageAbout(String age) {
    return 'בערך \u2068$age\u2069';
  }

  @override
  String weightKg(String value) {
    return '\u2068$value\u2069 ק״ג';
  }

  @override
  String weightG(String value) {
    return '\u2068$value\u2069 גרם';
  }

  @override
  String get unitKg => 'ק״ג';

  @override
  String get unitG => 'גרם';

  @override
  String get breedMixed => 'מעורב';

  @override
  String get welcomeTitle => 'נעים להכיר';

  @override
  String welcomeTitleNamed(String name) {
    return 'נעים להכיר, \u2068$name\u2069';
  }

  @override
  String get welcomeIntro => 'הגיע הזמן להכיר את החיה הראשונה שלך. מספיק שם וסוג כדי להתחיל; השאר לוקח בערך דקה.';

  @override
  String get welcomeWhyPhoto => 'תמונה, או אייקון חמוד';

  @override
  String get welcomeWhyVet => 'המספר של הווטרינר, מוכן למקרה חירום';

  @override
  String get welcomeWhyHealth => 'אלרגיות ומחלות רקע: מה שווטרינר שואל קודם';

  @override
  String get welcomeAddFirst => 'הוספת החיה הראשונה שלי';

  @override
  String get welcomeArchivedPets => 'חיות בארכיון';

  @override
  String get welcomeLoadFailed => 'לא הצלחנו לטעון את החיות שלך';

  @override
  String get restore => 'שחזור';

  @override
  String get addPetTitle => 'הוספת חיה';

  @override
  String aboutPetTitle(String name) {
    return 'פרטים על \u2068$name\u2069';
  }

  @override
  String petVetTitle(String name) {
    return 'הווטרינר של \u2068$name\u2069';
  }

  @override
  String get healthBasics => 'פרטי בריאות בסיסיים';

  @override
  String get finishLater => 'להמשיך אחר כך';

  @override
  String stepOf(int step, int total) {
    return 'שלב $step מתוך $total';
  }

  @override
  String get whoIsJoining => 'את מי מצרפים למשפחה?';

  @override
  String get whoIsJoiningNote => 'מספיק שם וסוג כדי להתחיל. כל השאר יכול לחכות.';

  @override
  String get addPhotoOrIcon => 'הוספת תמונה או בחירת אייקון';

  @override
  String get fieldName => 'שם';

  @override
  String get nameMissingNew => 'איך קוראים לחיה שלך?';

  @override
  String get nameMissing => 'חיה צריכה שם.';

  @override
  String nameTooLong(int count) {
    return 'צריך שם קצר מ־$count תווים.';
  }

  @override
  String get kindOfAnimal => 'סוג החיה';

  @override
  String savedOnContinue(String name) {
    return 'הפרטים של \u2068$name\u2069 נשמרים בלחיצה על ״המשך״. אפשר לשנות הכול אחר כך.';
  }

  @override
  String get savedOnContinueNoName => 'הפרטים של החיה שלך נשמרים בלחיצה על ״המשך״. אפשר לשנות הכול אחר כך.';

  @override
  String pictureNotSaved(String name) {
    return 'לא הצלחנו לשמור את התמונה. אפשר להוסיף אותה אחר כך מהפרופיל של \u2068$name\u2069.';
  }

  @override
  String petIsSaved(String name) {
    return 'הפרטים של \u2068$name\u2069 נשמרו';
  }

  @override
  String get aboutNote => 'אפשר למלא מה שידוע ולדלג על השאר.';

  @override
  String get skipForNow => 'לדלג בינתיים';

  @override
  String whoLooksAfter(String name) {
    return 'מי הווטרינר של \u2068$name\u2069?';
  }

  @override
  String get vetStepNote => 'כשהטלפון של הווטרינר שמור, חיוג או הודעה במקרה חירום נמצאים במרחק שתי לחיצות.';

  @override
  String get regularVet => 'וטרינר קבוע';

  @override
  String get emergencyVet => 'וטרינר חירום (24 שעות)';

  @override
  String get noVetYet => 'עדיין אין לי וטרינר';

  @override
  String noVetYetNote(String name) {
    return 'עדיין אין וטרינר? אפשר להמשיך: תזכורת קטנה תחכה במסך הבית של \u2068$name\u2069.';
  }

  @override
  String get whatAVetAsksFirst => 'מה שווטרינר שואל קודם';

  @override
  String get healthStepNote => 'אם אין מה לרשום, אפשר לסמן ״לא ידוע על כאלה״. גם זו תשובה.';

  @override
  String get finish => 'סיום';

  @override
  String get tagEssential => 'חיוני';

  @override
  String get tagOptional => 'לא חובה';

  @override
  String get allSetChecking => 'בודקים את הפרטים החיוניים…';

  @override
  String allSetAllFilled(int total) {
    return 'כל $total הפרטים החיוניים מולאו';
  }

  @override
  String allSetSomeFilled(int answered, int total) {
    return 'מולאו $answered מתוך $total פרטים חיוניים';
  }

  @override
  String allSetNoteUnknown(String name) {
    return 'כל עוד חסר פרט חיוני, תופיע תזכורת קטנה במסך הבית של \u2068$name\u2069.';
  }

  @override
  String allSetNoteComplete(String name) {
    return 'כל הפרטים החיוניים של \u2068$name\u2069 מולאו. אפשר לשנות הכול מהפרופיל.';
  }

  @override
  String allSetNoteVet(String name) {
    return 'תזכורת קטנה תישאר במסך הבית של \u2068$name\u2069 עד שיתווסף הטלפון של הווטרינר.';
  }

  @override
  String allSetNoteRest(String name) {
    return 'תזכורת קטנה תישאר במסך הבית של \u2068$name\u2069 עד שיתווספו שאר הפרטים.';
  }

  @override
  String petIsReady(String name) {
    return 'הפרופיל של \u2068$name\u2069 מוכן';
  }

  @override
  String get addNow => 'הוספה עכשיו';

  @override
  String goToDashboard(String name) {
    return 'למסך הבית של \u2068$name\u2069';
  }

  @override
  String get addAnotherPet => 'הוספת חיה נוספת';

  @override
  String checklistTitle(String name) {
    return 'הפרטים החיוניים של \u2068$name\u2069';
  }

  @override
  String get checklistChecking => 'בודקים מה כבר מולא…';

  @override
  String checklistAllAnswered(int total) {
    return 'כל $total הפרטים מולאו. תודה.';
  }

  @override
  String checklistSomeAnswered(int answered, int total) {
    return 'מולאו $answered מתוך $total. גם ״לא ידוע על כאלה״ נחשב.';
  }

  @override
  String get goodToHave => 'כדאי להוסיף';

  @override
  String get remindInAWeek => 'להזכיר לי בעוד שבוע';

  @override
  String reminderHiddenUntil(String date, String name) {
    return 'התזכורת מוסתרת עד \u2068$date\u2069. הנקודה ליד השם של \u2068$name\u2069 נשארת.';
  }

  @override
  String chipAnswered(String item) {
    return '\u2068$item\u2069: יש תשובה';
  }

  @override
  String chipNotAdded(String item) {
    return '\u2068$item\u2069: עדיין אין';
  }

  @override
  String get checking => 'בודקים…';

  @override
  String get couldNotCheck => 'לא הצלחנו לבדוק את זה כרגע';

  @override
  String get itemVetPhone => 'טלפון של וטרינר';

  @override
  String get itemAllergies => 'אלרגיות';

  @override
  String get itemConditions => 'מחלות רקע';

  @override
  String get itemAge => 'גיל';

  @override
  String get itemWeight => 'משקל';

  @override
  String get itemPhoto => 'תמונה אמיתית';

  @override
  String get itemBreed => 'גזע';

  @override
  String get itemSexAndNeutering => 'מין ועיקור';

  @override
  String get itemMicrochip => 'שבב';

  @override
  String get hintVetPhone => 'כדי שאפשר יהיה לחייג במקרה חירום';

  @override
  String get hintListOrNone => 'רשימה, או ״לא ידוע על כאלה״';

  @override
  String get hintAge => 'תאריך לידה, או ״בערך 3 שנים״';

  @override
  String get hintWeight => 'מספיק מספר משוער';

  @override
  String get hintPhoto => 'עוזרת במיוחד אם החיה הולכת לאיבוד';

  @override
  String get hintBreed => 'גם ״מעורב או לא ידוע״ היא תשובה';

  @override
  String get hintSexAndNeutering => 'שואלים על זה בטפסים של וטרינר';

  @override
  String get hintMicrochip => 'עוזר למצוא חיה שאבדה';

  @override
  String get hintEmergencyVet => 'גיבוי לשעות הלילה';

  @override
  String get actionVetPhone => 'הוספת טלפון של וטרינר';

  @override
  String get actionAllergies => 'מילוי פרטי אלרגיות';

  @override
  String get actionConditions => 'מילוי מחלות רקע';

  @override
  String actionAge(String name) {
    return 'הוספת הגיל של \u2068$name\u2069';
  }

  @override
  String actionWeight(String name) {
    return 'הוספת המשקל של \u2068$name\u2069';
  }

  @override
  String actionPhoto(String name) {
    return 'הוספת תמונה של \u2068$name\u2069';
  }

  @override
  String actionBreed(String name) {
    return 'הוספת הגזע של \u2068$name\u2069';
  }

  @override
  String get actionSexAndNeutering => 'הוספת מין ועיקור';

  @override
  String get actionMicrochip => 'הוספת מספר השבב';

  @override
  String get actionEmergencyVet => 'הוספת וטרינר חירום';

  @override
  String petAgeTitle(String name) {
    return 'הגיל של \u2068$name\u2069';
  }

  @override
  String get petAgeNote => 'תאריך לידה או ניחוש: שניהם נחשבים.';

  @override
  String petWeightTitle(String name) {
    return 'המשקל של \u2068$name\u2069';
  }

  @override
  String get petWeightNote => 'כל מינון מתחיל במשקל.';

  @override
  String petBreedTitle(String name) {
    return 'הגזע של \u2068$name\u2069';
  }

  @override
  String get sexAndNeuteringNote => 'גם ״לא ידוע״ היא תשובה.';

  @override
  String essentialsStillToAdd(int missing, int total) {
    return 'חסרים $missing מתוך $total פרטים חיוניים';
  }

  @override
  String reminderSemantics(String name, int missing, int total) {
    return 'הפרופיל של \u2068$name\u2069: חסרים $missing מתוך $total פרטים חיוניים';
  }

  @override
  String finishProfile(String name) {
    return 'השלמת הפרופיל של \u2068$name\u2069';
  }

  @override
  String get notNow => 'לא עכשיו';

  @override
  String get remindAgainInAWeek => 'נזכיר שוב בעוד שבוע';

  @override
  String essentialsComplete(String name) {
    return 'כל הפרטים החיוניים של \u2068$name\u2069 מולאו';
  }

  @override
  String get essentialsMissing => 'חסרים פרטים חיוניים';

  @override
  String essentialsToAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'חסרים $count פרטים חיוניים',
      two: 'חסרים שני פרטים חיוניים',
      one: 'חסר פרט חיוני אחד',
    );
    return '$_temp0';
  }

  @override
  String get complete => 'הכול מולא';

  @override
  String get birthdayOrAge => 'תאריך לידה או גיל';

  @override
  String get iKnowTheDate => 'התאריך ידוע לי';

  @override
  String get aboutEllipsis => 'בערך…';

  @override
  String get aboutField => 'בערך';

  @override
  String get unitYears => 'שנים';

  @override
  String get unitMonths => 'חודשים';

  @override
  String get ageGuessNote => 'גם ניחוש מספיק. יוצג כ״בערך 3 שנים״, והגיל ימשיך להתעדכן.';

  @override
  String get birthday => 'תאריך לידה';

  @override
  String get chooseTheDate => 'בחירת תאריך';

  @override
  String get sex => 'מין';

  @override
  String get neuteredOrSpayed => 'עיקור או סירוס';

  @override
  String get breedOptional => 'גזע (לא חובה)';

  @override
  String get breedExample => 'למשל לברדור';

  @override
  String get mixedOrNotSure => 'מעורב או לא ידוע';

  @override
  String breedTooLong(int count) {
    return 'צריך שם גזע קצר מ־$count תווים.';
  }

  @override
  String enterANumberLike(int example) {
    return 'צריך להזין מספר, למשל $example.';
  }

  @override
  String get tooHeavy => 'זה נראה כבד מדי. כדאי לבדוק את המספר.';

  @override
  String get enterANumber => 'צריך להזין מספר.';

  @override
  String get checkTheNumber => 'כדאי לבדוק את המספר.';

  @override
  String petPictureTitle(String name) {
    return 'התמונה של \u2068$name\u2069';
  }

  @override
  String get yourPetsPicture => 'התמונה של החיה שלך';

  @override
  String get petPicture => 'תמונת חיה';

  @override
  String get takeAPhoto => 'צילום תמונה';

  @override
  String get takeAPhotoNote => 'המצלמה תיפתח';

  @override
  String get chooseFromPhotos => 'בחירה מהתמונות שלך';

  @override
  String get chooseFromPhotosNote => 'ואז התאמה לעיגול';

  @override
  String get pickAnIcon => 'בחירת אייקון';

  @override
  String pickAnIconNote(int count) {
    return '$count חיות בצבעי האפליקציה';
  }

  @override
  String get removePicture => 'הסרת התמונה';

  @override
  String get removePictureNoteDog => 'חזרה לאייקון הרגיל של כלב';

  @override
  String get removePictureNoteCat => 'חזרה לאייקון הרגיל של חתול';

  @override
  String get removePictureNoteBird => 'חזרה לאייקון הרגיל של ציפור';

  @override
  String get removePictureNoteRabbit => 'חזרה לאייקון הרגיל של ארנב';

  @override
  String get removePictureNoteReptile => 'חזרה לאייקון הרגיל של זוחל';

  @override
  String get removePictureNoteOther => 'חזרה לאייקון הרגיל';

  @override
  String get cropTitle => 'הזזה והגדלה';

  @override
  String get cropHint => 'גרירה להזזה · צביטה להגדלה';

  @override
  String get cropPreview => 'תצוגה מקדימה';

  @override
  String get cropChooseAnother => 'תמונה אחרת';

  @override
  String get cropUsePhoto => 'שימוש בתמונה';

  @override
  String get cropFailed => 'לא הצלחנו לחתוך את התמונה. אפשר לנסות תמונה אחרת.';

  @override
  String get iconsForDog => 'לכלב';

  @override
  String get iconsForCat => 'לחתול';

  @override
  String get iconsForBird => 'לציפור';

  @override
  String get iconsForRabbit => 'לארנב';

  @override
  String get iconsForReptile => 'לזוחל';

  @override
  String get iconsSuggested => 'מומלצים';

  @override
  String get iconsAll => 'כל החיות';

  @override
  String get iconsBackground => 'רקע';

  @override
  String get iconsBackgroundYellow => 'רקע צהוב';

  @override
  String get iconsBackgroundGreen => 'רקע ירוק';

  @override
  String get iconsBackgroundPeach => 'רקע בצבע אפרסק';

  @override
  String get iconsBackgroundWhite => 'רקע לבן';

  @override
  String get iconsUse => 'שימוש באייקון הזה';

  @override
  String get changesSaved => 'השינויים נשמרו';

  @override
  String petArchived(String name) {
    return 'הפרופיל של \u2068$name\u2069 בארכיון. אפשר להחזיר אותו מ״החיות שלי״.';
  }

  @override
  String petDeleted(String name) {
    return 'הפרופיל של \u2068$name\u2069 נמחק';
  }

  @override
  String get petProfile => 'פרופיל החיה';

  @override
  String get petNoLongerHere => 'החיה הזאת כבר לא כאן.';

  @override
  String get changePicture => 'החלפת תמונה';

  @override
  String get basics => 'פרטים בסיסיים';

  @override
  String get kind => 'סוג';

  @override
  String get vet => 'וטרינר';

  @override
  String get saveChanges => 'שמירת השינויים';

  @override
  String archivePet(String name) {
    return 'העברת \u2068$name\u2069 לארכיון';
  }

  @override
  String deletePet(String name) {
    return 'מחיקת \u2068$name\u2069';
  }

  @override
  String get noneKnown => 'לא ידוע על כאלה';

  @override
  String get notAnsweredYet => 'עדיין אין תשובה';

  @override
  String get notAdded => 'לא נוסף';

  @override
  String get answer => 'מילוי';

  @override
  String removePetTitle(String name) {
    return 'להסיר את \u2068$name\u2069?';
  }

  @override
  String get archive => 'העברה לארכיון';

  @override
  String archiveNote(String name) {
    return 'הפרופיל של \u2068$name\u2069 יוסתר מהאפליקציה. הכול נשמר, ואפשר להחזיר אותו מ״החיות שלי״.';
  }

  @override
  String archiveOnlyPetNote(String name) {
    return 'אין כרגע חיה נוספת להציג במקום \u2068$name\u2069. אפשר להוסיף קודם חיה נוספת, או למחוק את הפרופיל של \u2068$name\u2069.';
  }

  @override
  String get deleteForGood => 'מחיקה לצמיתות';

  @override
  String deleteNote(String name) {
    return 'הפרופיל, התמונה, רשומות הבריאות, התזכורות והמסמכים של \u2068$name\u2069 יימחקו. אי אפשר לבטל את הפעולה הזאת.';
  }

  @override
  String get suggested => 'מומלץ';

  @override
  String get archived => 'בארכיון';

  @override
  String get archivedNote => 'חיות בארכיון שומרות על כל הרשומות שלהן ומוסתרות משאר האפליקציה.';

  @override
  String archivedRow(String kind, String date) {
    return '\u2068$kind\u2069 · בארכיון מאז \u2068$date\u2069';
  }

  @override
  String petIsBack(String name) {
    return 'הפרופיל של \u2068$name\u2069 חזר';
  }

  @override
  String get errNotYours => 'אפשר לשנות רק את החיות שלך. כדאי להיכנס שוב לחשבון.';

  @override
  String get errInvalid => 'חלק מהפרטים לא תקינים. כדאי לבדוק ולנסות שוב.';

  @override
  String get errDatabaseOutdated => 'מסד הנתונים עדיין לא מעודכן לחיות (מיגרציה 0005 עוד לא הורצה).';

  @override
  String get errSignInAgain => 'צריך להיכנס שוב לחשבון.';

  @override
  String get errSave => 'לא הצלחנו לשמור את פרטי החיה. אפשר לנסות שוב.';

  @override
  String get errLoad => 'לא הצלחנו לטעון את החיות שלך. אפשר לנסות שוב.';

  @override
  String get errDelete => 'לא הצלחנו למחוק את החיה. אפשר לנסות שוב.';

  @override
  String get errPhotoSave => 'לא הצלחנו לשמור את התמונה. אפשר לנסות שוב.';

  @override
  String get errPhotoRemove => 'לא הצלחנו להסיר את התמונה. אפשר לנסות שוב.';

  @override
  String get errPhotoLoad => 'לא הצלחנו לטעון את התמונה. אפשר לנסות שוב.';

  @override
  String get errPhotoTooLarge => 'התמונה גדולה מדי.';

  @override
  String get errPhotoUnsupported => 'סוג התמונה הזה לא נתמך.';

  @override
  String get errPhotoUnsupportedChooseAnother => 'סוג התמונה הזה לא נתמך. אפשר לבחור תמונה אחרת.';

  @override
  String get errPhotoGone => 'התמונה הזאת כבר לא זמינה.';

  @override
  String get errOffline => 'אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get errCameraNotAllowed => 'אי אפשר לפתוח את המצלמה. כדאי לבדוק שיש ל־Pet Companion הרשאה להשתמש בה.';

  @override
  String get errPhotosNotAllowed => 'אי אפשר לפתוח את התמונות שלך. כדאי לבדוק שיש ל־Pet Companion הרשאה לראות אותן.';

  @override
  String get errCamera => 'לא הצלחנו לפתוח את המצלמה.';

  @override
  String get errPhotos => 'לא הצלחנו לפתוח את התמונות שלך.';
}
