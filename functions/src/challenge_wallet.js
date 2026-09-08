"use strict";

function nonNegativeInteger(value, fallback = 0) {
  return Number.isSafeInteger(value) && value >= 0 ? value : fallback;
}

function stringList(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((item) =>
    typeof item === "string" && item.trim().length > 0)
  .map((item) => item.trim()))].sort();
}

function emptyWallet() {
  return {
    schemaVersion: 1,
    coins: 0,
    diamonds: 0,
    progressionPoints: 0,
    cosmeticIds: [],
    stampIds: [],
    emblemIds: [],
    deliveredClaimIds: [],
  };
}

function normalizeWallet(player) {
  const source = player && player.economy && player.economy.wallet;
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    return emptyWallet();
  }
  return {
    schemaVersion: 1,
    coins: nonNegativeInteger(source.coins),
    diamonds: nonNegativeInteger(source.diamonds),
    progressionPoints: nonNegativeInteger(source.progressionPoints),
    cosmeticIds: stringList(source.cosmeticIds),
    stampIds: stringList(source.stampIds),
    emblemIds: stringList(source.emblemIds),
    deliveredClaimIds: stringList(source.deliveredClaimIds),
  };
}

function normalizeReward(value) {
  const source = value && typeof value === "object" && !Array.isArray(value) ?
    value : {};
  const stampId = typeof source.stampId === "string" &&
    source.stampId.trim().length > 0 ? source.stampId.trim() : null;
  const emblemId = typeof source.emblemId === "string" &&
    source.emblemId.trim().length > 0 ? source.emblemId.trim() : null;
  return {
    xp: nonNegativeInteger(source.xp),
    coins: nonNegativeInteger(source.coins),
    diamonds: nonNegativeInteger(source.diamonds),
    cosmeticIds: stringList(source.cosmeticIds),
    ...(stampId === null ? {} : {stampId}),
    ...(emblemId === null ? {} : {emblemId}),
    progressionPoints: nonNegativeInteger(source.progressionPoints),
  };
}

function applyReward(wallet, claimId, rewardValue) {
  const normalized = normalizeWallet({economy: {wallet}});
  if (normalized.deliveredClaimIds.includes(claimId)) return normalized;
  const reward = normalizeReward(rewardValue);
  return {
    schemaVersion: 1,
    coins: normalized.coins + reward.coins,
    diamonds: normalized.diamonds + reward.diamonds,
    progressionPoints:
      normalized.progressionPoints + reward.progressionPoints,
    cosmeticIds: stringList([
      ...normalized.cosmeticIds,
      ...reward.cosmeticIds,
    ]),
    stampIds: stringList([
      ...normalized.stampIds,
      ...(reward.stampId ? [reward.stampId] : []),
    ]),
    emblemIds: stringList([
      ...normalized.emblemIds,
      ...(reward.emblemId ? [reward.emblemId] : []),
    ]),
    deliveredClaimIds: stringList([
      ...normalized.deliveredClaimIds,
      claimId,
    ]),
  };
}

function rewardClaimId(challenge) {
  if (challenge.period === "permanent") return `${challenge.id}@permanent`;
  const validFrom = new Date(challenge.validFromUtc);
  if (Number.isNaN(validFrom.getTime())) {
    throw new TypeError("La date du défi officiel est invalide.");
  }
  return `${challenge.id}@${validFrom.toISOString()}`;
}

function challengeSucceeded(challenge, performance) {
  const condition = challenge.successCondition || {};
  if (nonNegativeInteger(performance.correctAnswers) <
      nonNegativeInteger(condition.minimumCorrectAnswers)) {
    return false;
  }
  if (nonNegativeInteger(performance.score) <
      nonNegativeInteger(condition.minimumScore)) {
    return false;
  }
  if (condition.maximumAverageDistanceKilometers != null) {
    const distance = performance.averageDistanceKilometers;
    if (typeof distance !== "number" || !Number.isFinite(distance) ||
        distance > condition.maximumAverageDistanceKilometers) {
      return false;
    }
  }
  return true;
}

module.exports = {
  applyReward,
  challengeSucceeded,
  emptyWallet,
  normalizeReward,
  normalizeWallet,
  rewardClaimId,
};
