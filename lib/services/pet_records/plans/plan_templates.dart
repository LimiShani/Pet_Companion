/// The yearly plan of vaccines and treatments for dogs and cats in Israel:
/// a common plan, written as data. The owner picks items from it, and the
/// app creates planned health records from what they pick
/// (`plan_logic.dart`); the vet's word always comes first.
///
/// CONTENT FOR A VET TO REVIEW. Every item lists the sources it follows.
/// The capability `health.plans.view` (migration 0038) shows the plan to
/// the beta testers only, and stays there until a vet has reviewed this
/// file. The wording is careful on purpose: "a common plan; your vet may
/// suggest another", never a diagnosis, never a dose or a brand.
library;

import '../../../models/pet.dart';
import '../data/health_models.dart';

/// Where an item's advice comes from. [url] is left out where there is no
/// stable public page to point at.
class PlanSource {
  const PlanSource(this.title, [this.url]);

  final String title;
  final String? url;
}

/// A text in both of the app's languages. Plan content is data, not UI
/// strings, so it lives here with its sources rather than in an ARB file.
class PlanText {
  const PlanText(this.en, this.he);

  final String en;
  final String he;

  String of({required bool hebrew}) => hebrew ? he : en;
}

/// How long until an item is due again: [months] calendar months, or
/// [weeks] weeks.
class PlanInterval {
  const PlanInterval.months(this.months) : weeks = 0;
  const PlanInterval.weeks(this.weeks) : months = 0;

  final int months;
  final int weeks;

  /// The day this long after [day].
  DateTime after(DateTime day) =>
      months > 0 ? addMonths(day, months) : addDays(day, weeks * 7);

  @override
  bool operator ==(Object other) =>
      other is PlanInterval && other.months == months && other.weeks == weeks;

  @override
  int get hashCode => Object.hash(months, weeks);
}

/// [day] plus [months] calendar months, on the same day of the month or on
/// the month's last day (31 January + 1 month = 28 or 29 February).
DateTime addMonths(DateTime day, int months) {
  final first = DateTime(day.year, day.month + months);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, day.day > last ? last : day.day);
}

/// A shorter interval while the animal is young: until it is [untilWeeks]
/// weeks old, the item repeats every [interval].
class YoungInterval {
  const YoungInterval(this.untilWeeks, this.interval);

  final int untilWeeks;
  final PlanInterval interval;
}

/// The first vaccines of a puppy or a kitten: one dose at each age in
/// [ageWeeks], at least [minGapWeeks] apart, then the item's yearly
/// booster.
class PlanSeries {
  const PlanSeries(this.ageWeeks, {this.minGapWeeks = 3});

  final List<int> ageWeeks;
  final int minGapWeeks;

  int get count => ageWeeks.length;

  /// Past this age, an animal with no dose on record is not "in the
  /// series" any more: it gets one dose and then the yearly one.
  int get endsAtWeeks => ageWeeks.last + 4;
}

/// How strongly the plan holds an item.
enum PlanStanding {
  /// Required by Israeli law (rabies for dogs).
  requiredByLaw,

  /// What vets in Israel commonly give.
  common,

  /// Not required, but recommended (rabies for cats).
  recommended,
}

/// One item of a plan: what it is, how often, from what age, why, and
/// where that comes from.
class PlanTemplateItem {
  const PlanTemplateItem({
    required this.species,
    required this.id,
    required this.kind,
    required this.title,
    required this.why,
    required this.interval,
    required this.startAgeWeeks,
    required this.matchWords,
    required this.sources,
    this.standing = PlanStanding.common,
    this.series,
    this.seriesTitle,
    this.youngIntervals = const [],
    this.monthChoices = const [],
  });

  final PetSpecies species;

  /// Unique within the species: `rabies`, `combined`, ...
  final String id;

  /// [RecordKind.vaccination] or [RecordKind.preventive].
  final RecordKind kind;
  final PlanText title;

  /// One line on why it is in the plan.
  final PlanText why;

  /// How often for an adult (after the series, for a vaccine with one).
  final PlanInterval interval;

  /// The age it starts at.
  final int startAgeWeeks;

