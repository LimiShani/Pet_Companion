import 'safety_text.dart';

/// "Can they eat this?": foods, plants and a few things around the house,
/// with a three-level answer per animal. One short line each; no amounts
/// and no calculator: when in doubt, or for anything dangerous, the page
/// offers a call to the vet.
///
/// Dogs and cats first; birds where the sources say something clear, and
/// nothing for rabbits, reptiles and the rest (their owners are sent to the
/// vet). Names are searchable in English and Hebrew, with common other
/// names.
///
/// Shown only with the `safety.lists` capability (the Beta testers) until a
/// vet has reviewed this file. Sources:
const foodSafetySources = [
  SafetySource(
    'ASPCA Animal Poison Control: people foods to avoid feeding your pets',
    'https://www.aspca.org/pet-care/animal-poison-control/people-foods-avoid-feeding-your-pets',
  ),
  SafetySource(
    'ASPCA Animal Poison Control: toxic and non-toxic plants',
    'https://www.aspca.org/pet-care/animal-poison-control/toxic-and-non-toxic-plants',
  ),
  SafetySource(
    'Pet Poison Helpline: poisons',
    'https://www.petpoisonhelpline.com/poisons/',
  ),
  SafetySource(
    'MSD Veterinary Manual: poisoning (toxicology)',
    'https://www.msdvetmanual.com/',
  ),
];

/// How safe something is for one animal.
enum FoodLevel {
  /// Fine in a pet-sized portion, plain.
  safe,

  /// Only a little, now and then, or only some of it (see the line).
  aLittle,

  /// Keep away; if eaten, call the vet.
  dangerous,
}

enum FoodKind { food, plant, household }

/// One food, plant or household item.
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.kind,
    required this.en,
    required this.he,
    required this.dog,
    required this.cat,
    required this.line,
    this.bird,
  });

  /// Stable, for keys and tests.
  final String id;
  final FoodKind kind;

  /// English names: the first is shown, the rest are found by search.
  final List<String> en;

  /// Hebrew names, the same way.
  final List<String> he;

  final FoodLevel dog;
  final FoodLevel cat;

  /// `null`: the sources say nothing clear for birds.
  final FoodLevel? bird;

  /// One short line, for every animal it is listed for.
  final SafetyText line;

  /// The name to show in [languageCode].
  String name(String languageCode) => languageCode == 'he' ? he.first : en.first;

  /// The answer for [animal]; `null` when the list has none (ask the vet).
  FoodLevel? levelFor(SafetyAnimal animal) => switch (animal) {
    SafetyAnimal.dog => dog,
    SafetyAnimal.cat => cat,
    SafetyAnimal.bird => bird,
    SafetyAnimal.other => null,
  };

  /// The most careful answer of all the animals listed: what a search
  /// result shows before an animal is chosen.
  FoodLevel get worst => [dog, cat, ?bird].reduce((a, b) => a.index >= b.index ? a : b);
}

const _s = FoodLevel.safe;
const _l = FoodLevel.aLittle;
const _d = FoodLevel.dangerous;

