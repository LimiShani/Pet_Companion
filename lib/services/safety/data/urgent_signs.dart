import 'safety_text.dart';

/// "Is it urgent?": signs that mean going to a vet now, by animal.
///
/// General guidance, never a diagnosis: every sign leads to the same
/// answer (call the vet or the emergency clinic and go) and the page has
/// one Call now at the top. No doses, no home treatment.
///
/// Shown only with the `safety.lists` capability (the Beta testers) until a
/// vet has reviewed this file. Sources:
const urgentSignSources = [
  SafetySource(
    'MSD Veterinary Manual, pet owner version: emergencies and first aid',
    'https://www.msdvetmanual.com/',
  ),
  SafetySource(
    'ASPCA Animal Poison Control Center',
    'https://www.aspca.org/pet-care/animal-poison-control',
  ),
  SafetySource('Pet Poison Helpline', 'https://www.petpoisonhelpline.com/'),
  SafetySource(
    'AVMA: pet first aid, what to do in an emergency',
    'https://www.avma.org/resources-tools/pet-owners/emergencycare',
  ),
];

/// One sign that means "go now".
class UrgentSign {
  const UrgentSign({
    required this.id,
    required this.title,
    required this.detail,
    this.only,
  });

  /// Stable, for keys and tests.
  final String id;

  /// What the owner sees, in a few words.
  final SafetyText title;

  /// One short line: what it looks like.
  final SafetyText detail;

  /// The one animal this sign is about; `null` for every animal.
  final SafetyAnimal? only;

  bool appliesTo(SafetyAnimal animal) => only == null || only == animal;
}

