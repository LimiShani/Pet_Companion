// Israel: the first (and today the only) registered region.

import type { RegionConfig } from './types.ts';

export const IL: RegionConfig = {
  code: 'IL',
  name: 'Israel',
  // One box from Eilat to the northern border, coast to the Jordan valley.
  bounds: [{ minLat: 29.3, maxLat: 33.5, minLng: 34.2, maxLng: 35.95 }],
  provider: { regionCode: 'IL', geocodeComponents: 'country:IL' },
  defaultLanguage: 'he',
  languages: ['he', 'en'],
  radii: {
    emergencyCuratedM: [10_000, 25_000, 50_000, 120_000],
    longTermM: [5_000, 10_000, 20_000],
  },
  phone: {
    countryCallingCode: '972',
    trunkPrefix: '0',
    // 0X-XXXXXXX (landlines 02/03/04/08/09), 05X-XXXXXXX (mobile), 07X-XXXXXXX
    // (VoIP), the same with +972 (optionally "+972 (0)"), separators "-", " "
    // or "." anywhere, and four-digit star numbers such as *8818.
    scanPattern:
      String.raw`(?<![\d+*])(?:\+972[\s.-]?(?:\(0\)[\s.-]?)?|\(?0)(?:5\d|7\d|[2-489])\)?(?:[\s.-]?\d){7}(?!\d)` +
      String.raw`|(?<![\w*])\*\d{4}(?!\d)`,
  },
  nameStopWords: [
    // English
    'the', 'of', 'and', 'vet', 'vets', 'veterinary', 'veterinarian', 'clinic', 'clinics',
    'hospital', 'animal', 'animals', 'pet', 'pets', 'care', 'medical', 'emergency',
    'center', 'centre', 'dr', 'ltd', 'israel',
    // Hebrew
    'מרפאה', 'מרפאת', 'מרפאות', 'וטרינרית', 'וטרינרי', 'וטרינרים', 'וטרינר', 'וטרינרה',
    'בית', 'חולים', 'בעלי', 'חיים', 'מרכז', 'חירום', 'רפואה', 'רפואי', 'רפואית',
    'דר', 'דוקטור', 'בעמ', 'ישראל', 'של',
  ],
  nameStopWordPrefixes: ['ה', 'ו', 'ל', 'ב', 'ש', 'מ'],
  streetWords: ['רחוב', 'רח', 'שדרות', 'שד', 'דרך', 'street', 'st', 'road', 'rd', 'avenue', 'ave', 'blvd', 'boulevard'],
  evidencePatterns: {
    emergency: ['24/7', '24 שעות', 'חירום', 'emergency'],
  },
  closureWords: ['נסגר', 'סגור לצמיתות', 'permanently closed', 'closed permanently'],
  timeZone: 'Asia/Jerusalem',
};
