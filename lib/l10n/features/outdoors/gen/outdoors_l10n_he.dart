// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'outdoors_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class OutdoorsL10nHe extends OutdoorsL10n {
  OutdoorsL10nHe([String locale = 'he']) : super(locale);

  @override
  String get sectionOutside => 'בחוץ';

  @override
  String get outsidePartners => 'שותפים';

  @override
  String get outsideParks => 'גינות';

  @override
  String get partnersSoonTitle => 'שותפים לטיול ולמשחק בדרך';

  @override
  String get partnersSoonBody => 'בקרוב יהיה אפשר למצוא כאן שותפים לטיול או למפגש משחק בסביבה. בינתיים, גינות הכלבים במרחק לחיצה.';

  @override
  String get partnersShowParks => 'לגינות';

  @override
  String get areaQuestion => 'איפה לחפש?';

  @override
  String get locationWhy => '״לידי״ מבקש מהטלפון את המיקום שלו פעם אחת. המיקום לא נשמר ולא נשלח.';

  @override
  String get nearMe => 'לידי';

  @override
  String get locating => 'מאתרים את המיקום…';

  @override
  String get orPickCity => 'או בחירה של עיר';

  @override
  String get cityHint => 'עיר או יישוב';

  @override
  String get noCityMatch => 'לא מצאנו יישוב בשם הזה. אפשר לנסות כתיב אחר.';

  @override
  String get problemDenied => 'לא התקבלה גישה למיקום. אפשר לבחור עיר במקום.';

  @override
  String get problemDeniedForever => 'הגישה למיקום כבויה עבור PetLoop. אפשר להפעיל אותה בהגדרות הטלפון, או לבחור עיר.';

  @override
  String get problemServiceOff => 'המיקום כבוי בטלפון. אפשר להפעיל אותו, או לבחור עיר.';

  @override
  String get problemUnavailable => 'לא הצלחנו לקבל את המיקום. אפשר לבחור עיר במקום.';

  @override
  String get problemOutsideRegion => 'בינתיים יש כאן גינות בישראל בלבד. אפשר לבחור עיר בישראל.';

  @override
  String get openSettings => 'פתיחת ההגדרות';

  @override
  String get areaNearMe => 'לידי';

  @override
  String areaNearMeIn(String place) {
    return 'לידי · \u2068$place\u2069';
  }

  @override
  String get changeArea => 'שינוי';

  @override
  String get changeAreaLabel => 'שינוי האזור';

  @override
  String areaChipLabel(String place) {
    return 'אזור: \u2068$place\u2069. שינוי האזור';
  }

  @override
  String approximateLocation(int km) {
    return 'המיקום משוער (בטווח של כ־$km ק״מ).';
  }

  @override
  String get radiusCityOnly => 'העיר בלבד';

  @override
  String radiusKm(int km) {
    return 'עד $km ק״מ';
  }

  @override
  String get filtersLabel => 'גינות עם';

  @override
  String get detailFenced => 'מגודרת';

  @override
  String get detailWater => 'ברז';

  @override
  String get detailShade => 'צל';

  @override
  String get detailLighting => 'תאורה';

  @override
  String get detailSmallDogs => 'פינה לקטנים';

  @override
  String get detailBenches => 'ספסלים';

  @override
  String get answerYes => 'כן';

  @override
  String get answerNo => 'לא';

  @override
  String get answerUnknown => 'לא ידוע';

  @override
  String get answerUnknownShort => '?';

  @override
  String detailAnswer(String detail, String answer) {
    return '\u2068$detail\u2069: \u2068$answer\u2069';
  }

  @override
  String get myParks => 'הגינות שלי';

  @override
  String get parksInArea => 'גינות באזור';

  @override
  String distanceKm(String km) {
    return '\u2068$km\u2069 ק״מ';
  }

  @override
  String distanceM(int m) {
    return '$m מ׳';
  }

  @override
  String get parkDefaultName => 'גינת כלבים';

  @override
  String parkOnStreet(String street) {
    return 'גינת כלבים · \u2068$street\u2069';
  }

  @override
  String parkInCity(String park, String city) {
    return '\u2068$park\u2069, \u2068$city\u2069';
  }

  @override
  String get closedLabel => 'סגורה לשיפוץ';

  @override
  String get searching => 'מחפשים גינות…';

  @override
  String get noParksTitle => 'לא מצאנו כאן גינות כלבים';

  @override
  String get noParksBody => 'המפה עוד לא מכירה גינת כלבים באזור הזה. מכירים אחת? אפשר לספר לנו.';

  @override
  String get noParksWider => 'חיפוש רחוק יותר';

  @override
  String get noFilterMatch => 'אין כאן גינה שידוע שיש בה את כל אלה.';

  @override
  String get clearFilters => 'ניקוי הסינון';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את הגינות.';

  @override
  String get missingPark => 'חסרה גינה?';

  @override
  String get suggestPark => 'הצעת גינה';

  @override
  String get sampleData => 'גינות לדוגמה: מקומות מומצאים לניסיון.';

  @override
  String reviewEntry(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הצעות לבדיקה',
      two: 'שתי הצעות לבדיקה',
      one: 'הצעה אחת לבדיקה',
    );
    return '$_temp0';
  }

  @override
  String get reviewEntryEmpty => 'הצעות לגינות';

  @override
  String get navigate => 'ניווט';

  @override
  String get navigateWith => 'ניווט עם';

  @override
  String get waze => 'Waze';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get navigateFailed => 'לא הצלחנו לפתוח את אפליקציית הניווט.';

  @override
  String get updateDetails => 'עדכון פרטים';

  @override
  String get saveToMyParks => 'שמירה לגינות שלי';

  @override
  String get removeFromMyParks => 'הסרה מהגינות שלי';

  @override
  String get savedToMyParks => 'נשמרה בגינות שלי';

  @override
  String get removedFromMyParks => 'הוסרה מהגינות שלי';

  @override
  String get saveFailed => 'השמירה לא הצליחה. אפשר לנסות שוב.';

  @override
  String get whatsThere => 'מה יש בגינה';

  @override
  String get openingHours => 'שעות פתיחה';

  @override
  String get unknownNote => 'ביקרת שם? ״עדכון פרטים״ עוזר לכולם לדעת למה לצפות.';

  @override
  String get osmCredit => 'נתוני מפה © OpenStreetMap contributors';

  @override
  String get memberPark => 'נוספה על ידי חברי PetLoop';

  @override
  String get parkGone => 'הגינה הזו כבר לא מופיעה ברשימה.';

  @override
  String get updateTitle => 'עדכון פרטים';

  @override
  String get updateIntro => 'מה ראית בגינה? מישהו מהצוות בודק את העדכון לפני שהוא מוצג לכולם.';

  @override
  String get closedSwitch => 'סגורה לשיפוץ';

  @override
  String get send => 'שליחה';

  @override
  String get nothingChanged => 'צריך לשנות לפחות פרט אחד.';

  @override
  String get sentThanks => 'תודה. העדכון ייבדק בקרוב.';

  @override
  String get rateLimited => 'זה הרבה הצעות ליום אחד. אפשר לנסות שוב מחר.';

  @override
  String get sendFailed => 'לא הצלחנו לשלוח. אפשר לנסות שוב.';

  @override
  String get suggestTitle => 'הצעת גינה';

  @override
  String get suggestIntro => 'אפשר לספר לנו על גינת כלבים שחסרה ברשימה. מישהו מהצוות בודק אותה לפני שהיא נוספת.';

  @override
  String get parkNameLabel => 'שם הגינה (לא חובה)';

  @override
  String get whereIsIt => 'איפה היא?';

  @override
  String get imHere => 'אני בגינה עכשיו';

  @override
  String get imHereWhy => 'המיקום שלך נשלח עם ההצעה בתור המיקום של הגינה, ותו לא.';

  @override
  String get hereSet => 'מיקום: המקום הנוכחי שלך';

  @override
  String get orTheCity => 'או בחירה של העיר';

  @override
  String get placeLabel => 'איפה בעיר?';

  @override
  String get placeHint => 'למשל: ליד המתנ״ס ברחוב הרצל';

  @override
  String get detailsOptional => 'מה יש בה? (לא חובה)';

  @override
  String get needLocation => 'צריך מיקום: ״אני בגינה עכשיו״, או בחירה של העיר ותיאור של המקום.';

  @override
  String get suggestSend => 'שליחת ההצעה';

  @override
  String get reviewTitle => 'הצעות לגינות';

  @override
  String get reviewEmpty => 'אין מה לבדוק.';

  @override
  String get reviewNewPark => 'גינה חדשה';

  @override
  String get reviewDetails => 'פרטים של גינה';

  @override
  String get reviewVanished => 'כבר לא מופיעה ב־OpenStreetMap';

  @override
  String get reviewVanishedBody => 'אפשר להשאיר אותה אם היא עדיין שם, לסמן אותה כסגורה, או להסיר אותה מהרשימה.';

  @override
  String get reviewFromPhone => 'מיקום: מהטלפון של מי שהציע, בגינה';

  @override
  String reviewFromCity(String city) {
    return 'מיקום: מרכז \u2068$city\u2069. כדאי לבדוק במפה.';
  }

  @override
  String reviewPlace(String place) {
    return 'מקום: \u2068$place\u2069';
  }

  @override
  String reviewChange(String detail, String from, String to) {
    return '\u2068$detail\u2069: \u2068$from\u2069 ← \u2068$to\u2069';
  }

  @override
  String get reviewClosed => 'בהצעה: סגורה לשיפוץ';

  @override
  String get reviewReopened => 'בהצעה: פתוחה שוב';

  @override
  String get showOnMap => 'הצגה במפה';

  @override
  String get approve => 'אישור';

  @override
  String get reject => 'דחייה';

  @override
  String get keepPark => 'השארה';

  @override
  String get markClosed => 'סימון כסגורה';

  @override
  String get removePark => 'הסרה';

  @override
  String get reviewDone => 'בוצע.';

  @override
  String get reviewFailed => 'זה לא הצליח. אפשר לנסות שוב.';

  @override
  String get pickParkTitle => 'בחירת גינה';

  @override
  String get reviewerTools => 'לבודקי הגינות';

  @override
  String get reopenPark => 'פתוחה שוב';

  @override
  String get removeConfirm => 'להסיר את הגינה מהרשימה? היא תוסתר ולא תימחק.';

  @override
  String get aboutMapData => 'גינות כלבים: נתוני מפה © OpenStreetMap contributors, לפי רישיון ODbL.';
}