/// Everything on the list, foods first, then plants, then the house.
const foodEntries = <FoodEntry>[
  // ---- Dangerous foods ------------------------------------------------------
  FoodEntry(
    id: 'chocolate', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Chocolate', 'cocoa', 'cacao', 'brownie', 'chocolate cake'],
    he: ['שוקולד', 'קקאו', 'שוקו', 'בראוניז', 'עוגת שוקולד'],
    line: SafetyText('Dark and baking chocolate are the worst; even milk chocolate can harm.',
        'מריר ושוקולד לאפייה הכי מסוכנים, אבל גם שוקולד חלב יכול להזיק.'),
  ),
  FoodEntry(
    id: 'grapes', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Grapes and raisins', 'grape', 'raisin', 'sultanas', 'currants'],
    he: ['ענבים וצימוקים', 'ענבים', 'צימוקים', 'ענב'],
    line: SafetyText('Can harm the kidneys, even a few. There is no safe amount.',
        'עלולים לפגוע בכליות, גם מעט. אין כמות בטוחה.'),
  ),
  FoodEntry(
    id: 'xylitol', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Xylitol', 'sugar-free gum', 'chewing gum', 'sugar free sweets', 'birch sugar'],
    he: ['קסיליטול', 'מסטיק', 'מסטיק ללא סוכר', 'ממתקים ללא סוכר', 'סוכר ליבנה'],
    line: SafetyText('A sweetener in sugar-free gum, sweets and some peanut butters. Very dangerous for dogs.',
        'ממתיק במסטיק, בממתקים ללא סוכר ובחלק מחמאות הבוטנים. מסוכן מאוד לכלבים.'),
  ),
  FoodEntry(
    id: 'onion', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Onion', 'onions', 'onion powder', 'spring onion'],
    he: ['בצל', 'בצלים', 'אבקת בצל', 'בצל ירוק'],
    line: SafetyText('Raw, cooked or powdered, it damages red blood cells. Cats are the most sensitive.',
        'חי, מבושל או כאבקה, פוגע בתאי הדם האדומים. חתולים הכי רגישים.'),
  ),
  FoodEntry(
    id: 'garlic', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Garlic', 'garlic powder', 'garlic bread'],
    he: ['שום', 'אבקת שום', 'לחם שום'],
    line: SafetyText('Like onion, and stronger. Watch for it in sauces and leftovers.',
        'כמו בצל, ואף חזק יותר. כדאי לשים לב לרטבים ולשאריות.'),
  ),
  FoodEntry(
    id: 'leek', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Leeks and chives', 'leek', 'chives', 'shallot'],
    he: ['כרישה ועירית', 'כרישה', 'עירית', 'שאלוט'],
    line: SafetyText('From the onion family: the same harm to the blood.',
        'ממשפחת הבצל: אותה פגיעה בדם.'),
  ),
  FoodEntry(
    id: 'macadamia', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Macadamia nuts', 'macadamia'],
    he: ['אגוזי מקדמיה', 'מקדמיה'],
    line: SafetyText('Weakness, shaking and fever in dogs. Keep them from cats too.',
        'חולשה, רעד וחום אצל כלבים. גם מחתולים כדאי להרחיק.'),
  ),
  FoodEntry(
    id: 'alcohol', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Alcohol', 'beer', 'wine', 'spirits', 'vodka', 'arak'],
    he: ['אלכוהול', 'בירה', 'יין', 'משקה חריף', 'וודקה', 'ערק'],
    line: SafetyText('A little goes a long way in a small body. Never on purpose.',
        'בגוף קטן גם מעט משפיע מאוד. אף פעם לא בכוונה.'),
  ),
  FoodEntry(
    id: 'dough', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Raw bread dough', 'dough', 'yeast dough', 'pizza dough'],
    he: ['בצק שמרים', 'בצק', 'בצק פיצה', 'בצק לחם'],
    line: SafetyText('It keeps rising in the stomach and makes alcohol.',
        'ממשיך לתפוח בקיבה ומייצר אלכוהול.'),
  ),
  FoodEntry(
    id: 'caffeine', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Coffee and caffeine', 'coffee', 'tea', 'energy drink', 'cola', 'coffee grounds'],
    he: ['קפה וקפאין', 'קפה', 'תה', 'משקה אנרגיה', 'קולה', 'שאריות קפה'],
    line: SafetyText('Coffee, grounds, tea bags, energy drinks and caffeine pills.',
        'קפה, שאריות קפה, שקיקי תה, משקאות אנרגיה וכדורי קפאין.'),
  ),
  FoodEntry(
    id: 'avocado', kind: FoodKind.food, dog: _l, cat: _l, bird: _d,
    en: ['Avocado', 'guacamole'],
    he: ['אבוקדו', 'גוואקמולי'],
    line: SafetyText('Dangerous for birds. For dogs and cats a little flesh at most; the stone can block the gut.',
        'מסוכן לציפורים. לכלבים ולחתולים לכל היותר מעט מהפרי; הגלעין עלול לחסום את המעי.'),
  ),
  FoodEntry(
    id: 'bones', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Cooked bones', 'chicken bones', 'bones', 'rib bones'],
    he: ['עצמות מבושלות', 'עצמות עוף', 'עצמות', 'צלעות'],
    line: SafetyText('Cooked bones splinter and can tear or block the gut.',
        'עצמות מבושלות נשברות לרסיסים ועלולות לפצוע או לחסום את המעי.'),
  ),
  FoodEntry(
    id: 'pits', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Fruit stones and apple seeds', 'peach stone', 'apricot pit', 'cherry pit', 'plum stone', 'apple core', 'pits'],
    he: ['גלעינים וחרצני תפוח', 'גלעין', 'גלעין אפרסק', 'גלעין משמש', 'גלעין דובדבן', 'חרצנים', 'ליבת תפוח'],
    line: SafetyText('They can block the gut, and some hold a poison that releases when chewed.',
        'עלולים לחסום את המעי, וחלקם מכילים רעל שמשתחרר בלעיסה.'),
  ),
  FoodEntry(
    id: 'nutmeg', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Nutmeg'],
    he: ['אגוז מוסקט', 'מוסקט'],
    line: SafetyText('Can cause shaking and a racing heart. Watch for it in baking.',
        'עלול לגרום לרעד ולדופק מהיר. כדאי לשים לב אליו במאפים.'),
  ),
  FoodEntry(
    id: 'mushrooms', kind: FoodKind.food, dog: _d, cat: _d, bird: _d,
    en: ['Wild mushrooms', 'mushroom', 'mushrooms', 'toadstool'],
    he: ['פטריות בר', 'פטרייה', 'פטריות'],
    line: SafetyText('Mushrooms found outside can be deadly. Plain shop mushrooms are a different story: ask the vet.',
        'פטריות שנמצאו בחוץ עלולות להיות קטלניות. פטריות מהסופר הן סיפור אחר: כדאי לשאול את הווטרינר.'),
  ),
  FoodEntry(
    id: 'hops', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Hops', 'home brewing'],
    he: ['כשות', 'בירה ביתית'],
    line: SafetyText('Used for home-brewed beer; can cause a dangerous fever.',
        'משמשת לבירה ביתית; עלולה לגרום לחום גוף מסוכן.'),
  ),
  FoodEntry(
    id: 'corncob', kind: FoodKind.food, dog: _d, cat: _d,
    en: ['Corn on the cob', 'corn cob', 'cob'],
    he: ['קלח תירס', 'קלחי תירס'],
    line: SafetyText('The cob blocks the gut. Plain corn kernels are fine.',
        'הקלח חוסם את המעי. גרעיני תירס פשוטים בסדר.'),
  ),
  // ---- A little -------------------------------------------------------------
  FoodEntry(
    id: 'salt', kind: FoodKind.food, dog: _l, cat: _l, bird: _d,
    en: ['Salty snacks', 'salt', 'crisps', 'chips', 'pretzels', 'bamba'],
    he: ['חטיפים מלוחים', 'מלח', 'צ׳יפס', 'בייגלה', 'במבה', 'ביסלי'],
    line: SafetyText('A crumb is fine for dogs and cats; a lot of salt is not. Dangerous for birds.',
        'פירור לא יזיק לכלבים ולחתולים; הרבה מלח כן. מסוכן לציפורים.'),
  ),
  FoodEntry(
    id: 'fat', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Fatty food', 'fat trimmings', 'chicken skin', 'bacon', 'fried food'],
    he: ['אוכל שומני', 'שומן', 'עור עוף', 'בייקון', 'מטוגן'],
    line: SafetyText('Rich, fatty leftovers can bring on a painful pancreas. Only a taste.',
        'שאריות שמנות עלולות לגרום לדלקת כואבת בלבלב. רק טעימה.'),
  ),
  FoodEntry(
    id: 'milk', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Milk', 'cream', 'dairy'],
    he: ['חלב', 'שמנת', 'מוצרי חלב'],
    line: SafetyText('Many adult cats and dogs cannot digest it well: a lick, not a bowl.',
        'הרבה חתולים וכלבים בוגרים לא מעכלים אותו היטב: ליקוק, לא קערה.'),
  ),
  FoodEntry(
    id: 'cheese', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Cheese', 'yellow cheese', 'cottage cheese'],
    he: ['גבינה', 'גבינה צהובה', 'קוטג׳'],
    line: SafetyText('A small cube as a treat. Not blue or garlic cheeses.',
        'קובייה קטנה כפינוק. לא גבינות כחולות או עם שום.'),
  ),
  FoodEntry(
    id: 'yogurt', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Plain yogurt', 'yogurt', 'yoghurt', 'labneh'],
    he: ['יוגורט', 'יוגורט טבעי', 'לבנה'],
    line: SafetyText('Plain and unsweetened, a spoonful now and then.',
        'טבעי ובלי סוכר, כפית מדי פעם.'),
  ),
  FoodEntry(
    id: 'icecream', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Ice cream'],
    he: ['גלידה', 'ארטיק'],
    line: SafetyText('Sugar and milk: a lick at most, and never chocolate or sugar-free.',
        'סוכר וחלב: לכל היותר ליקוק, ואף פעם לא שוקולד או ללא סוכר.'),
  ),
  FoodEntry(
    id: 'peanutbutter', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Peanut butter', 'peanuts'],
    he: ['חמאת בוטנים', 'בוטנים'],
    line: SafetyText('Only one without xylitol, and only a little.',
        'רק בלי קסיליטול, ורק מעט.'),
  ),
  FoodEntry(
    id: 'nuts', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Almonds, walnuts and pistachios', 'nuts', 'almonds', 'walnuts', 'pistachios', 'cashews'],
    he: ['שקדים, אגוזי מלך ופיסטוקים', 'אגוזים', 'שקדים', 'אגוזי מלך', 'פיסטוקים', 'קשיו'],
    line: SafetyText('Fatty and easy to choke on. Mouldy walnuts are dangerous. Never macadamia.',
        'שמנים וקל להיחנק מהם. אגוזי מלך עובשים מסוכנים. אף פעם לא מקדמיה.'),
  ),
  FoodEntry(
    id: 'citrus', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Citrus fruit', 'orange', 'lemon', 'clementine', 'grapefruit', 'mandarin'],
    he: ['פרי הדר', 'תפוז', 'לימון', 'קלמנטינה', 'אשכולית', 'מנדרינה'],
    line: SafetyText('A segment of orange is fine for most dogs; peel, seeds and lemons upset the stomach.',
        'פלח תפוז בסדר לרוב הכלבים; קליפה, גרעינים ולימון מקלקלים את הבטן.'),
  ),
  FoodEntry(
    id: 'tomato', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Tomato', 'tomatoes', 'cherry tomato'],
    he: ['עגבנייה', 'עגבניות', 'עגבניות שרי'],
    line: SafetyText('A bit of ripe tomato is fine; leaves, stems and green tomatoes are not.',
        'מעט עגבנייה בשלה בסדר; עלים, גבעולים ועגבניות ירוקות לא.'),
  ),
  FoodEntry(
    id: 'potato', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Potato', 'potatoes', 'mashed potato', 'french fries'],
    he: ['תפוח אדמה', 'תפוחי אדמה', 'פירה', 'צ׳יפס מטוגן'],
    line: SafetyText('Plain and cooked, a little. Never raw, green or sprouting.',
        'מבושל ופשוט, מעט. אף פעם לא חי, ירוק או מנבט.'),
  ),
  FoodEntry(
    id: 'spicy', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Spicy food', 'chili', 'hot pepper', 'schug'],
    he: ['אוכל חריף', 'צ׳ילי', 'פלפל חריף', 'סחוג', 'חריף'],
    line: SafetyText('Upsets the stomach. Spiced leftovers often hide onion or garlic.',
        'מקלקל את הבטן. שאריות מתובלות מסתירות לא פעם בצל או שום.'),
  ),
  FoodEntry(
    id: 'tuna', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Canned tuna', 'tuna'],
    he: ['טונה', 'טונה בקופסה'],
    line: SafetyText('A treat now and then, in water, not oil. Not a cat\'s main food.',
        'פינוק מדי פעם, במים ולא בשמן. לא כמזון עיקרי לחתול.'),
  ),
  FoodEntry(
    id: 'popcorn', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Popcorn'],
    he: ['פופקורן'],
    line: SafetyText('Plain and popped only, no butter or salt; the hard kernels can choke.',
        'רק פשוט ומוכן, בלי חמאה ומלח; גרעינים קשים עלולים לחנוק.'),
  ),
  FoodEntry(
    id: 'bread', kind: FoodKind.food, dog: _l, cat: _l, bird: _l,
    en: ['Bread', 'pita', 'challah', 'toast'],
    he: ['לחם', 'פיתה', 'חלה', 'טוסט'],
    line: SafetyText('Plain baked bread is fine as a nibble; not with raisins, garlic or seeds.',
        'לחם אפוי ופשוט בסדר כנשנוש; לא עם צימוקים, שום או גרעינים.'),
  ),
  FoodEntry(
    id: 'broccoli', kind: FoodKind.food, dog: _l, cat: _l, bird: _s,
    en: ['Broccoli', 'cauliflower'],
    he: ['ברוקולי', 'כרובית'],
    line: SafetyText('Small pieces, now and then; a lot gives wind and a sore tummy.',
        'חתיכות קטנות מדי פעם; הרבה גורם לגזים ולכאבי בטן.'),
  ),
  FoodEntry(
    id: 'coconut', kind: FoodKind.food, dog: _l, cat: _l,
    en: ['Coconut', 'coconut milk'],
    he: ['קוקוס', 'חלב קוקוס'],
    line: SafetyText('A little flesh is fine; it is fatty. Not the hard shell.',
        'מעט מהפרי בסדר; הוא שומני. לא הקליפה הקשה.'),
  ),
  FoodEntry(
    id: 'sunflowerseeds', kind: FoodKind.food, dog: _l, cat: _l, bird: _s,
    en: ['Sunflower seeds', 'seeds', 'garinim'],
    he: ['גרעינים', 'גרעיני חמנייה', 'גרעינים שחורים'],
    line: SafetyText('Shelled and unsalted, a few. The shells and salted seeds upset the gut.',
        'קלופים ובלי מלח, מעט. הקליפות וגרעינים מלוחים מקלקלים את הבטן.'),
  ),
  // ---- Safe foods -----------------------------------------------------------
  FoodEntry(
    id: 'carrot', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Carrot', 'carrots'],
    he: ['גזר'],
    line: SafetyText('Raw or cooked, in pieces small enough to chew.',
        'חי או מבושל, בחתיכות קטנות שקל ללעוס.'),
  ),
  FoodEntry(
    id: 'apple', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Apple', 'apples'],
    he: ['תפוח', 'תפוחים', 'תפוח עץ'],
    line: SafetyText('Slices without the core and seeds.',
        'פרוסות בלי הליבה והחרצנים.'),
  ),
  FoodEntry(
    id: 'banana', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Banana', 'bananas'],
    he: ['בננה', 'בננות'],
    line: SafetyText('A few slices as a treat; it is sweet.',
        'כמה פרוסות כפינוק; היא מתוקה.'),
  ),
  FoodEntry(
    id: 'blueberries', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Blueberries', 'blueberry', 'berries'],
    he: ['אוכמניות', 'פירות יער'],
    line: SafetyText('A handful for a dog, a few for a cat.',
        'חופן לכלב, כמה בודדות לחתול.'),
  ),
  FoodEntry(
    id: 'strawberries', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Strawberries', 'strawberry'],
    he: ['תותים', 'תות'],
    line: SafetyText('Washed, in small pieces.',
        'שטופים, בחתיכות קטנות.'),
  ),
  FoodEntry(
    id: 'watermelon', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Watermelon', 'melon'],
    he: ['אבטיח', 'מלון'],
    line: SafetyText('The flesh, without the seeds and the rind.',
        'הפרי עצמו, בלי הגרעינים והקליפה.'),
  ),
  FoodEntry(
    id: 'pear', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Pear', 'pears'],
    he: ['אגס', 'אגסים'],
    line: SafetyText('Slices without the core and seeds.',
        'פרוסות בלי הליבה והחרצנים.'),
  ),
  FoodEntry(
    id: 'mango', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Mango'],
    he: ['מנגו'],
    line: SafetyText('The flesh only: no stone, no skin.',
        'רק הפרי: בלי גלעין ובלי קליפה.'),
  ),
  FoodEntry(
    id: 'cucumber', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Cucumber', 'cucumbers'],
    he: ['מלפפון', 'מלפפונים'],
    line: SafetyText('Crunchy and mostly water; plain, not pickled.',
        'פריך וכמעט כולו מים; טרי, לא חמוץ.'),
  ),
  FoodEntry(
    id: 'greenbeans', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Green beans', 'string beans'],
    he: ['שעועית ירוקה'],
    line: SafetyText('Plain, raw or cooked, with no salt or oil.',
        'פשוטה, חיה או מבושלת, בלי מלח ושמן.'),
  ),
  FoodEntry(
    id: 'peas', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Peas', 'green peas'],
    he: ['אפונה'],
    line: SafetyText('Fresh or frozen, plain; not from a salty can.',
        'טרייה או קפואה, פשוטה; לא מקופסה מלוחה.'),
  ),
  FoodEntry(
    id: 'pumpkin', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Pumpkin', 'squash'],
    he: ['דלעת', 'דלורית'],
    line: SafetyText('Plain cooked pumpkin, not pie filling with spices.',
        'דלעת מבושלת ופשוטה, לא מילוי מתובל לפאי.'),
  ),
  FoodEntry(
    id: 'sweetpotato', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Sweet potato'],
    he: ['בטטה'],
    line: SafetyText('Cooked and plain, never raw.',
        'מבושלת ופשוטה, אף פעם לא חיה.'),
  ),
  FoodEntry(
    id: 'rice', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Plain rice', 'rice', 'white rice'],
    he: ['אורז', 'אורז לבן'],
    line: SafetyText('Plain cooked rice, with nothing added.',
        'אורז מבושל ופשוט, בלי תוספות.'),
  ),
  FoodEntry(
    id: 'oats', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Oats', 'oatmeal', 'porridge'],
    he: ['שיבולת שועל', 'דייסת קוואקר', 'קוואקר'],
    line: SafetyText('Cooked in water, plain, no sugar or raisins.',
        'מבושלת במים, פשוטה, בלי סוכר וצימוקים.'),
  ),
  FoodEntry(
    id: 'chicken', kind: FoodKind.food, dog: _s, cat: _s,
    en: ['Cooked chicken', 'chicken', 'turkey'],
    he: ['עוף מבושל', 'עוף', 'הודו', 'חזה עוף'],
    line: SafetyText('Plain and boneless, without skin or seasoning.',
        'פשוט ובלי עצמות, בלי עור ותיבול.'),
  ),
  FoodEntry(
    id: 'egg', kind: FoodKind.food, dog: _s, cat: _s, bird: _s,
    en: ['Cooked egg', 'egg', 'eggs', 'boiled egg', 'scrambled egg'],
    he: ['ביצה מבושלת', 'ביצה', 'ביצים', 'ביצה קשה', 'חביתה'],
    line: SafetyText('Fully cooked, with no salt or butter.',
        'מבושלת היטב, בלי מלח וחמאה.'),
  ),
  FoodEntry(
    id: 'fish', kind: FoodKind.food, dog: _s, cat: _s,
    en: ['Cooked fish', 'fish', 'salmon'],
    he: ['דג מבושל', 'דג', 'דגים', 'סלמון'],
    line: SafetyText('Cooked, plain and without bones.',
        'מבושל, פשוט ובלי עצמות.'),
  ),
  // ---- Plants ---------------------------------------------------------------
  FoodEntry(
    id: 'lily', kind: FoodKind.plant, dog: _l, cat: _d,
    en: ['Lilies', 'lily', 'easter lily', 'tiger lily', 'day lily', 'stargazer'],
    he: ['שושן', 'ליליום', 'שושנים', 'שושן צחור', 'המרוקליס'],
    line: SafetyText('Deadly for cats: the petals, leaves, pollen and the vase water. Upsets a dog\'s stomach.',
        'קטלני לחתולים: עלי הכותרת, העלים, האבקה ומי האגרטל. אצל כלבים מקלקל את הבטן.'),
  ),
  FoodEntry(
    id: 'lilyofthevalley', kind: FoodKind.plant, dog: _d, cat: _d, bird: _d,
    en: ['Lily of the valley'],
    he: ['שונית', 'שושנת העמקים'],
    line: SafetyText('Affects the heart, in every animal.',
        'משפיע על הלב, אצל כל החיות.'),
  ),
  FoodEntry(
    id: 'oleander', kind: FoodKind.plant, dog: _d, cat: _d, bird: _d,
    en: ['Oleander', 'nerium'],
    he: ['הרדוף', 'הרדוף הנחלים'],
    line: SafetyText('Common in streets and gardens; every part affects the heart.',
        'נפוץ ברחובות ובגינות; כל חלקיו משפיעים על הלב.'),
  ),
  FoodEntry(
    id: 'sago', kind: FoodKind.plant, dog: _d, cat: _d, bird: _d,
    en: ['Sago palm', 'cycas', 'cycad'],
    he: ['ציקס', 'דקל סאגו'],
    line: SafetyText('Above all the seeds: severe liver damage.',
        'בעיקר הזרעים: פגיעה קשה בכבד.'),
  ),
  FoodEntry(
    id: 'castor', kind: FoodKind.plant, dog: _d, cat: _d, bird: _d,
    en: ['Castor bean plant', 'castor', 'ricinus'],
    he: ['קיקיון', 'קיקיון מצוי'],
    line: SafetyText('Grows wild by roads and streams; the seeds are very poisonous.',
        'גדל בר לצד דרכים ונחלים; הזרעים רעילים מאוד.'),
  ),
  FoodEntry(
    id: 'lantana', kind: FoodKind.plant, dog: _d, cat: _d,
    en: ['Lantana'],
    he: ['לנטנה'],
    line: SafetyText('A garden shrub; the berries above all harm the liver.',
        'שיח גינה; בעיקר הפירות פוגעים בכבד.'),
  ),
  FoodEntry(
    id: 'azalea', kind: FoodKind.plant, dog: _d, cat: _d, bird: _d,
    en: ['Azalea', 'rhododendron'],
    he: ['אזליאה', 'רודודנדרון'],
    line: SafetyText('A few leaves can cause vomiting and heart trouble.',
        'כמה עלים עלולים לגרום להקאות ולבעיות לב.'),
  ),
  FoodEntry(
    id: 'bulbs', kind: FoodKind.plant, dog: _d, cat: _d,
    en: ['Tulip and daffodil bulbs', 'tulip', 'daffodil', 'narcissus', 'hyacinth'],
    he: ['פקעות צבעונים ונרקיסים', 'צבעוני', 'טוליפ', 'נרקיס', 'יקינטון'],
    line: SafetyText('The bulbs are the worst part: watch dogs that dig.',
        'הפקעות הן החלק המסוכן ביותר: כדאי לשים לב לכלבים שחופרים.'),
  ),
  FoodEntry(
    id: 'cyclamen', kind: FoodKind.plant, dog: _d, cat: _d,
    en: ['Cyclamen'],
    he: ['רקפת'],
    line: SafetyText('The round root below the soil is the dangerous part.',
        'הפקעת העגולה שמתחת לאדמה היא החלק המסוכן.'),
  ),
  FoodEntry(
    id: 'aloe', kind: FoodKind.plant, dog: _l, cat: _l,
    en: ['Aloe vera', 'aloe'],
    he: ['אלוורה', 'אלוי'],
    line: SafetyText('The gel is mild; the outer leaf brings vomiting and diarrhoea.',
        'הג׳ל עדין; העלה החיצוני גורם להקאות ולשלשול.'),
  ),
  FoodEntry(
    id: 'pothos', kind: FoodKind.plant, dog: _l, cat: _l, bird: _l,
    en: ['Pothos', 'devil\'s ivy', 'epipremnum'],
    he: ['פוטוס', 'אפיפרמנום'],
    line: SafetyText('Burns the mouth and causes drooling; rarely more.',
        'צורב בפה וגורם לריור; לעיתים רחוקות יותר מזה.'),
  ),
  FoodEntry(
    id: 'monstera', kind: FoodKind.plant, dog: _l, cat: _l, bird: _l,
    en: ['Monstera and philodendron', 'monstera', 'philodendron', 'dieffenbachia'],
    he: ['מונסטרה ופילודנדרון', 'מונסטרה', 'פילודנדרון', 'דיפנבכיה'],
    line: SafetyText('Chewing them burns the mouth and throat: drooling and pawing at the mouth.',
        'לעיסה צורבת בפה ובגרון: ריור ושפשוף הפה בכפה.'),
  ),
  FoodEntry(
    id: 'ivy', kind: FoodKind.plant, dog: _l, cat: _l,
    en: ['Ivy', 'english ivy', 'hedera'],
    he: ['קיסוס', 'קיסוס החורש'],
    line: SafetyText('The leaves upset the stomach and the mouth.',
        'העלים מקלקלים את הבטן ומגרים את הפה.'),
  ),
  FoodEntry(
    id: 'poinsettia', kind: FoodKind.plant, dog: _l, cat: _l,
    en: ['Poinsettia'],
    he: ['פוינסטיה', 'חלבלוב הנאה'],
    line: SafetyText('Its milky sap irritates the mouth and stomach; usually mild.',
        'המוהל הלבן מגרה את הפה והבטן; לרוב קל.'),
  ),
  FoodEntry(
    id: 'snakeplant', kind: FoodKind.plant, dog: _l, cat: _l,
    en: ['Snake plant', 'sansevieria', 'mother-in-law\'s tongue'],
    he: ['סנסיווריה', 'לשון חמותי'],
    line: SafetyText('Can bring on vomiting and drooling if chewed.',
        'עלולה לגרום להקאות ולריור כשלועסים אותה.'),
  ),
  FoodEntry(
    id: 'jade', kind: FoodKind.plant, dog: _l, cat: _l,
    en: ['Jade plant', 'crassula', 'money plant'],
    he: ['קרסולה', 'עץ הכסף'],
    line: SafetyText('Vomiting and a slow, tired pet after a nibble.',
        'הקאות ועייפות אחרי נגיסה.'),
  ),
  FoodEntry(
    id: 'geranium', kind: FoodKind.plant, dog: _l, cat: _l,
    en: ['Geranium', 'pelargonium'],
    he: ['גרניום', 'פלרגוניום'],
    line: SafetyText('Mild: vomiting or a rash, more in cats.',
        'קל: הקאה או פריחה, יותר אצל חתולים.'),
  ),
  FoodEntry(
    id: 'grass', kind: FoodKind.plant, dog: _s, cat: _s, bird: _s,
    en: ['Grass', 'cat grass', 'wheatgrass'],
    he: ['דשא', 'עשב לחתולים', 'עשב חיטה'],
    line: SafetyText('Fine to nibble, if no weed killer or fertiliser was sprayed.',
        'בסדר לנשנש, אם לא רוססו קוטלי עשבים או דשן.'),
  ),
  FoodEntry(
    id: 'catnip', kind: FoodKind.plant, dog: _s, cat: _s,
    en: ['Catnip', 'catmint'],
    he: ['נפית', 'נפית החתולים', 'קטניפ'],
    line: SafetyText('Safe; some cats get playful, a lot can upset the stomach.',
        'בטוחה; חלק מהחתולים נהיים שובבים, הרבה עלול לקלקל את הבטן.'),
  ),
  FoodEntry(
    id: 'spiderplant', kind: FoodKind.plant, dog: _s, cat: _s, bird: _s,
    en: ['Spider plant', 'chlorophytum'],
    he: ['כלורופיטום', 'צמח העכביש'],
    line: SafetyText('Not toxic, though cats love to chew it.',
        'לא רעיל, גם אם חתולים אוהבים ללעוס אותו.'),
  ),
  FoodEntry(
    id: 'basil', kind: FoodKind.plant, dog: _s, cat: _s, bird: _s,
    en: ['Basil and rosemary', 'basil', 'rosemary'],
    he: ['בזיליקום ורוזמרין', 'בזיליקום', 'רוזמרין'],
    line: SafetyText('Garden herbs that are safe to sniff and nibble.',
        'צמחי תבלין שבטוח להריח ולנשנש.'),
  ),
  FoodEntry(
    id: 'rose', kind: FoodKind.plant, dog: _s, cat: _s, bird: _s,
    en: ['Roses', 'rose'],
    he: ['ורד', 'ורדים'],
    line: SafetyText('Not toxic; the thorns can scratch.',
        'לא רעיל; הקוצים עלולים לשרוט.'),
  ),
  FoodEntry(
    id: 'orchid', kind: FoodKind.plant, dog: _s, cat: _s, bird: _s,
    en: ['Orchid', 'phalaenopsis'],
    he: ['סחלב', 'פלנופסיס'],
    line: SafetyText('Not toxic. Mind the pot\'s bark and plant food.',
        'לא רעיל. כדאי להיזהר מהקליפות בעציץ ומהדשן.'),
  ),
  FoodEntry(
    id: 'sunflower', kind: FoodKind.plant, dog: _s, cat: _s, bird: _s,
    en: ['Sunflower'],
    he: ['חמנייה', 'חמניות'],
    line: SafetyText('The plant is not toxic.',
        'הצמח לא רעיל.'),
  ),
  // ---- Around the house -----------------------------------------------------
  FoodEntry(
    id: 'medicines', kind: FoodKind.household, dog: _d, cat: _d, bird: _d,
    en: ['Human medicines', 'ibuprofen', 'paracetamol', 'acamol', 'advil', 'painkillers', 'pills'],
    he: ['תרופות של בני אדם', 'איבופרופן', 'פרצטמול', 'אקמול', 'אדויל', 'משככי כאבים', 'כדורים'],
    line: SafetyText('Never give your own medicine. Paracetamol is deadly for cats.',
        'אף פעם לא לתת תרופות של בני אדם. פרצטמול קטלני לחתולים.'),
  ),
  FoodEntry(
    id: 'ratpoison', kind: FoodKind.household, dog: _d, cat: _d, bird: _d,
    en: ['Rat and mouse poison', 'rat poison', 'rodenticide', 'bait'],
    he: ['רעל עכברים', 'רעל מכרסמים', 'פיתיון', 'רעל'],
    line: SafetyText('Go to the vet even with no signs; bring the pack if you can.',
        'לנסוע לווטרינר גם בלי סימנים; אם אפשר, להביא את האריזה.'),
  ),
  FoodEntry(
    id: 'antifreeze', kind: FoodKind.household, dog: _d, cat: _d, bird: _d,
    en: ['Antifreeze', 'coolant'],
    he: ['נוזל קירור', 'אנטיפריז'],
    line: SafetyText('Sweet-tasting and deadly; a small lick is an emergency.',
        'מתוק בטעם וקטלני; גם ליקוק קטן הוא מצב חירום.'),
  ),
  FoodEntry(
    id: 'nicotine', kind: FoodKind.household, dog: _d, cat: _d, bird: _d,
    en: ['Cigarettes and nicotine', 'cigarette', 'tobacco', 'vape', 'nicotine gum'],
    he: ['סיגריות וניקוטין', 'סיגריה', 'טבק', 'סיגריה אלקטרונית', 'ניקוטין'],
    line: SafetyText('Butts, refills and nicotine gum all count.',
        'גם בדלים, מילויים ומסטיק ניקוטין.'),
  ),
  FoodEntry(
    id: 'cannabis', kind: FoodKind.household, dog: _d, cat: _d, bird: _d,
    en: ['Cannabis', 'marijuana', 'weed', 'edibles'],
    he: ['קנאביס', 'מריחואנה', 'גראס', 'עוגיות קנאביס'],
    line: SafetyText('Wobbling, dribbling urine, a slow heart; edibles add chocolate.',
        'חוסר יציבות, טפטוף שתן, דופק איטי; במאפים יש גם שוקולד.'),
  ),
  FoodEntry(
    id: 'essentialoils', kind: FoodKind.household, dog: _l, cat: _d, bird: _d,
    en: ['Essential oils', 'tea tree oil', 'diffuser', 'eucalyptus oil'],
    he: ['שמנים אתריים', 'שמן עץ התה', 'מפזר ריח', 'שמן אקליפטוס'],
    line: SafetyText('Dangerous for cats and birds, even through the skin or the air. Keep them away from dogs too.',
        'מסוכנים לחתולים ולציפורים, גם דרך העור או האוויר. כדאי להרחיק גם מכלבים.'),
  ),
];