  /// Lower-case words that, in a record's title or product, mean this
  /// item: how the plan finds what was already done or planned.
  final List<String> matchWords;
  final List<PlanSource> sources;
  final PlanStanding standing;

  /// The puppy or kitten series, for a vaccine that has one.
  final PlanSeries? series;

  /// The title of one dose of [series]: `{n}` is the dose, `{count}` the
  /// number of doses.
  final PlanText? seriesTitle;

  /// Shorter intervals while young, youngest first.
  final List<YoungInterval> youngIntervals;

  /// When not empty, the owner picks the interval in months (it depends on
  /// the product); the first one is the default.
  final List<int> monthChoices;

  /// `dog.rabies`: what a planned record's `plan_item` starts with.
  String get key => '${species.name}.$id';

  /// The interval at an age of [ageWeeks] (`null`: unknown, an adult).
  PlanInterval intervalAt(int? ageWeeks, {int? months}) {
    if (months != null && months > 0) return PlanInterval.months(months);
    if (monthChoices.isNotEmpty) return PlanInterval.months(monthChoices.first);
    if (ageWeeks != null) {
      for (final young in youngIntervals) {
        if (ageWeeks < young.untilWeeks) return young.interval;
      }
    }
    return interval;
  }

  /// The title of a planned record: the item, or one dose of its series.
  String titleOf({required bool hebrew, int? dose}) {
    final s = series;
    final t = seriesTitle;
    if (dose == null || s == null || t == null) return title.of(hebrew: hebrew);
    return t
        .of(hebrew: hebrew)
        .replaceAll('{n}', '$dose')
        .replaceAll('{count}', '${s.count}');
  }

  /// Whether [record] is about this item: same kind, and a match word in
  /// its title or product, or made from this item of a plan.
  bool matches(HealthRecord record) {
    if (record.kind != kind) return false;
    final plan = record.planItem;
    if (plan != null) {
      return plan == key || plan.startsWith('$key#') || plan.startsWith('$key@');
    }
    final text = '${record.title} ${record.productName}'.toLowerCase();
    return matchWords.any(text.contains);
  }
}

// ---------------------------------------------------------------- sources

const _wsava = PlanSource(
  'WSAVA Guidelines for the vaccination of dogs and cats (2024)',
  'https://wsava.org/global-guidelines/vaccination-guidelines/',
);
const _israelRabies = PlanSource(
  'Israel Ministry of Agriculture, Veterinary Services: every dog from 3 '
  'months of age must be vaccinated against rabies once a year (the Rabies '
  'Ordinance and its regulations)',
);
const _israelRabiesCats = PlanSource(
  'Israel Ministry of Agriculture, Veterinary Services: rabies vaccination '
  'of cats is recommended (it is required by law for dogs)',
);
const _msdRabies = PlanSource(
  'MSD Veterinary Manual: Rabies',
  'https://www.msdvetmanual.com/',
);
const _esccapWorms = PlanSource(
  'ESCCAP Guideline 1: Worm control in dogs and cats',
  'https://www.esccap.org/guidelines/',
);
const _esccapEcto = PlanSource(
  'ESCCAP Guideline 3: Control of ectoparasites in dogs and cats',
  'https://www.esccap.org/guidelines/',
);
const _spirocercaIsrael = PlanSource(
  'Koret School of Veterinary Medicine, Hebrew University: Spirocerca lupi '
  '(the "park worm") in dogs in Israel and its prevention',
);
const _msdSpirocerca = PlanSource(
  'MSD Veterinary Manual: Spirocercosis in dogs',
  'https://www.msdvetmanual.com/',
);

// -------------------------------------------------------------- the words

const _rabiesWords = [
  'rabies',
  'כלבת',
  'rabisin',
  'rabivac',
  'nobivac rabies',
  'nobivac r',
];

const _dogCombinedWords = [
  'dhpp',
  'dhppi',
  'dappv',
  'משושה',
  'מחומש',
  'combined',
  'parvo',
  'פרבו',
  'distemper',
  'כלבלבת',
  'canigen',
  'eurican',
  'vanguard',
  'nobivac dhp',
];

const _catCombinedWords = [
  'fvrcp',
  'rcp',
  'משולש',
  'משולשת',
  'combined',
  'tricat',
  'felocell',
  'purevax',
  'feligen',
  'panleukopenia',
];

