// Small geometry helpers: great-circle distance and bounding boxes.

import type { BoundingBox } from './regions/types.ts';

export interface LatLng {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_M = 6_371_008.8;
const toRad = (deg: number): number => (deg * Math.PI) / 180;

/** Haversine distance in metres; plenty accurate at country scale. */
export function distanceM(a: LatLng, b: LatLng): number {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** True when the point lies inside (or on the edge of) any of the boxes. */
export function inAnyBox(boxes: BoundingBox[], lat: number, lng: number): boolean {
  return boxes.some((b) => lat >= b.minLat && lat <= b.maxLat && lng >= b.minLng && lng <= b.maxLng);
}

/**
 * A box that contains the circle (center, radiusM). Used to pre-filter
 * curated rows in the database; the exact distance is checked afterwards.
 */
export function boxAround(center: LatLng, radiusM: number): BoundingBox {
  const dLat = (radiusM / EARTH_RADIUS_M) * (180 / Math.PI);
  const cos = Math.max(0.01, Math.cos(toRad(center.lat)));
  const dLng = dLat / cos;
  return {
    minLat: center.lat - dLat,
    maxLat: center.lat + dLat,
    minLng: center.lng - dLng,
    maxLng: center.lng + dLng,
  };
}
