"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  isChildPlayer,
  resolveProfileSafety,
} = require("../src/profile_safety");

test("active toutes les protections pour un profil enfant", () => {
  const safety = resolveProfileSafety({}, "child", "9_11");
  assert.deepEqual(safety, {
    profileType: "child",
    isChild: true,
    childAgeGroup: "9_11",
    advertisementsAllowed: false,
    socialAllowed: false,
    publicRankingAllowed: false,
    purchasesAllowed: false,
  });
});

test("ne permet jamais de retransformer un profil enfant en adulte", () => {
  const safety = resolveProfileSafety(
    {profileType: "child", childAgeGroup: "6_8"},
    "adult",
    null,
  );
  assert.equal(safety.profileType, "child");
  assert.equal(safety.childAgeGroup, "6_8");
  assert.equal(safety.publicRankingAllowed, false);
});

test("reconnaît les anciens marqueurs de protection enfant", () => {
  assert.equal(isChildPlayer({isChild: true}), true);
  assert.equal(isChildPlayer({audience: "child"}), true);
  assert.equal(isChildPlayer({profileType: "adult"}), false);
});