const _dewormWords = [
  'deworm',
  'de-worm',
  'worming',
  'wormer',
  'תילוע',
  'תולעים',
  'milbemax',
  'מילבמקס',
  'drontal',
  'דרונטל',
  'profender',
  'פרופנדר',
];

const _spirocercaWords = [
  'spirocerca',
  'ספירוצרקה',
  'תולעת הפארק',
  'park worm',
  'dectomax',
  'דקטומקס',
  'doramectin',
];

const _fleaWords = [
  'flea',
  'tick',
  'פרעוש',
  'קרצי',
  'bravecto',
  'ברבקטו',
  'nexgard',
  'נקסגארד',
  'simparica',
  'סימפריקה',
  'frontline',
  'פרונטליין',
  'advantix',
  'advocate',
  'seresto',
  'סרסטו',
  'revolution',
];

const _youngWorming = [
  YoungInterval(12, PlanInterval.weeks(2)),
  YoungInterval(26, PlanInterval.months(1)),
];

// --------------------------------------------------------------- the plans

/// The dog's plan, in the order it is shown.
const dogPlan = <PlanTemplateItem>[
  PlanTemplateItem(
    species: PetSpecies.dog,
    id: 'rabies',
    kind: RecordKind.vaccination,
    standing: PlanStanding.requiredByLaw,
    title: PlanText('Rabies vaccine', 'חיסון כלבת'),
    why: PlanText(
      'Required by law in Israel for every dog from 3 months old, once a year.',
      'חובה לפי החוק בישראל לכל כלב מגיל 3 חודשים, פעם בשנה.',
    ),
    interval: PlanInterval.months(12),
    startAgeWeeks: 12,
    matchWords: _rabiesWords,
    sources: [_israelRabies, _wsava, _msdRabies],
  ),
  PlanTemplateItem(
    species: PetSpecies.dog,
    id: 'combined',
    kind: RecordKind.vaccination,
    title: PlanText('Combined vaccine (DHPPi+L)', 'חיסון משושה'),
    seriesTitle: PlanText(
      'Combined vaccine, puppy dose {n} of {count}',
      'חיסון משושה, מנת גור {n} מתוך {count}',
    ),
    why: PlanText(
      'Protects against parvo, distemper, hepatitis and leptospirosis. '
          'Puppies get a short series first.',
      'מגן מפני פרבו, כלבלבת, דלקת כבד ולפטוספירוזיס. גורים מקבלים קודם סדרה קצרה.',
    ),
    // 6-8, 10-12 and 14-16 weeks, as WSAVA describes; then once a year,
    // as is usual in Israel for the vaccine with leptospirosis.
    series: PlanSeries([8, 12, 16]),
    interval: PlanInterval.months(12),
    startAgeWeeks: 6,
    matchWords: _dogCombinedWords,
    sources: [_wsava],
  ),
  PlanTemplateItem(
    species: PetSpecies.dog,
    id: 'spirocerca',
    kind: RecordKind.preventive,
    title: PlanText('Park worm prevention', 'מניעת תולעת הפארק'),
    why: PlanText(
      'The park worm (Spirocerca) is common in Israel. A preventive treatment '
          'every 3 months is the usual advice.',
      'תולעת הפארק (ספירוצרקה) נפוצה בישראל, ולכן נהוג לתת טיפול מונע כל 3 חודשים.',
    ),
    interval: PlanInterval.months(3),
    startAgeWeeks: 12,
    matchWords: _spirocercaWords,
    sources: [_spirocercaIsrael, _msdSpirocerca],
  ),
  PlanTemplateItem(
    species: PetSpecies.dog,
    id: 'deworm',
    kind: RecordKind.preventive,
    title: PlanText('Deworming', 'טיפול נגד תולעים'),
    why: PlanText(
      'Puppies are dewormed often; adult dogs usually every 3 months.',
      'גורים מקבלים טיפול לעיתים קרובות, כלבים בוגרים בדרך כלל כל 3 חודשים.',
    ),
    interval: PlanInterval.months(3),
    youngIntervals: _youngWorming,
    startAgeWeeks: 2,
    matchWords: _dewormWords,
    sources: [_esccapWorms],
  ),
  PlanTemplateItem(
    species: PetSpecies.dog,
    id: 'flea',
    kind: RecordKind.preventive,
    title: PlanText('Flea and tick treatment', 'טיפול נגד פרעושים וקרציות'),
    why: PlanText(
      'Fleas and ticks carry diseases. How often depends on the product.',
      'פרעושים וקרציות מעבירים מחלות. התדירות תלויה במוצר.',
    ),
    interval: PlanInterval.months(1),
    monthChoices: [1, 3],
    startAgeWeeks: 8,
    matchWords: _fleaWords,
    sources: [_esccapEcto],
  ),
];

