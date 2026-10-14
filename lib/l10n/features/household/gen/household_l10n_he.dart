// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'household_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class HouseholdL10nHe extends HouseholdL10n {
  HouseholdL10nHe([String locale = 'he']) : super(locale);

  @override
  String get title => 'הבית';

  @override
  String nameOnePet(String pet) {
    return 'הבית של \u2068$pet\u2069';
  }

  @override
  String nameTwoPets(String first, String second) {
    return 'הבית של \u2068$first\u2069 ושל \u2068$second\u2069';
  }

  @override
  String nameOfPerson(String name) {
    return 'הבית של \u2068$name\u2069';
  }

  @override
  String get nameOurs => 'הבית שלנו';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשים',
      two: 'שני אנשים',
      one: 'אדם אחד',
    );
    return '$_temp0';
  }

  @override
  String petsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חיות',
      two: 'שתי חיות',
      one: 'חיה אחת',
      zero: 'עדיין אין חיות',
    );
    return '$_temp0';
  }

  @override
  String get youRowSolo => 'טיפול משותף בחיות עם בני הבית';

  @override
  String get sectionPeople => 'אנשים';

  @override
  String get sectionPets => 'חיות';

  @override
  String get roleOwner => 'בעלים';

  @override
  String get roleCarer => 'טיפול';

  @override
  String get invitedTag => 'הוזמנו';

  @override
  String get you => 'החשבון שלי';

  @override
  String joinedOn(String date) {
    return 'הצטרפות: \u2068$date\u2069';
  }

  @override
  String invitedBy(String name) {
    return 'הזמנה מאת \u2068$name\u2069';
  }

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'נשארו $days ימים',
      two: 'נשארו יומיים',
      one: 'נשאר יום אחד',
      zero: 'מסתיימת היום',
    );
    return '$_temp0';
  }

  @override
  String get openInvitation => 'הזמנה פתוחה';

  @override
  String get inviteSomeone => 'הזמנה לבית';

  @override
  String get haveCode => 'יש לי קוד הזמנה';

  @override
  String get soloLine => 'בהזמנה לבית אפשר לראות את אותן החיות, לרשום ארוחות, טיולים ומנות תרופה ולקבל את התזכורות.';

  @override
  String get petsEmpty => 'עדיין אין חיות בבית הזה.';

  @override
  String get rename => 'שינוי שם';

  @override
  String get renameTitle => 'השם של הבית';

  @override
  String get renameHint => 'בלי שם, הבית נקרא על שם החיות.';

  @override
  String get leave => 'יציאה מהבית';

  @override
  String get leaveConfirmTitle => 'יציאה מהבית הזה?';

  @override
  String get leaveConfirmBody => 'החיות של הבית לא יופיעו יותר באפליקציה שלך. מה שרשמת נשאר אצלן.';

  @override
  String get leaveAction => 'יציאה';

  @override
  String get leftSnack => 'היציאה מהבית בוצעה.';

  @override
  String get remove => 'הסרה מהבית';

  @override
  String removeConfirmTitle(String name) {
    return 'הסרה של \u2068$name\u2069?';
  }

  @override
  String removeConfirmBody(String name) {
    return 'החיות של הבית לא יופיעו יותר אצל \u2068$name\u2069. מה שנרשם נשאר.';
  }

  @override
  String get removeAction => 'הסרה';

  @override
  String removedSnack(String name) {
    return '\u2068$name\u2069 כבר לא בבית.';
  }

  @override
  String get takeBack => 'ביטול ההזמנה';

  @override
  String get takenBackSnack => 'ההזמנה בוטלה.';

  @override
  String get inviteTitle => 'הזמנה לבית';

  @override
  String get inviteCanTitle => 'אחרי ההצטרפות אפשר:';

  @override
  String get inviteCan1 => 'צפייה ועריכה של הטיפול, התרופות והתיעוד הרפואי';

  @override
  String get inviteCan2 => 'רישום ארוחות, טיולים ומנות תרופה';

  @override
  String get inviteCan3 => 'קבלת התזכורות';

  @override
  String get inviteCodeLabel => 'קוד הזמנה';

  @override
  String get inviteValidity => 'תקף לשבעה ימים, לאדם אחד.';

  @override
  String get inviteShare => 'שיתוף ההזמנה';

  @override
  String get copyCode => 'העתקת הקוד';

  @override
  String get codeCopied => 'הקוד הועתק.';

  @override
  String inviteShareText(String household, String link, String code) {
    return 'הזמנה להצטרפות: \u2068$household\u2069 ב־PetLoop. אפשר לפתוח את \u2068$link\u2069 או להזין את הקוד \u2068$code\u2069 ב־PetLoop (החשבון שלי › הבית).';
  }

  @override
  String get joinTitle => 'הצטרפות לבית';

  @override
  String get joinCodeHint => 'למשל KELY-7Q4M';

  @override
  String get joinContinue => 'המשך';

  @override
  String joinInvitationFrom(String name) {
    return 'הזמנה מאת \u2068$name\u2069';
  }

  @override
  String get joinAction => 'הצטרפות';

  @override
  String get joinDecline => 'לא תודה';

  @override
  String get joinedSnack => 'ההצטרפות לבית הושלמה.';

  @override
  String get errNotFound => 'הקוד הזה לא מוביל להזמנה. כדאי לבדוק אותו ולנסות שוב.';

  @override
  String get errExpired => 'ההזמנה הזאת הסתיימה. כדאי לבקש הזמנה חדשה.';

  @override
  String get errUsed => 'כבר השתמשו בהזמנה הזאת.';

  @override
  String get errMember => 'הבית הזה כבר ברשימה שלך.';

  @override
  String get errFull => 'הבית הזה מלא (10 אנשים).';

  @override
  String get errSlowDown => 'רגע, זה היה מהר. אפשר לנסות שוב עוד מעט.';

  @override
  String get errNotAvailable => 'האפשרות הזאת לא זמינה בחשבון הזה.';

  @override
  String get errOwnerOnly => 'רק הבעלים של הבית יכולים לעשות את זה.';

  @override
  String get errName => 'השם הזה ארוך מדי.';

  @override
  String get errOffline => 'לא הצלחנו להתחבר ל־PetLoop. אפשר לנסות שוב.';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את הבית.';

  @override
  String heroWith(String names) {
    return 'יחד עם \u2068$names\u2069';
  }

  @override
  String heroWithLabel(String names) {
    return 'טיפול משותף עם \u2068$names\u2069';
  }
}
