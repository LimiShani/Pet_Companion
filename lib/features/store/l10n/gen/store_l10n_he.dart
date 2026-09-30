// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'store_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class StoreL10nHe extends StoreL10n {
  StoreL10nHe([String locale = 'he']) : super(locale);

  @override
  String get tabTitle => 'חנות';

  @override
  String get searchHint => 'חיפוש מבצעים';

  @override
  String get clearSearch => 'ניקוי החיפוש';

  @override
  String get savedDeals => 'מבצעים ששמרתי';

  @override
  String get shareADeal => 'שיתוף מבצע';

  @override
  String get allAnimals => 'כל החיות';

  @override
  String get allCategories => 'הכול';

  @override
  String get sortTooltip => 'מיון המבצעים';

  @override
  String get couldNotLoadDeals => 'לא הצלחנו לטעון את המבצעים';

  @override
  String get couldNotRefresh => 'לא הצלחנו לרענן את המבצעים. אפשר לנסות שוב.';

  @override
  String get dealIsLive => 'תודה, המבצע שלך פורסם.';

  @override
  String dealCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מבצעים',
      two: 'שני מבצעים',
      one: 'מבצע אחד',
    );
    return '$_temp0';
  }

  @override
  String dealCountFor(int count, String animals) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מבצעים',
      two: 'שני מבצעים',
      one: 'מבצע אחד',
      zero: 'אין מבצעים',
    );
    return '$_temp0 עבור \u2068$animals\u2069';
  }

  @override
  String get noDealsYetTitle => 'עדיין אין מבצעים';

  @override
  String get noDealsYetMessage => 'מבצעים חדשים יופיעו כאן. מצאת מבצע טוב? אפשר לשתף אותו עם בעלי חיות אחרים.';

  @override
  String get noDealsFoundTitle => 'לא נמצאו מבצעים';

  @override
  String get clearFilters => 'ניקוי הסינון';

  @override
  String get showAllAnimals => 'הצגת כל החיות';

  @override
  String noDealsInCategory(String category) {
    return 'אין כרגע מבצעים בקטגוריה \u2068$category\u2069. אפשר לנסות קטגוריה אחרת.';
  }

  @override
  String nothingMatches(String query) {
    return 'לא נמצא דבר עבור ״\u2068$query\u2069״. אפשר לנסות מילה אחרת.';
  }

  @override
  String nothingMatchesInCategory(String query, String category) {
    return 'לא נמצא דבר עבור ״\u2068$query\u2069״ בקטגוריה \u2068$category\u2069. אפשר לנסות מילה אחרת או קטגוריה אחרת.';
  }

  @override
  String noDealsForAnimalsTitle(String animals) {
    return 'אין כאן מבצעים עבור \u2068$animals\u2069';
  }

  @override
  String noneForAnimals(String animals) {
    return 'אין כרגע מבצעים עבור \u2068$animals\u2069.';
  }

  @override
  String noneForAnimalsInCategory(String animals, String category) {
    return 'אין כרגע דבר עבור \u2068$animals\u2069 בקטגוריה \u2068$category\u2069.';
  }

  @override
  String noneForAnimalsMatching(String animals, String query) {
    return 'לא נמצא דבר עבור \u2068$animals\u2069 שמתאים לחיפוש ״\u2068$query\u2069״.';
  }

  @override
  String noneForAnimalsMatchingInCategory(String animals, String query, String category) {
    return 'לא נמצא דבר עבור \u2068$animals\u2069 שמתאים לחיפוש ״\u2068$query\u2069״ בקטגוריה \u2068$category\u2069.';
  }

  @override
  String othersHaveDeals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מבצעים',
      two: 'שני מבצעים',
      one: 'מבצע אחד',
    );
    return 'לחיות אחרות יש כאן $_temp0.';
  }

  @override
  String get categoryFood => 'מזון';

  @override
  String get categoryTreats => 'חטיפים';

  @override
  String get categoryLitterAndCleaning => 'חול וניקיון';

  @override
  String get categoryToys => 'צעצועים';

  @override
  String get categoryHealth => 'בריאות';

  @override
  String get categoryGrooming => 'טיפוח';

  @override
  String get categoryAccessories => 'אביזרים';

  @override
  String get categoryBedsAndCrates => 'מיטות וכלובים';

  @override
  String get sortBiggestDiscount => 'ההנחה הגדולה ביותר';

  @override
  String get sortLowestPrice => 'המחיר הנמוך ביותר';

  @override
  String get sortLowestUnitPrice => 'המחיר הנמוך ביותר ליחידת מידה';

  @override
  String get sortNewest => 'החדשים ביותר';

  @override
  String get sortEndingSoon => 'מסתיימים בקרוב';

  @override
  String get animalsDog => 'כלבים';

  @override
  String get animalsCat => 'חתולים';

  @override
  String get animalsBird => 'ציפורים';

  @override
  String get animalsRabbit => 'ארנבונים';

  @override
  String get animalsReptile => 'זוחלים';

  @override
  String get animalsOther => 'אחר';

  @override
  String get animalsInSentenceDog => 'כלבים';

  @override
  String get animalsInSentenceCat => 'חתולים';

  @override
  String get animalsInSentenceBird => 'ציפורים';

  @override
  String get animalsInSentenceRabbit => 'ארנבונים';

  @override
  String get animalsInSentenceReptile => 'זוחלים';

  @override
  String get animalsInSentenceOther => 'חיות אחרות';

  @override
  String get allPets => 'כל החיות';

  @override
  String get forAllPets => 'לכל החיות';

  @override
  String forAnimals(String animals) {
    return 'עבור \u2068$animals\u2069';
  }

  @override
  String listAnd(String first, String last) {
    return '\u2068$first\u2069 ו\u2068$last\u2069';
  }

  @override
  String listComma(String first, String next) {
    return '\u2068$first\u2069, \u2068$next\u2069';
  }

  @override
  String get unitKg => 'ק״ג';

  @override
  String get unitG => 'גרם';

  @override
  String get unitLitre => 'ליטר';

  @override
  String get unitMl => 'מ״ל';

  @override
  String get unitUnits => 'יחידות';

  @override
  String packageKg(String amount) {
    return '\u2068$amount\u2069 ק״ג';
  }

  @override
  String packageG(String amount) {
    return '\u2068$amount\u2069 גרם';
  }

  @override
  String packageLitreOne(String amount) {
    return '\u2068$amount\u2069 ליטר';
  }

  @override
  String packageLitres(String amount) {
    return '\u2068$amount\u2069 ליטר';
  }

  @override
  String packageMl(String amount) {
    return '\u2068$amount\u2069 מ״ל';
  }

  @override
  String packageUnitOne(String amount) {
    return '\u2068$amount\u2069 יחידה';
  }

  @override
  String packageUnits(String amount) {
    return '\u2068$amount\u2069 יחידות';
  }

  @override
  String unitPricePerKg(String price) {
    return '\u2068$price\u2069 לק״ג';
  }

  @override
  String unitPricePerLitre(String price) {
    return '\u2068$price\u2069 לליטר';
  }

  @override
  String unitPriceEach(String price) {
    return '\u2068$price\u2069 ליחידה';
  }

  @override
  String get expired => 'הסתיים';

  @override
  String get freeDelivery => 'משלוח חינם';

  @override
  String plusDelivery(String price) {
    return 'משלוח: \u2068$price\u2069';
  }

  @override
  String get dealTitle => 'מבצע';

  @override
  String get dealGoneTitle => 'המבצע הזה כבר לא קיים';

  @override
  String get dealGoneMessage => 'ייתכן שהוא הוסר מהחנות.';

  @override
  String get backToStore => 'חזרה לחנות';

  @override
  String youSave(String amount, int percent) {
    return 'חיסכון של \u2068$amount\u2069 ($percent%)';
  }

  @override
  String get unitPriceLabel => 'מחיר ליחידת מידה';

  @override
  String get packageLabel => 'אריזה';

  @override
  String get deliveryLabel => 'משלוח';

  @override
  String get deliveryFree => 'חינם';

  @override
  String deliveryPlus(String price) {
    return '+ \u2068$price\u2069';
  }

  @override
  String get deliveryNotGiven => 'לא צוין';

  @override
  String get deliveryAskSeller => 'כדאי לבדוק מול המוכר';

  @override
  String get finalPriceLabel => 'מחיר סופי';

  @override
  String get sellerLabel => 'מוכר';

  @override
  String get priceCheckedLabel => 'המחיר נבדק';

  @override
  String get postedLabel => 'פורסם';

  @override
  String get endsLabel => 'מסתיים';

  @override
  String get priceMayHaveChanged => 'המחיר נבדק לפני זמן מה, וייתכן שהשתנה.';

  @override
  String dealEndedOn(String date) {
    return 'המבצע הסתיים בתאריך \u2068$date\u2069';
  }

  @override
  String get pickOfTheApp => 'בחירת Pet Companion';

  @override
  String get sharedByYou => 'מבצע ששיתפת';

  @override
  String get sharedByMember => 'שיתוף מהקהילה';

  @override
  String sharedBy(String name) {
    return 'שיתוף של \u2068$name\u2069';
  }

  @override
  String get reportExpired => 'דיווח שהמבצע הסתיים';

  @override
  String get reportedExpired => 'דיווחת שהמבצע הסתיים';

  @override
  String get reportThanks => 'תודה, נבדוק את זה.';

  @override
  String get deleteMyDeal => 'מחיקת המבצע שלי';

  @override
  String get deleteDealTitle => 'למחוק את המבצע?';

  @override
  String get deleteDealMessage => 'המבצע יוסר מהחנות עבור כולם.';

  @override
  String get dealDeleted => 'המבצע שלך נמחק.';

  @override
  String get openOffer => 'מעבר למבצע באתר המוכר';

  @override
  String opensInBrowser(String host) {
    return '\u2068$host\u2069 ייפתח בדפדפן שלך';
  }

  @override
  String get couldNotOpenOffer => 'לא הצלחנו לפתוח את המבצע. אפשר לנסות שוב.';

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
  String get timeYesterday => 'אתמול';

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
  String get noEndDate => 'ללא תאריך סיום';

  @override
  String endedOn(String date) {
    return 'הסתיים בתאריך \u2068$date\u2069';
  }

  @override
  String endsOn(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'נותרו $days ימים',
      two: 'נותרו יומיים',
      one: 'נותר יום אחד',
      zero: 'מסתיים היום',
    );
    return '\u2068$date\u2069 · $_temp0';
  }

  @override
  String checkedOn(String date, String when) {
    return '\u2068$date\u2069 · \u2068$when\u2069';
  }

  @override
  String get checkedToday => 'היום';

  @override
  String get checkedYesterday => 'אתמול';

  @override
  String checkedDaysAgo(int days) {
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
  String get saveDeal => 'שמירת המבצע';

  @override
  String get removeFromSaved => 'הסרה מהשמורים';

  @override
  String get savedConfirmation => 'נשמר';

  @override
  String get removedFromSaved => 'הוסר מהמבצעים ששמרת';

  @override
  String get couldNotUpdateSaved => 'לא הצלחנו לעדכן את המבצעים ששמרת. אפשר לנסות שוב.';

  @override
  String get couldNotLoadSaved => 'לא הצלחנו לטעון את המבצעים ששמרת';

  @override
  String get noSavedDealsTitle => 'עדיין לא שמרת מבצעים';

  @override
  String get noSavedDealsMessage => 'לחיצה על הלב שעל מבצע שומרת אותו כאן.';

  @override
  String get browseDeals => 'לכל המבצעים';

  @override
  String savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מבצעים שמורים',
      two: 'שני מבצעים שמורים',
      one: 'מבצע שמור אחד',
    );
    return '$_temp0';
  }

  @override
  String get shareIntro => 'מצאת מבצע טוב? כדאי לספר לבעלי חיות אחרים איפה הוא.';

  @override
  String get fieldTitle => 'כותרת';

  @override
  String get fieldTitleHint => 'מה במבצע?';

  @override
  String get fieldCategory => 'קטגוריה';

  @override
  String get fieldCategoryHint => 'בחירת קטגוריה';

  @override
  String get fieldAnimals => 'לאילו חיות';

  @override
  String get fieldAnimalsHelp => 'הבחירה מתחילה מסוג החיה שנבחרה. אפשר לסמן יותר מסוג אחד.';

  @override
  String fieldPriceNow(String symbol) {
    return 'המחיר עכשיו (\u2068$symbol\u2069)';
  }

  @override
  String fieldPriceBefore(String symbol) {
    return 'המחיר הקודם (\u2068$symbol\u2069)';
  }

  @override
  String hintPercentOff(int percent) {
    return 'זו הנחה של $percent%';
  }

  @override
  String get fieldPackageSize => 'גודל האריזה (לא חובה)';

  @override
  String get fieldPackageAmountHint => 'כמות';

  @override
  String get fieldPackageUnitHint => 'יחידת מידה';

  @override
  String get fieldPackageHelp => 'במארז של כמה יחידות מזינים את הסך הכול. לדוגמה: 12 × 85 גרם הם 1020 גרם.';

  @override
  String hintUnitPrice(String unitPrice) {
    return 'כלומר \u2068$unitPrice\u2069';
  }

  @override
  String get fieldDelivery => 'משלוח (לא חובה)';

  @override
  String get deliveryNotSure => 'לא ידוע';

  @override
  String get deliveryPaid => 'בתשלום';

  @override
  String fieldDeliveryCost(String symbol) {
    return 'עלות המשלוח (\u2068$symbol\u2069)';
  }

  @override
  String hintFinalPrice(String price) {
    return 'מחיר סופי: \u2068$price\u2069';
  }

  @override
  String get fieldSellerHint => 'החנות או האתר';

  @override
  String get fieldLink => 'קישור למבצע';

  @override
  String get fieldDescription => 'תיאור (לא חובה)';

  @override
  String get fieldDescriptionHint => 'גודל, טעם, מה כלול...';

  @override
  String get fieldEndDate => 'תאריך סיום (לא חובה)';

  @override
  String get addEndDate => 'הוספת תאריך סיום';

  @override
  String endsDate(String date) {
    return 'מסתיים בתאריך \u2068$date\u2069';
  }

  @override
  String get removeEndDate => 'הסרת תאריך הסיום';

  @override
  String get lastDayOfDeal => 'היום האחרון של המבצע';

  @override
  String checkedTodayNote(String date) {
    return 'המחיר יוצג כמחיר שנבדק היום, \u2068$date\u2069.';
  }

  @override
  String get shareDealButton => 'שיתוף המבצע';

  @override
  String get validTitleRequired => 'צריך לתת למבצע כותרת.';

  @override
  String validTitleTooShort(int count) {
    return 'צריך לפחות $count תווים.';
  }

  @override
  String get validSellerRequired => 'מי המוכר?';

  @override
  String get validCategoryRequired => 'צריך לבחור קטגוריה.';

  @override
  String get validOriginalPriceRequired => 'צריך להזין את המחיר שלפני ההנחה.';

  @override
  String get validPriceRequired => 'צריך להזין את המחיר עכשיו.';

  @override
  String get validNotANumber => 'צריך להזין מספר, למשל 49.90.';

  @override
  String get validPriceAboveZero => 'המחיר צריך להיות גדול מאפס.';

  @override
  String get validPriceBelowOriginal => 'מחיר המבצע צריך להיות נמוך מהמחיר הקודם.';

  @override
  String get validLinkRequired => 'צריך להדביק את הקישור למבצע.';

  @override
  String validLinkNotHttps(String prefix) {
    return 'צריך קישור מלא שמתחיל ב־\u2068$prefix\u2069';
  }

  @override
  String get validPackageAmount => 'צריך להזין גודל גדול מאפס, למשל 2.5.';

  @override
  String get validPackageUnit => 'צריך לבחור יחידת מידה: ק״ג, גרם, ליטר, מ״ל או יחידות.';

  @override
  String get validDeliveryCostRequired => 'צריך להזין את עלות המשלוח.';

  @override
  String get validDeliveryCostInvalid => 'צריך להזין מספר גדול מאפס, או לבחור ״חינם״.';

  @override
  String get errNetwork => 'אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get errSignInToShare => 'כדי לשתף מבצע צריך להיכנס לחשבון.';

  @override
  String get errSignInToDelete => 'כדי למחוק מבצע צריך להיכנס לחשבון.';

  @override
  String get errSignInToReport => 'כדי לדווח על מבצע צריך להיכנס לחשבון.';

  @override
  String get errNeedsTitleAndSeller => 'למבצע צריך כותרת ומוכר.';

  @override
  String errLinkMustBeHttps(String prefix) {
    return 'צריך קישור שמתחיל ב־\u2068$prefix\u2069';
  }

  @override
  String get errPackageNotValid => 'גודל האריזה צריך להיות גדול מאפס.';

  @override
  String get errDeliveryNotValid => 'עלות המשלוח לא יכולה להיות קטנה מאפס.';

  @override
  String get errOnlyDeleteOwn => 'אפשר למחוק רק מבצעים ששיתפת.';

  @override
  String get errNotAllowed => 'אין הרשאה לפעולה הזאת. כדאי להיכנס שוב לחשבון.';

  @override
  String get errDetailsNotValid => 'חלק מהפרטים לא תקינים. כדאי לבדוק אותם ולנסות שוב.';

  @override
  String get errDealNoLongerAvailable => 'המבצע הזה כבר לא זמין.';

  @override
  String get errSessionEnded => 'החיבור לחשבון הסתיים. צריך להיכנס שוב.';

  @override
  String get errStoreNeedsUpdate => 'החנות מתעדכנת כרגע. אפשר לנסות שוב מאוחר יותר.';
}