/// The cat's plan, in the order it is shown.
const catPlan = <PlanTemplateItem>[
  PlanTemplateItem(
    species: PetSpecies.cat,
    id: 'combined',
    kind: RecordKind.vaccination,
    title: PlanText('Combined cat vaccine (FVRCP)', 'חיסון משולש'),
    seriesTitle: PlanText(
      'Combined cat vaccine, kitten dose {n} of {count}',
      'חיסון משולש, מנת גור {n} מתוך {count}',
    ),
    why: PlanText(
      'Protects against panleukopenia and cat flu. Kittens get a short series '
          'first, then once a year or as your vet suggests.',
      'מגן מפני מחלת הפנלאוקופניה ושפעת החתולים. גורים מקבלים קודם סדרה קצרה, '
          'ואחר כך פעם בשנה או לפי המלצת הווטרינר.',
    ),
    series: PlanSeries([8, 12, 16]),
    interval: PlanInterval.months(12),
    startAgeWeeks: 6,
    matchWords: _catCombinedWords,
    sources: [_wsava],
  ),
  PlanTemplateItem(
    species: PetSpecies.cat,
    id: 'rabies',
    kind: RecordKind.vaccination,
    standing: PlanStanding.recommended,
    title: PlanText('Rabies vaccine', 'חיסון כלבת'),
    why: PlanText(
      'Not required by law for cats, but recommended, especially for cats '
          'that go outside.',
      'לא חובה לפי החוק לחתולים, אבל מומלץ, במיוחד לחתולים שיוצאים החוצה.',
    ),
    interval: PlanInterval.months(12),
    startAgeWeeks: 12,
    matchWords: _rabiesWords,
    sources: [_israelRabiesCats, _wsava, _msdRabies],
  ),
  PlanTemplateItem(
    species: PetSpecies.cat,
    id: 'deworm',
    kind: RecordKind.preventive,
    title: PlanText('Deworming', 'טיפול נגד תולעים'),
    why: PlanText(
      'Kittens are dewormed often; for adult cats it depends on whether they '
          'go outside.',
      'גורים מקבלים טיפול לעיתים קרובות. לחתולים בוגרים זה תלוי אם הם יוצאים החוצה.',
    ),
    interval: PlanInterval.months(3),
    youngIntervals: _youngWorming,
    startAgeWeeks: 3,
    matchWords: _dewormWords,
    sources: [_esccapWorms],
  ),
  PlanTemplateItem(
    species: PetSpecies.cat,
    id: 'flea',
    kind: RecordKind.preventive,
    title: PlanText('Flea treatment', 'טיפול נגד פרעושים'),
    why: PlanText(
      'Fleas bother indoor cats too. How often depends on the product.',
      'פרעושים מציקים גם לחתולים שלא יוצאים מהבית. התדירות תלויה במוצר.',
    ),
    interval: PlanInterval.months(1),
    monthChoices: [1, 3],
    startAgeWeeks: 8,
    matchWords: _fleaWords,
    sources: [_esccapEcto],
  ),
];

/// The plan of [species]; empty for the animals without one yet.
List<PlanTemplateItem> planTemplatesFor(PetSpecies species) =>
    switch (species) {
      PetSpecies.dog => dogPlan,
      PetSpecies.cat => catPlan,
      _ => const [],
    };

/// The item whose [PlanTemplateItem.key] is [key], or `null`.
PlanTemplateItem? planTemplateByKey(String key) {
  for (final item in [...dogPlan, ...catPlan]) {
    if (item.key == key) return item;
  }
  return null;
}
