// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'budget_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class BudgetL10nHe extends BudgetL10n {
  BudgetL10nHe([String locale = 'he']) : super(locale);

  @override
  String get budgetTitle => 'תקציב';

  @override
  String get menuBudgetSummary => 'כמה עולות החיות בכל חודש';

  @override
  String get allHome => 'כל הבית';

  @override
  String get wholeHome => 'כל הבית';

  @override
  String get previousMonth => 'החודש הקודם';

  @override
  String get nextMonth => 'החודש הבא';

  @override
  String get spentLabel => 'הוצאות';

  @override
  String previousMonthLine(String month, String amount) {
    return '\u2068$month\u2069: \u2068$amount\u2069';
  }

  @override
  String changeUp(String percent, String month) {
    return '↑ \u2068$percent\u2069% לעומת \u2068$month\u2069';
  }

  @override
  String changeDown(String percent, String month) {
    return '↓ \u2068$percent\u2069% לעומת \u2068$month\u2069';
  }

  @override
  String changeSame(String month) {
    return 'אותו סכום כמו ב־\u2068$month\u2069';
  }

  @override
  String averageLine(String amount) {
    return 'ממוצע חודשי: \u2068$amount\u2069';
  }

  @override
  String get averageNote =>
      'על פני 12 החודשים האחרונים לכל היותר. הוצאה שנתית נספרת כ־1/12 בכל חודש.';

  @override
  String get byCategory => 'לפי קטגוריה';

  @override
  String get expensesTitle => 'הוצאות';

  @override
  String get noExpenses => 'אין הוצאות בחודש הזה.';

  @override
  String get addExpense => 'הוספת הוצאה';

  @override
  String get healthMissing =>
      'לא הצלחנו לטעון את העלויות מ״בריאות״, ולכן הן לא נספרות כאן.';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את התקציב';

  @override
  String get sourceHealth => 'מ״בריאות״';

  @override
  String get sourceBasket => 'מהסל';

  @override
  String get sourceManual => 'ידני';

  @override
  String get tagEveryMonth => 'כל חודש';

  @override
  String get tagEveryYear => 'כל שנה';

  @override
  String get categoryFood => 'מזון';

  @override
  String get categoryLitter => 'חול ומתכלים';

  @override
  String get categoryVet => 'וטרינר ותרופות';

  @override
  String get categoryEquipment => 'ציוד';

  @override
  String get categoryServices => 'שירותים';

  @override
  String get categoryOther => 'אחר';

  @override
  String get newExpense => 'הוצאה חדשה';

  @override
  String get editExpense => 'עריכת הוצאה';

  @override
  String get amountLabel => 'סכום';

  @override
  String get amountInvalid => 'צריך להזין סכום, למשל 120';

  @override
  String get categoryLabel => 'קטגוריה';

  @override
  String get forLabel => 'עבור';

  @override
  String get dateLabel => 'תאריך';

  @override
  String get noteLabel => 'הערה';

  @override
  String get noteHint => 'על מה? (לא חובה)';

  @override
  String get howOften => 'באיזו תדירות';

  @override
  String get once => 'פעם אחת';

  @override
  String get everyMonth => 'כל חודש';

  @override
  String get everyYear => 'כל שנה';

  @override
  String get monthlyNote =>
      'נרשמת פעם אחת: היא נספרת שוב בכל חודש מהתאריך הזה, עד שעוצרים אותה.';

  @override
  String get yearlyNote =>
      'נספרת בחודש הזה בכל שנה. בממוצע החודשי היא נספרת כ־1/12 בכל חודש.';

  @override
  String get stopRepeating => 'הפסקת החזרה';

  @override
  String get keepRepeating => 'חידוש החזרה';

  @override
  String stoppedOn(String date) {
    return 'הופסקה ב־\u2068$date\u2069';
  }

  @override
  String get deleteExpenseTitle => 'למחוק את ההוצאה?';

  @override
  String get deleteExpenseBody =>
      'היא תוסר מהתקציב. אי אפשר לבטל את הפעולה הזאת.';

  @override
  String get deleteRecurringBody =>
      'היא תוסר מכל החודשים שבהם נספרה. כדי לשמור את החודשים הקודמים, אפשר להפסיק את החזרה במקום.';

  @override
  String get expenseSaved => 'נשמר';

  @override
  String get expenseDeleted => 'ההוצאה נמחקה';

  @override
  String get deals => 'מבצעים';

  @override
  String get myBasket => 'הסל שלי';

  @override
  String get basketEmptyTitle => 'הסל שלך עדיין ריק';

  @override
  String get basketEmptyMessage =>
      'אפשר להוסיף כאן את המזון, החול ושאר הדברים שקונים שוב ושוב, ולראות מתי כל אחד נגמר.';

  @override
  String get regularProduct => 'מוצר קבוע';

  @override
  String get boughtAgain => 'קניתי שוב';

  @override
  String boughtOn(String date) {
    return 'קנייה אחרונה \u2068$date\u2069';
  }

  @override
  String runsOutOn(String date) {
    return 'סיום משוער \u2068$date\u2069';
  }

  @override
  String ranOutOn(String date) {
    return 'המלאי נגמר \u2068$date\u2069';
  }

  @override
  String byFeeding(String grams) {
    return 'לפי \u2068$grams\u2069 גרם ביום מההאכלה';
  }

  @override
  String get notBoughtYet => 'עוד לא נקנה';

  @override
  String dealsOnFood(int count, String animals) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מבצעים על מזון עבור \u2068$animals\u2069',
      two: 'שני מבצעים על מזון עבור \u2068$animals\u2069',
      one: 'מבצע אחד על מזון עבור \u2068$animals\u2069',
    );
    return '$_temp0';
  }

  @override
  String dealsOnLitter(int count, String animals) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מבצעים על חול וניקיון עבור \u2068$animals\u2069',
      two: 'שני מבצעים על חול וניקיון עבור \u2068$animals\u2069',
      one: 'מבצע אחד על חול וניקיון עבור \u2068$animals\u2069',
    );
    return '$_temp0';
  }

  @override
  String runsOutIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נשארו $count ימים',
      two: 'נשארו יומיים',
      one: 'נשאר יום אחד',
      zero: 'היום האחרון',
    );
    return '$_temp0';
  }

  @override
  String get ranOut => 'המלאי נגמר';

  @override
  String reminderTitle(String name) {
    return 'המלאי של \u2068$name\u2069 עומד להיגמר';
  }

  @override
  String reminderBody(int count, String name, String pet, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'המלאי של \u2068$name\u2069 עבור \u2068$pet\u2069 ייגמר בעוד $count ימים (\u2068$date\u2069).',
      two:
          'המלאי של \u2068$name\u2069 עבור \u2068$pet\u2069 ייגמר בעוד יומיים (\u2068$date\u2069).',
      one:
          'המלאי של \u2068$name\u2069 עבור \u2068$pet\u2069 ייגמר מחר (\u2068$date\u2069).',
    );
    return '$_temp0';
  }

  @override
  String get newProduct => 'מוצר קבוע חדש';

  @override
  String get editProduct => 'עריכת מוצר';

  @override
  String get productName => 'מוצר';

  @override
  String get productNameHint => 'מזון יבש לבוגרים';

  @override
  String get nameRequired => 'צריך להזין את שם המוצר';

  @override
  String get kindLabel => 'סוג';

  @override
  String get kindFood => 'מזון';

  @override
  String get kindLitter => 'חול';

  @override
  String get kindConsumable => 'מתכלה';

  @override
  String get kindOther => 'אחר';

  @override
  String get packageSize => 'גודל האריזה';

  @override
  String get sizeInvalid => 'צריך להזין גודל, למשל 12';

  @override
  String get unitKg => 'ק״ג';

  @override
  String get unitG => 'גרם';

  @override
  String get unitL => 'ליטר';

  @override
  String get unitUnits => 'יחידות';

  @override
  String get lastPrice => 'מחיר';

  @override
  String get boughtOnLabel => 'תאריך קנייה';

  @override
  String get lastsLabel => 'כמה זמן אריזה מחזיקה';

  @override
  String get lastsByFeedingChoice => 'לפי ההאכלה';

  @override
  String get lastsOwnChoice => 'הערכה שלי';

  @override
  String lastsByFeeding(String days, String grams) {
    return 'בערך \u2068$days\u2069 ימים, לפי \u2068$grams\u2069 גרם ביום מההאכלה.';
  }

  @override
  String get lastsNoFeeding =>
      'כדי לחשב לפי ההאכלה צריך מנה ושעות האכלה בדף ההאכלה, וגודל בק״ג או בגרם.';

  @override
  String get lastsAbout => 'מחזיקה בערך';

  @override
  String get lastsInvalid => 'צריך להזין מספר, למשל 30';

  @override
  String get days => 'ימים';

  @override
  String get weeks => 'שבועות';

  @override
  String get lastsOptional =>
      'אפשר להשאיר ריק אם לא בטוחים: פשוט לא יהיה תאריך סיום.';

  @override
  String get deleteProductTitle => 'להסיר את המוצר?';

  @override
  String get deleteProductBody => 'הקניות הקודמות שלו נשארות בתקציב.';

  @override
  String get productDeleted => 'המוצר הוסר';

  @override
  String boughtAgainTitle(String name) {
    return 'קניתי שוב: \u2068$name\u2069';
  }

  @override
  String get boughtAgainNote => 'נשמר כהוצאה בתקציב.';

  @override
  String addedToBudget(String amount) {
    return '\u2068$amount\u2069 נוספו לתקציב';
  }

  @override
  String get spendingTitle => 'ההוצאות החודש';

  @override
  String get openBudget => 'פתיחת התקציב';

  @override
  String get runningLowTitle => 'מלאי נמוך';

  @override
  String get openBasket => 'פתיחת הסל שלי';

  @override
  String get errorOffline =>
      'לא הצלחנו להתחבר לשרת. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get errorSessionEnded => 'פג תוקף החיבור. צריך להיכנס שוב.';

  @override
  String get errorNotAllowed => 'אין הרשאה לפעולה הזאת. צריך להיכנס שוב.';

  @override
  String get errorInvalid => 'חלק מהפרטים לא תקינים. כדאי לבדוק אותם.';

  @override
  String get errorPetNotStored =>
      'החיה עוד לא שמורה בחשבון שלך, ולכן אי אפשר לשמור עבורה כלום.';

  @override
  String get errorGone => 'הפריט הזה כבר לא קיים.';

  @override
  String get errorNeedsUpdate => 'התקציב עוד לא הוגדר בשרת.';

  @override
  String get errorUnknown => 'משהו השתבש. אפשר לנסות שוב.';
}