/// [foodEntries] whose names match [query] in either language, the best
/// matches first: a name that is the query, then one that starts with it,
/// then one with a word that starts with it, then one that holds it. An
/// empty query gives every entry in [languageCode]'s alphabetical order.
List<FoodEntry> searchFoods(String query, {String languageCode = 'en'}) {
  final q = normalizeSafetySearch(query);
  if (q.isEmpty) {
    final all = [...foodEntries]
      ..sort((a, b) => a.name(languageCode).compareTo(b.name(languageCode)));
    return all;
  }
  int? rank(FoodEntry entry) {
    int? best;
    for (final name in [...entry.en, ...entry.he]) {
      final n = normalizeSafetySearch(name);
      final r = n == q
          ? 0
          : n.startsWith(q)
          ? 1
          : n.split(' ').any((w) => w.startsWith(q))
          ? 2
          : n.contains(q)
          ? 3
          : null;
      if (r != null && (best == null || r < best)) best = r;
    }
    return best;
  }

  final found = <(FoodEntry, int)>[
    for (final entry in foodEntries)
      if (rank(entry) case final r?) (entry, r),
  ];
  // Stable: equal ranks keep the list's order (the dangerous ones first).
  final ordered = [
    for (var r = 0; r <= 3; r++)
      for (final (entry, rr) in found)
        if (rr == r) entry,
  ];
  return ordered;
}
