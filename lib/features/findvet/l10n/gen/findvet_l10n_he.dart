// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'findvet_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class FindVetL10nHe extends FindVetL10n {
  FindVetL10nHe([String locale = 'he']) : super(locale);

  @override
  String get findVetTitle => 'חיפוש וטרינר';

  @override
  String get findVetMenuSubtitle => 'חירום או טיפול שוטף בסביבה';

  @override
  String get loginEmergencyLink => 'מצב חירום? חיפוש וטרינר';

  @override
  String get emergencySheetFindVet => 'חיפוש וטרינר חירום קרוב';

  @override
  String get choiceQuestion => 'מה צריך?';

  @override
  String get emergencyChoiceTitle => 'טיפול חירום';

  @override
  String get emergencyChoiceBody => 'המקומות הקרובים שמפרסמים שירות חירום, עם חיוג וניווט.';

  @override
  String get longTermChoiceTitle => 'טיפול שוטף';

  @override
  String get longTermChoiceBody => 'מרפאות בסביבה עם הפרטים שלהן, ושמירה של וטרינר קבוע.';

  @override
  String get modeEmergency => 'חירום';

  @override
  String get modeLongTerm => 'שוטף';

  @override
  String get areaQuestion => 'איפה לחפש?';

  @override
  String get locationWhy => 'כדי למצוא וטרינרים קרובים, PetLoop מבקשת מהטלפון את המיקום שלך פעם אחת. הוא משמש רק לחיפוש הזה ולא נשמר.';

  @override
  String get useMyLocation => 'שימוש במיקום שלי';

  @override
  String get locating => 'מאתרים את המיקום…';

  @override
  String get orTypePlace => 'או הקלדה של עיר, כתובת או מיקוד';

  @override
  String get placeSearchHint => 'עיר, כתובת או מיקוד';

  @override
  String get placeSearchButton => 'חיפוש';

  @override
  String get placeNoMatch => 'לא מצאנו את המקום הזה. אפשר לנסות שם של עיר.';

  @override
  String get placeLookupFailed => 'לא הצלחנו לחפש את זה כרגע. אפשר לנסות שם של עיר.';

  @override
  String get problemDenied => 'לא ניתנה גישה למיקום. אפשר להקליד מקום במקום זה.';

  @override
  String get problemDeniedForever => 'הגישה למיקום כבויה עבור PetLoop. אפשר להפעיל אותה בהגדרות הטלפון, או להקליד מקום.';

  @override
  String get problemServiceOff => 'שירותי המיקום כבויים בטלפון. אפשר להפעיל אותם, או להקליד מקום.';

  @override
  String get problemUnavailable => 'לא הצלחנו לאתר את המיקום. אפשר להקליד מקום.';

  @override
  String get problemOutsideRegion => 'חיפוש וטרינר פועל כרגע רק בישראל. אפשר להקליד מקום בישראל.';

  @override
  String get openSettings => 'פתיחת ההגדרות';

  @override
  String searchingNear(String place) {
    return 'מחפשים ליד \u2068$place\u2069';
  }

  @override
  String get yourLocation => 'המיקום שלך';

  @override
  String approximateLocation(int km) {
    return 'המיקום משוער (בטווח של כ־$km ק״מ). אם הוא לא נראה נכון, אפשר לשנות את האזור.';
  }

  @override
  String get changeArea => 'שינוי';

  @override
  String get changeAreaLabel => 'שינוי האזור';

  @override
  String withinKm(int km) {
    return 'עד $km ק״מ';
  }

  @override
  String get searching => 'מחפשים וטרינרים…';

  @override
  String get callFirstTitle => 'כדאי להתקשר לפני שיוצאים';

  @override
  String get callFirstBody => 'שעות פתיחה ו״24/7״ לא אומרים אם יוכלו לקבל את החיה שלך עכשיו.';

  @override
  String get callToConfirm => 'כדאי להתקשר ולוודא שיוכלו לקבל את החיה שלך';

  @override
  String get evidenceListed => 'מופיע ברשימה באזור';

  @override
  String get evidenceListedNote => 'נמצא ברשימת מקומות במפה. PetLoop לא אימתה שיש שם שירות חירום.';

  @override
  String get evidenceAdvertised => 'מפרסמים שירות חירום';

  @override
  String evidenceAdvertisedSchedule(String schedule) {
    return 'מפרסמים שירות חירום · \u2068$schedule\u2069';
  }

  @override
  String evidenceSourceChecked(String date) {
    return 'באתר שלהם, נבדק לאחרונה ב־\u2068$date\u2069';
  }

  @override
  String get evidenceSourceNotChecked => 'באתר שלהם, עוד לא נבדק שוב';

  @override
  String get evidenceUnverified => 'שירות החירום לא אומת מחדש';

  @override
  String evidenceUnverifiedNote(String date) {
    return 'באתר שלהם זה לא הופיע בבדיקה האחרונה (\u2068$date\u2069). כדאי לשאול בטלפון.';
  }

  @override
  String get evidenceUnverifiedNoDate => 'לא הצלחנו לאמת את זה באתר שלהם לאחרונה. כדאי לשאול בטלפון.';

  @override
  String get evidenceOpenNow => 'לפי השעות שפורסמו: פתוח עכשיו';

  @override
  String get evidenceClosedNow => 'לפי השעות שפורסמו: סגור עכשיו';

  @override
  String get evidenceHoursUnknown => 'שעות הפתיחה לא פורסמו';

  @override
  String get evidenceAccepting => 'מקבלים מטופלים עכשיו';

  @override
  String get evidenceLimited => 'מקבלים מטופלים, בהיקף מוגבל';

  @override
  String get evidenceDiverting => 'מפנים מטופלים למקום אחר כרגע';

  @override
  String evidenceReported(String time, String until) {
    return 'דיווח של המקום בשעה \u2068$time\u2069, בתוקף עד \u2068$until\u2069';
  }

  @override
  String staleNote(String date) {
    return 'PetLoop בדקה את הפרטים האלה לאחרונה ב־\u2068$date\u2069.';
  }

  @override
  String get staleNever => 'PetLoop עוד לא בדקה את הפרטים האלה.';

  @override
  String get closedTemporarily => 'מופיע כסגור זמנית';

  @override
  String distanceKm(String km) {
    return '\u2068$km\u2069 ק״מ';
  }

  @override
  String distanceM(int m) {
    return '$m מ׳';
  }

  @override
  String get call => 'חיוג';

  @override
  String callName(String name) {
    return 'חיוג אל \u2068$name\u2069';
  }

  @override
  String get noPhone => 'אין מספר טלפון';

  @override
  String get directions => 'ניווט';

  @override
  String directionsName(String name) {
    return 'ניווט אל \u2068$name\u2069';
  }

  @override
  String get website => 'אתר';

  @override
  String get viewOnMaps => 'צפייה ב־Google Maps';

  @override
  String get save => 'שמירה';

  @override
  String saveName(String name) {
    return 'שמירת \u2068$name\u2069 כווטרינר קבוע';
  }

  @override
  String get saveChoosePet => 'שמירה כווטרינר קבוע עבור…';

  @override
  String saveForPet(String pet) {
    return 'שמירה עבור \u2068$pet\u2069';
  }

  @override
  String get saveNeedsPet => 'כדי לשמור וטרינר קבוע, צריך קודם להוסיף חיה.';

  @override
  String get savedVet => 'נשמר כווטרינר קבוע.';

  @override
  String get details => 'פרטים';

  @override
  String get fewerDetails => 'פחות פרטים';

  @override
  String get hoursTitle => 'שעות פתיחה שפורסמו';

  @override
  String speciesLine(String list) {
    return 'מטפלים ב: \u2068$list\u2069';
  }

  @override
  String servicesLine(String list) {
    return 'שירותים: \u2068$list\u2069';
  }

  @override
  String factSource(String date) {
    return 'מהאתר שלהם, נבדק ב־\u2068$date\u2069';
  }

  @override
  String get factSourceNoDate => 'מהאתר שלהם';

  @override
  String get speciesDog => 'כלבים';

  @override
  String get speciesCat => 'חתולים';

  @override
  String get speciesRabbit => 'ארנבים';

  @override
  String get speciesBird => 'ציפורים';

  @override
  String get speciesReptile => 'זוחלים';

  @override
  String get speciesRodent => 'מכרסמים קטנים';

  @override
  String get speciesExotic => 'חיות אקזוטיות';

  @override
  String get speciesHorse => 'סוסים';

  @override
  String get speciesFarm => 'חיות משק';

  @override
  String get sectionAdvertised => 'מפרסמים שירות חירום';

  @override
  String get sectionOther => 'וטרינרים נוספים באזור';

  @override
  String get sectionOtherNote => 'לא אומת שיש להם שירות חירום. כדאי להתקשר ולשאול.';

  @override
  String get sectionUnverified => 'שירות חירום שלא אומת מחדש';

  @override
  String get firstOption => 'האפשרות הקרובה';

  @override
  String get secondOption => 'אפשרות שנייה';

  @override
  String onlyOneAdvertised(int km) {
    return 'נמצא רק מקום אחד שמפרסם שירות חירום בטווח של $km ק״מ.';
  }

  @override
  String noticeExpanded(int km) {
    return 'לא נמצא מספיק קרוב, אז חיפשנו עד $km ק״מ.';
  }

  @override
  String get noticeProviderDown => 'החיפוש החי לא זמין כרגע. אלה מקומות חירום מהמאגר של PetLoop, כל אחד עם תאריך הבדיקה האחרונה.';

  @override
  String get noticeProviderDownLongTerm => 'החיפוש החי לא זמין כרגע. המרפאות האלה מגיעות מהמאגר של PetLoop.';

  @override
  String noticeDirectoryCopy(String date) {
    return 'אין חיבור. זה העותק של המאגר של PetLoop שנשמר בטלפון ב־\u2068$date\u2069.';
  }

  @override
  String get noResultsTitle => 'לא נמצאו וטרינרים באזור';

  @override
  String noResultsBody(int km) {
    return 'לא נמצא דבר בטווח של $km ק״מ.';
  }

  @override
  String noEmergencyResultsBody(int km) {
    return 'לא נמצא מקום שמפרסם שירות חירום בטווח של $km ק״מ.';
  }

  @override
  String searchWider(int km) {
    return 'חיפוש עד $km ק״מ';
  }

  @override
  String get tryAnotherArea => 'חיפוש באזור אחר';

  @override
  String get errorTitle => 'החיפוש לא הצליח';

  @override
  String get errorOffline => 'אין חיבור, ועדיין אין עותק שמור של המאגר. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get errorRateLimited => 'יותר מדי חיפושים בזמן קצר. אפשר לנסות שוב בעוד כמה דקות.';

  @override
  String get errorUnavailable => 'החיפוש לא זמין כרגע. אפשר לנסות שוב.';

  @override
  String get errorInvalid => 'אי אפשר לחפש במקום הזה. אפשר לנסות מקום אחר.';

  @override
  String get tryAgain => 'ניסיון נוסף';

  @override
  String get demoBanner => 'נתוני דוגמה: המקומות האלה מומצאים. החיפוש האמיתי עובד כשהאפליקציה מחוברת לשרת.';

  @override
  String get listingsFrom => 'רשימת המקומות במפה:';

  @override
  String get legendLink => 'מה אומרות התוויות';

  @override
  String get legendListedBody => 'נמצא ברשימת מקומות במפה באזור. זה לבד לא אומר כלום על שירות חירום, גם אם השם אומר.';

  @override
  String get legendAdvertisedBody => 'האתר של המקום עצמו (או המקום עצמו) אומר שיש שם שירות חירום. PetLoop בודקת את זה כל שבוע ומראה את תאריך הבדיקה האחרונה.';

  @override
  String get legendOpenBody => 'לפי השעות שפורסמו, המקום פתוח עכשיו. זה לא אומר שיש וטרינר פנוי לחיה שלך.';

  @override
  String get legendAcceptingBody => 'מוצג רק כשהמקום עצמו דיווח שהוא מקבל מטופלים, ורק עד שהדיווח פג. אחרת יופיע ״כדאי להתקשר ולוודא״.';

  @override
  String get legendCallBody => 'החיוג לא מסמן שום דבר כמאושר. רק המקום יכול לומר אם יוכלו לקבל את החיה שלך עכשיו.';

  @override
  String get adminTitle => 'בדיקת מאגר הווטרינרים';

  @override
  String get adminMenuSubtitle => 'אישור, תיקון או הסרה של מקומות';

  @override
  String get adminNeedsAttention => 'דורש טיפול';

  @override
  String get adminNoItems => 'אין מה לבדוק.';

  @override
  String get adminFacilities => 'מקומות';

  @override
  String get adminResolve => 'טופל';

  @override
  String get adminDismiss => 'התעלמות';

  @override
  String get adminApprove => 'אישור';

  @override
  String get adminMarkReview => 'סימון לבדיקה';

  @override
  String get adminWithdraw => 'הסרה';

  @override
  String get adminWithdrawEmergency => 'הסרת החירום';

  @override
  String get adminCorrect => 'תיקון פרט';

  @override
  String get adminNoteHint => 'הערה: מה נבדק';

  @override
  String get adminFact => 'פרט';

  @override
  String get adminValue => 'ערך';

  @override
  String get adminValueHint => 'ברשימה, להפריד בפסיקים';

  @override
  String get adminSourceUrl => 'קישור למקור (https://…)';

  @override
  String get adminSourceRequired => 'צריך קישור למקור שמתחיל ב־https://.';

  @override
  String get adminValueRequired => 'צריך ערך.';

  @override
  String get adminStatusPending => 'ממתין לאישור';

  @override
  String get adminStatusApproved => 'מאושר';

  @override
  String get adminStatusNeedsReview => 'דורש בדיקה';

  @override
  String get adminStatusWithdrawn => 'הוסר';

  @override
  String get adminClaimStatusCurrent => 'בתוקף';

  @override
  String get adminClaimStatusUnverified => 'לא אומת מחדש';

  @override
  String get adminClaimStatusConflict => 'סתירה';

  @override
  String get adminClaimStatusWithdrawn => 'הוסר';

  @override
  String get adminFactKeyEmergency => 'שירות חירום';

  @override
  String get adminFactKeySchedule => 'שעות';

  @override
  String get adminFactKeyPhone => 'טלפון';

  @override
  String get adminFactKeyAddress => 'כתובת';

  @override
  String get adminFactKeyWebsite => 'אתר';

  @override
  String get adminFactKeySpecies => 'חיות';

  @override
  String get adminFactKeyServices => 'שירותים';

  @override
  String get adminKindEmergencyEvidenceMissing => 'הראיה לשירות חירום חסרה';

  @override
  String get adminKindPhoneConflict => 'מספר הטלפון שונה';

  @override
  String get adminKindAddressConflict => 'הכתובת שונה';

  @override
  String get adminKindClosure => 'ייתכן שנסגר';

  @override
  String get adminKindSourceUnreachable => 'דף המקור לא זמין';

  @override
  String get adminKindNewEmergencyEvidence => 'נמצא ניסוח חדש על חירום';

  @override
  String get adminKindVerifyCoordinates => 'לבדוק את המיקום במפה';

  @override
  String get adminKindLinkCandidate => 'התאמה אפשרית לרשימה במפה';

  @override
  String get adminKindRobotsDisallowed => 'האתר לא מאפשר בדיקה';

  @override
  String get adminSeverityHigh => 'גבוהה';

  @override
  String get adminSeverityMedium => 'בינונית';

  @override
  String get adminSeverityLow => 'נמוכה';

  @override
  String adminLastChecked(String date) {
    return 'נבדק לאחרונה ב־\u2068$date\u2069';
  }

  @override
  String get adminNeverChecked => 'לא נבדק אף פעם';

  @override
  String get adminLoadFailed => 'לא הצלחנו לטעון את רשימת הבדיקה.';

  @override
  String get adminSaved => 'נשמר.';

  @override
  String get adminActionFailed => 'השמירה לא הצליחה. אפשר לנסות שוב.';

  @override
  String get adminNotAllowed => 'הדף הזה מיועד לבודקי המאגר.';
}
