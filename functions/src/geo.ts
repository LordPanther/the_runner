/**
 * Location helpers matching the app's GeohashService and
 * location_privacy.dart exactly, so an errand edited on the server is
 * found by the same nearby search as one created in the app.
 */

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/** Standard geohash, longitude bit first (same as the Dart encoder). */
export function geohashEncode(lat: number, lng: number, precision = 12): string {
  let even = true;
  let bit = 0;
  let ch = 0;
  let out = "";
  let [minLat, maxLat, minLng, maxLng] = [-90, 90, -180, 180];
  while (out.length < precision) {
    if (even) {
      const mid = (minLng + maxLng) / 2;
      if (lng > mid) {
        ch |= 1 << (4 - bit);
        minLng = mid;
      } else {
        maxLng = mid;
      }
    } else {
      const mid = (minLat + maxLat) / 2;
      if (lat > mid) {
        ch |= 1 << (4 - bit);
        minLat = mid;
      } else {
        maxLat = mid;
      }
    }
    even = !even;
    if (bit < 4) {
      bit++;
    } else {
      out += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return out;
}

/** ~1km grid: the only location the public errand document carries. */
// Rounds halves away from zero, like Dart's round(), so both sides agree.
export const approximate = (value: number) =>
  Math.sign(value) * Math.round(Math.abs(value) * 100) / 100;