/// Every sign, the most common emergencies first. Use [urgentSignsFor].
const urgentSigns = <UrgentSign>[
  UrgentSign(
    id: 'breathing',
    title: SafetyText('Trouble breathing', 'קושי לנשום'),
    detail: SafetyText(
      'Struggling for air, noisy breathing, a cat breathing with its mouth open.',
      'מאמץ לנשום, נשימה רועשת, חתול שנושם בפה פתוח.',
    ),
  ),
  UrgentSign(
    id: 'collapse',
    title: SafetyText('Collapse or cannot stand', 'התמוטטות או חוסר יכולת לעמוד'),
    detail: SafetyText(
      'Fainting, sudden weakness, not responding as usual.',
      'עילפון, חולשה פתאומית, אין תגובה כרגיל.',
    ),
  ),
  UrgentSign(
    id: 'gums',
    title: SafetyText('Pale, white or blue gums', 'חניכיים חיוורות, לבנות או כחלחלות'),
    detail: SafetyText(
      'Gums are usually pink. A change of colour can mean shock or no air.',
      'חניכיים בריאות ורודות. שינוי צבע יכול להעיד על הלם או מחסור בחמצן.',
    ),
  ),
  UrgentSign(
    id: 'seizure',
    title: SafetyText('A seizure', 'פרכוס'),
    detail: SafetyText(
      'Shaking, paddling legs, not aware. Above all one that goes on or comes back.',
      'רעד, תנועות חתירה ברגליים, חוסר תגובה. במיוחד פרכוס ממושך או חוזר.',
    ),
  ),
  UrgentSign(
    id: 'poison',
    title: SafetyText('Ate or licked something poisonous', 'אכילה או ליקוק של משהו רעיל'),
    detail: SafetyText(
      'Medicines, rat poison, antifreeze, chocolate, xylitol, lilies for cats. Go even with no signs yet.',
      'תרופות, רעל עכברים, נוזל קירור, שוקולד, קסיליטול, שושן אצל חתולים. גם כשעוד אין סימנים.',
    ),
  ),
  UrgentSign(
    id: 'bloat',
    only: SafetyAnimal.dog,
    title: SafetyText('A swollen, hard belly with retching', 'בטן נפוחה וקשה עם ניסיונות הקאה'),
    detail: SafetyText(
      'Trying to vomit with nothing coming up, restless, drooling. Large dogs most of all.',
      'ניסיונות להקיא בלי שיוצא דבר, אי־שקט, ריור. בעיקר אצל כלבים גדולים.',
    ),
  ),
  UrgentSign(
    id: 'urine',
    only: SafetyAnimal.cat,
    title: SafetyText('Straining to pee with little or no urine', 'מאמץ להטיל שתן עם מעט שתן או בלי'),
    detail: SafetyText(
      'In and out of the litter box, crying. Male cats above all: a blocked bladder.',
      'כניסות ויציאות מארגז החול, יללות. בעיקר אצל חתולים זכרים: חסימה בדרכי השתן.',
    ),
  ),
  UrgentSign(
    id: 'bleeding',
    title: SafetyText('Heavy bleeding', 'דימום חזק'),
    detail: SafetyText(
      'Bleeding that does not stop with firm pressure, or blood from the nose, mouth or bottom.',
      'דימום שלא נעצר בלחיצה חזקה, או דם מהאף, מהפה או מפי הטבעת.',
    ),
  ),
  UrgentSign(
    id: 'heat',
    title: SafetyText('Heatstroke signs', 'סימני מכת חום'),
    detail: SafetyText(
      'Heavy panting, drooling, bright red gums, wobbling or vomiting after heat or exercise.',
      'התנשפות כבדה, ריור, חניכיים אדומות מאוד, חוסר יציבות או הקאה אחרי חום או מאמץ.',
    ),
  ),
  UrgentSign(
    id: 'eye',
    title: SafetyText('An eye injury', 'פגיעה בעין'),
    detail: SafetyText(
      'An eye that bulges, bleeds, is held shut, or turns cloudy all of a sudden.',
      'עין בולטת, מדממת, סגורה כל הזמן, או שהפכה עכורה בפתאומיות.',
    ),
  ),
  UrgentSign(
    id: 'accident',
    title: SafetyText('Hit by a car or a bad fall', 'פגיעה של רכב או נפילה קשה'),
    detail: SafetyText(
      'Go even if all seems fine: injuries inside do not show at first.',
      'גם אם הכול נראה בסדר: פגיעות פנימיות לא נראות מיד.',
    ),
  ),
  UrgentSign(
    id: 'snake',
    title: SafetyText('A snake bite', 'הכשת נחש'),
    detail: SafetyText(
      'Sudden swelling and pain, often on the face or a leg. Keep calm and still, and go.',
      'נפיחות וכאב פתאומיים, לרוב בפנים או ברגל. לשמור על רוגע ומנוחה ולנסוע.',
    ),
  ),
  UrgentSign(
    id: 'caterpillar',
    only: SafetyAnimal.dog,
    title: SafetyText('Touched pine processionary caterpillars', 'מגע עם זחלי תהלוכה של האורן'),
    detail: SafetyText(
      'Drooling, a swollen tongue or mouth after sniffing a line of caterpillars.',
      'ריור, לשון או פה נפוחים אחרי הרחה של שיירת זחלים.',
    ),
  ),
  UrgentSign(
    id: 'swelling',
    title: SafetyText('A swollen face or throat', 'נפיחות בפנים או בגרון'),
    detail: SafetyText(
      'After a sting, a bite or something new, above all with trouble breathing.',
      'אחרי עקיצה, נשיכה או משהו חדש, במיוחד עם קושי לנשום.',
    ),
  ),
  UrgentSign(
    id: 'vomiting',
    title: SafetyText('Vomiting or diarrhoea that will not stop', 'הקאות או שלשול שלא נפסקים'),
    detail: SafetyText(
      'Again and again, with blood, or with weakness. Sooner for puppies, kittens and old pets.',
      'שוב ושוב, עם דם, או עם חולשה. מוקדם יותר אצל גורים וחיות מבוגרות.',
    ),
  ),
  UrgentSign(
    id: 'legs',
    title: SafetyText('Sudden weak or dragged back legs', 'חולשה פתאומית או גרירה של הרגליים האחוריות'),
    detail: SafetyText(
      'Cannot walk, or crying when moved. In cats, cold back legs too.',
      'אין יכולת ללכת, או בכי בזמן תזוזה. אצל חתולים גם רגליים אחוריות קרות.',
    ),
  ),
  UrgentSign(
    id: 'pain',
    title: SafetyText('Severe pain', 'כאב חזק'),
    detail: SafetyText(
      'Crying out, hiding, hunched, cannot get comfortable.',
      'צעקות, הסתתרות, גב מכווץ, אין תנוחה נוחה.',
    ),
  ),
  UrgentSign(
    id: 'birth',
    title: SafetyText('Trouble giving birth', 'קושי בלידה'),
    detail: SafetyText(
      'Strong straining with no baby coming, or a long wait between babies.',
      'צירים חזקים בלי שנולד גור, או הפסקה ארוכה בין גורים.',
    ),
  ),
];

/// The signs for [animal]: the general ones and its own. Rabbits, reptiles
/// and the rest get the general list.
List<UrgentSign> urgentSignsFor(SafetyAnimal animal) => [
  for (final sign in urgentSigns)
    if (sign.appliesTo(animal)) sign,
];
