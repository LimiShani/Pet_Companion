// Lookups over a region's generated list of localities (cities, towns and
// local councils; e.g. regions/il_localities.ts). Dog parks store the code
// of their nearest locality; meetups will use the same codes.

import { distanceM } from './geo.ts';
import type { LatLng } from './geo.ts';
import type { Locality } from './regions/types.ts';

/** The locality with this code, or undefined. */
export function localityByCode(list: readonly Locality[], code: string): Locality | undefined {
  return list.find((l) => l.code === code);
}

/** The locality whose centre is nearest to the point, if one is within maxM metres. */
export function nearestLocality(list: readonly Locality[], point: LatLng, maxM = 15_000): Locality | undefined {
  let best: Locality | undefined;
  let bestM = maxM;
  for (const l of list) {
    const m = distanceM(point, l);
    if (m <= bestM) {
      best = l;
      bestM = m;
    }
  }
  return best;
}
