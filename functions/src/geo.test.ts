import {test} from "node:test";
import assert from "node:assert/strict";
import {approximate, geohashEncode} from "./geo.js";

test("matches the app's geohash (real errand: Mountain Rise, PMB)", () => {
  assert.equal(geohashEncode(-29.58, 30.4), "kdtxez0s526f");
});

test("approximates to ~1km like the app (halves away from zero)", () => {
  assert.equal(approximate(-29.5849), -29.58);
  assert.equal(approximate(30.4651), 30.47);
});
