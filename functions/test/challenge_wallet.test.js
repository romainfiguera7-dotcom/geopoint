"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyReward,
  challengeSucceeded,
  emptyWallet,
  normalizeWallet,
  rewardClaimId,
} = require("../src/challenge_wallet");

test("crédite une récompense une seule fois", () => {
  const first = applyReward(emptyWallet(), "daily@date", {
    coins: 35,
    diamonds: 1,
    progressionPoints: 2,
  });
  const repeated = applyReward(first, "daily@date", {
    coins: 35,
    diamonds: 1,
    progressionPoints: 2,
  });

  assert.equal(first.coins, 35);
  assert.equal(first.diamonds, 1);
  assert.deepEqual(repeated, first);
});

test("normalise un portefeuille Firebase incomplet", () => {
  const wallet = normalizeWallet({
    economy: {wallet: {coins: 42, deliveredClaimIds: ["a", "a"]}},
  });

  assert.equal(wallet.coins, 42);
  assert.equal(wallet.diamonds, 0);
  assert.deepEqual(wallet.deliveredClaimIds, ["a"]);
});

test("construit les identifiants permanents et datés", () => {
  assert.equal(
    rewardClaimId({id: "world", period: "permanent"}),
    "world@permanent",
  );
  assert.equal(
    rewardClaimId({
      id: "daily",
      period: "daily",
      validFromUtc: "2026-09-08T00:00:00Z",
    }),
    "daily@2026-09-08T00:00:00.000Z",
  );
});

test("vérifie les conditions avec le résultat officiel", () => {
  const challenge = {
    successCondition: {
      minimumCorrectAnswers: 4,
      minimumScore: 300,
      maximumAverageDistanceKilometers: 450,
    },
  };
  assert.equal(challengeSucceeded(challenge, {
    correctAnswers: 4,
    score: 320,
    averageDistanceKilometers: 440,
  }), true);
  assert.equal(challengeSucceeded(challenge, {
    correctAnswers: 4,
    score: 320,
    averageDistanceKilometers: 500,
  }), false);
});
