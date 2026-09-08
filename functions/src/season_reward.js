"use strict";

const POLICY_VERSION = 1;
const CLAIM_GRACE_MINUTES = 60;

const TIERS = Object.freeze([
  Object.freeze({
    id: "champion",
    label: "Champion",
    maximumRank: 1,
    coins: 600,
    diamonds: 5,
  }),
  Object.freeze({
    id: "podium",
    label: "Podium",
    maximumRank: 3,
    coins: 400,
    diamonds: 3,
  }),
  Object.freeze({
    id: "top_10",
    label: "Top 10",
    maximumRank: 10,
    coins: 250,
    diamonds: 2,
  }),
  Object.freeze({
    id: "top_25",
    label: "Top 25",
    maximumRank: 25,
    coins: 150,
    diamonds: 1,
  }),
  Object.freeze({
    id: "participant",
    label: "Explorateur",
    maximumRank: null,
    coins: 75,
    diamonds: 0,
  }),
]);

function parseSeasonKey(seasonKey) {
  const match = /^(\d{4})-(\d{2})$/.exec(seasonKey);
  const year = match ? Number(match[1]) : 0;
  const month = match ? Number(match[2]) : 0;
  if (!match || year < 2020 || year > 2200 || month < 1 || month > 12) {
    throw new TypeError("seasonKey est invalide.");
  }
  return {year, month};
}

function seasonClaimOpensAt(seasonKey) {
  const {year, month} = parseSeasonKey(seasonKey);
  return new Date(Date.UTC(year, month, 1, 0, CLAIM_GRACE_MINUTES));
}

function seasonRewardForRank(rank, seasonKey) {
  if (!Number.isSafeInteger(rank) || rank < 1) {
    throw new TypeError("rank est invalide.");
  }
  parseSeasonKey(seasonKey);
  const tier = TIERS.find((candidate) =>
    candidate.maximumRank === null || rank <= candidate.maximumRank);
  const seasonId = seasonKey.replace("-", "_");
  return {
    policyVersion: POLICY_VERSION,
    tierId: tier.id,
    tierLabel: tier.label,
    xp: 0,
    coins: tier.coins,
    diamonds: tier.diamonds,
    cosmeticIds: [],
    progressionPoints: 0,
    ...(tier.id === "champion" ? {
      emblemId: `season_${seasonId}_champion`,
    } : {}),
  };
}

function seasonRewardTiers() {
  return TIERS.map((tier) => ({...tier}));
}

function seasonRewardClaimId(seasonKey) {
  parseSeasonKey(seasonKey);
  return `season_reward:${seasonKey}`;
}

module.exports = {
  CLAIM_GRACE_MINUTES,
  POLICY_VERSION,
  parseSeasonKey,
  seasonClaimOpensAt,
  seasonRewardClaimId,
  seasonRewardForRank,
  seasonRewardTiers,
};
