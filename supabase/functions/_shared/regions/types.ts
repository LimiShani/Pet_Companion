// The shape of a region module: everything country-specific that the
// find-vet search and the weekly directory check need. The rest of the
// backend takes a RegionConfig and holds no country knowledge, so adding a
// country is one new file next to il.ts plus one line in index.ts.

/** A rectangle in degrees (WGS84). A region may need several. */
export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

export interface RegionConfig {
  /** ISO 3166-1 alpha-2, upper case ('IL'). Also vet_facilities.country_code. */
  code: string;
  /** English name, for logs and the `regions` action. */
  name: string;
  /** Coordinates outside every box are rejected (400). */
  bounds: BoundingBox[];
  provider: {
    /** Places API `regionCode` (CLDR two letters). */
    regionCode: string;
    /** Geocoding API `components` filter, e.g. 'country:IL'. */
    geocodeComponents: string;
  };
  /** Language used when a request does not name one. */
  defaultLanguage: string;
  /** Languages a request may ask for (BCP-47 primary tags). */
  languages: string[];
  radii: {
    /**
     * Emergency radius ladder in metres for curated records, smallest
     * first. The search widens step by step while fewer than two
     * emergency-advertised results are in range.
     */
    emergencyCuratedM: number[];
    /** Long-term radius ladder in metres; widened while fewer than 3 results. */
    longTermM: number[];
  };
  phone: {
    /** Country calling code without '+', e.g. '972'. */
    countryCallingCode: string;
    /** National trunk prefix dialled before area codes, e.g. '0' ('' if none). */
    trunkPrefix: string;
    /**
     * Regular expression SOURCE (no slashes, compiled with the 'gu' flags)
     * that finds phone numbers of this country in page text. Kept as a
     * string so every use gets a fresh RegExp (global regexes carry state).
     */
    scanPattern: string;
  };
  /**
   * Generic words removed from names before comparing them ("vet",
   * "clinic", "מרפאה"...), lower case.
   */
  nameStopWords: string[];
  /**
   * One-letter prefixes that may be glued to a stop word (Hebrew "ה", "ו",
   * "ל"...): "המרפאה" is "ה" + "מרפאה". Empty for languages without them.
   */
  nameStopWordPrefixes: string[];
  /** Words dropped from street names before comparing addresses ("רחוב", "street"). */
  streetWords: string[];
  /**
   * Default evidence patterns per claim key, used by the weekly check when a
   * claim has none of its own. Matched case-insensitively as substrings.
   */
  evidencePatterns: Record<string, string[]>;
  /**
   * Wording that suggests a facility closed. Matched case-insensitively and
   * only when not followed by another letter, so "נסגר" does not fire on
   * "נסגרת בשעה 20:00" (closes at 20:00).
   */
  closureWords: string[];
  /** IANA time zone; the weekly job reports local check times in it. */
  timeZone: string;
}
