// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'access_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AccessL10nHe extends AccessL10n {
  AccessL10nHe([String locale = 'he']) : super(locale);

  @override
  String get title => 'הרשאות לתכונות';

  @override
  String get refresh => 'רענון';

  @override
  String get tabUsers => 'משתמשים';

  @override
  String get tabGroups => 'קבוצות';

  @override
  String get tabFeatures => 'תכונות';

  @override
  String get tabAudit => 'היסטוריה';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את הגדרות ההרשאות. אפשר לנסות שוב.';

  @override
  String get retry => 'נסו שוב';

  @override
  String get user => 'משתמש';

  @override
  String get groupMembership => 'חברות בקבוצות';

  @override
  String get individualOverrides => 'הרשאות אישיות';

  @override
  String get group => 'קבוצה';

  @override
  String get newGroup => 'קבוצה חדשה';

  @override
  String get groupName => 'שם הקבוצה';

  @override
  String get create => 'יצירה';

  @override
  String get featuresNote => 'תכונה כבויה חסומה לכולם. הרשאות אישיות גוברות על קבוצות; חסימה בקבוצה גוברת על אישור בקבוצה.';

  @override
  String get publicVetSearch => 'חיפוש וטרינר לציבור';

  @override
  String get ruleInherit => 'ירושה';

  @override
  String get ruleAllow => 'אישור';

  @override
  String get ruleDeny => 'חסימה';

  @override
  String get allowed => 'מותר';

  @override
  String get blocked => 'חסום';

  @override
  String ruleSummary(String status, String reason) {
    return '\u2068$status\u2069 · \u2068$reason\u2069';
  }

  @override
  String capabilityLabel(String feature, String action) {
    return '\u2068$feature\u2069 · \u2068$action\u2069';
  }

  @override
  String get featurePets => 'פרופילי חיות';

  @override
  String get featureCare => 'טיפול יומי';

  @override
  String get featureHealth => 'בריאות';

  @override
  String get featureHealthRecords => 'רישומי בריאות';

  @override
  String get featureHealthSchedule => 'תזמון בריאות';

  @override
  String get featureHealthEmergency => 'כלי חירום';

  @override
  String get featureCommunity => 'קהילה';

  @override
  String get featureCommunityFeed => 'פוסטים בקהילה';

  @override
  String get featureCommunityChat => 'צ׳אט בקהילה';

  @override
  String get featureCommunityGuides => 'מדריכים';

  @override
  String get featureCommunityParks => 'גינות כלבים';

  @override
  String get featureCommunityMeetups => 'שותפים לטיול ולמשחק';

  @override
  String get featureHousehold => 'הבית';

  @override
  String get featureDeals => 'מבצעים';

  @override
  String get featureBudget => 'תקציב';

  @override
  String get featureBasket => 'סל קניות';

  @override
  String get featureFirstDays => 'הימים הראשונים';

  @override
  String get featureFindVet => 'חיפוש וטרינר';

  @override
  String get actionView => 'צפייה';

  @override
  String get actionEdit => 'עריכה';

  @override
  String get actionExport => 'ייצוא';

  @override
  String get actionPost => 'פרסום';

  @override
  String get actionSend => 'שליחה';

  @override
  String get actionShare => 'שיתוף';

  @override
  String get actionSearch => 'חיפוש';

  @override
  String get actionAdmin => 'ניהול המדריך';

  @override
  String get actionModerate => 'בדיקת דיווחים';

  @override
  String get actionSuggest => 'הצעת תיקונים';

  @override
  String get actionReview => 'בדיקת הצעות';

  @override
  String get actionPrivate => 'שיחות פרטיות';

  @override
  String get auditIntroDemo => 'היסטוריית ההדגמה מתאפסת בסגירת האפליקציה. לחצו על רשומה לפרטים.';

  @override
  String get auditIntroSaved => 'היסטוריית ניהול שמורה. לחצו על רשומה לפרטים.';

  @override
  String get auditActorFilter => 'דוא״ל או מזהה מנהל';

  @override
  String get auditActionType => 'סוג פעולה';

  @override
  String get auditAllActions => 'כל הפעולות';

  @override
  String get auditAnyDate => 'כל תאריך';

  @override
  String get auditSearch => 'חיפוש בהיסטוריה';

  @override
  String get auditClearFilters => 'ניקוי מסננים';

  @override
  String get auditLoadFailed => 'טעינת ההיסטוריה נכשלה. בדקו את החיבור ואת עדכון מסד הנתונים 0017.';

  @override
  String get auditEmpty => 'לא נמצאו פעולות ניהול.';

  @override
  String get auditLoadOlder => 'טעינת פעולות קודמות';

  @override
  String get auditSystemActor => 'מערכת / בעל מסד הנתונים';

  @override
  String auditEntryNumber(int id) {
    return 'רשומה #$id';
  }

  @override
  String get auditBefore => 'לפני';

  @override
  String get auditAfter => 'אחרי';

  @override
  String get auditNoPreviousValue => 'אין ערך קודם';

  @override
  String get auditRemoved => 'הוסר';

  @override
  String get categoryFeatureSettings => 'הגדרות תכונות';

  @override
  String get categoryGroups => 'קבוצות';

  @override
  String get categoryGroupMembership => 'חברות בקבוצות';

  @override
  String get categoryUserRules => 'הרשאות אישיות';

  @override
  String get categoryGroupRules => 'הרשאות קבוצתיות';

  @override
  String get categoryAdmins => 'מנהלי הרשאות';

  @override
  String get categoryCapabilities => 'קטלוג הרשאות';

  @override
  String get categoryVetDirectory => 'סקירת מדריך וטרינרים';

  @override
  String get unavailableTitle => 'לא ניתן לטעון את הרשאות החשבון';

  @override
  String get unavailableMessage => 'כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get signOut => 'יציאה מהחשבון';

  @override
  String get gateTitle => 'גישה לתכונה';

  @override
  String get gateUnavailable => 'התכונה אינה זמינה';

  @override
  String get gateMessage => 'אין לחשבון שלך גישה לתכונה הזאת כרגע.';

  @override
  String get featureCommunityHazards => 'דיווחים על סכנות';
}
