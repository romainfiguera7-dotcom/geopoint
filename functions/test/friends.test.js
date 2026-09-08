"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  formatFriendCode,
  friendPairId,
  generateFriendCode,
  normalizeFriendCode,
  socialAllowed,
} = require("../src/friends");

test("normalise et présente un code ami sans caractères ambigus", () => {
  assert.equal(normalizeFriendCode("gp-abcd-2345"), "GPABCD2345");
  assert.equal(formatFriendCode("GPABCD2345"), "GP-ABCD-2345");
  assert.throws(() => normalizeFriendCode("GP-O0IL-1234"), /invalide/);
});

test("génère un code stable avec une source aléatoire contrôlée", () => {
  const code = generateFriendCode((length) => Buffer.alloc(length, 0));
  assert.equal(code, "GPAAAAAAAA");
});

test("fabrique le même identifiant de paire dans les deux sens", () => {
  assert.equal(friendPairId("uid_a", "uid_b"), friendPairId("uid_b", "uid_a"));
  assert.notEqual(friendPairId("uid_a", "uid_b"), friendPairId("uid_a", "uid_c"));
});

test("refuse les fonctions sociales aux profils enfants signalés", () => {
  assert.equal(socialAllowed({profileType: "adult"}), true);
  assert.equal(socialAllowed({isChild: true}), false);
  assert.equal(socialAllowed({audience: "child"}), false);
});
