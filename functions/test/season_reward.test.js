"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  seasonClaimOpensAt,
  seasonRewardClaimId,
  seasonRewardForRank,
  seasonRewardTiers,
} = require("../src/season_reward");

test("ouvre les gains une heure après la clôture mensuelle", () => {
  assert.equal(
    seasonClaimOpensAt("2026-09").toISOString(),
    "2026-10-01T01:00:00.000Z",
  );
});

test("attribue le palier champion et son emblème", () => {
  const reward = seasonRewardForRank(1, "2026-09");
  assert.equal(reward.tierId, "champion");
  assert.equal(reward.coins, 600);
  assert.equal(reward.diamonds, 5);
  assert.equal(reward.emblemId, "season_2026_09_champion");
});

test("récompense aussi chaque participant hors top 25", () => {
  const reward = seasonRewardForRank(987, "2026-09");
  assert.equal(reward.tierId, "participant");
  assert.equal(reward.coins, 75);
  assert.equal(reward.diamonds, 0);
  assert.equal(reward.emblemId, undefined);
});

test("expose des paliers continus du champion au participant", () => {
  assert.deepEqual(
    seasonRewardTiers().map((tier) => tier.maximumRank),
    [1, 3, 10, 25, null],
  );
});

test("fabrique un identifiant de versement stable", () => {
  assert.equal(seasonRewardClaimId("2026-09"), "season_reward:2026-09");
});

test("refuse une saison ou un rang invalides", () => {
  assert.throws(() => seasonClaimOpensAt("septembre"), /seasonKey/);
  assert.throws(() => seasonRewardForRank(0, "2026-09"), /rank/);
});
