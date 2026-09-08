"use strict";

const bundledPack = require("../data/challenge_pack_2026_09.json");

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function deepMerge(base, overrides) {
  const result = {...base};
  for (const [key, value] of Object.entries(overrides)) {
    result[key] = isObject(result[key]) && isObject(value) ?
      deepMerge(result[key], value) : value;
  }
  return result;
}

function applyAutomaticRanking(challenge) {
  if (!isObject(challenge)) return challenge;
  const audience = challenge.audience || "standard";
  if (audience !== "standard") return challenge;
  return {
    ...challenge,
    minimumPlayerLevel: 1,
    rankingGroupId: challenge.id,
    geoBrainPersonalizationAllowed: false,
  };
}

function mergeBundledPermanentChallenges(pack, bundled = bundledPack) {
  if (!isObject(pack) || !isObject(bundled)) {
    throw new TypeError("Les packs de défis doivent être des objets.");
  }
  const challenges = Array.isArray(pack.challenges) ? pack.challenges : [];
  const existingIds = new Set(challenges
    .filter(isObject)
    .map((challenge) => challenge.id));
  const missingPermanent = (Array.isArray(bundled.challenges) ?
    bundled.challenges : [])
    .filter((challenge) => isObject(challenge) &&
      challenge.period === "permanent" &&
      !existingIds.has(challenge.id));
  if (missingPermanent.length === 0) return pack;
  return {
    ...pack,
    challenges: [...challenges, ...missingPermanent],
  };
}

function expandChallengePack(pack) {
  if (!isObject(pack)) {
    throw new TypeError("Le pack officiel doit être un objet.");
  }
  const templates = new Map();
  for (const template of pack.templates || []) {
    if (isObject(template) && typeof template.templateId === "string") {
      templates.set(template.templateId, template);
    }
  }
  const challenges = Array.isArray(pack.challenges) ?
    pack.challenges.map(applyAutomaticRanking) : [];
  for (const entry of pack.schedule || []) {
    if (!isObject(entry)) continue;
    const template = templates.get(entry.templateId);
    if (!template) {
      throw new TypeError(`Modèle officiel introuvable : ${entry.templateId}.`);
    }
    const challenge = deepMerge(template, entry);
    delete challenge.templateId;
    delete challenge.childVariantTemplateId;
    delete challenge.beginnerVariantTemplateId;
    challenges.push(applyAutomaticRanking(challenge));
  }
  return challenges;
}

function competitiveSignature(challenge) {
  const condition = challenge.successCondition || {};
  const retry = challenge.retryPolicy || {};
  const countries = Array.isArray(challenge.countryIds) ?
    [...challenge.countryIds].sort().join(",") : "";
  return [
    challenge.modeId,
    challenge.difficultyId,
    challenge.continentId || "-",
    countries,
    challenge.questionCount == null ? "-" : challenge.questionCount,
    challenge.durationSeconds == null ? "-" : challenge.durationSeconds,
    condition.minimumCorrectAnswers,
    condition.minimumScore || 0,
    condition.maximumAverageDistanceKilometers == null ?
      "-" : condition.maximumAverageDistanceKilometers,
    retry.maximumAttempts,
    retry.unlimitedFreeAttempts === true,
    retry.diamondRetryCost || 0,
    retry.maximumDiamondRetries || 0,
    retry.rewardedAdvertisementAllowed === true,
    retry.maximumRewardedAdvertisementRetries || 0,
    retry.unlimitedRewardedAdvertisementRetries === true,
  ].join("|");
}

function resolveOfficialChallenge(pack, input, now = new Date()) {
  const challenge = expandChallengePack(pack).find(
    (candidate) => candidate.id === input.challengeId,
  );
  if (!challenge || challenge.disabled === true) {
    throw new RangeError("Le défi officiel est introuvable.");
  }
  if (typeof challenge.rankingGroupId !== "string") {
    throw new RangeError("Ce défi ne possède pas de classement officiel.");
  }
  if (challenge.rankingGroupId !== input.rankingGroupId) {
    throw new RangeError("Le groupe de classement ne correspond pas.");
  }
  if (competitiveSignature(challenge) !== input.competitiveSignature) {
    throw new RangeError("La configuration compétitive ne correspond pas.");
  }
  if (challenge.period !== "permanent") {
    const validFrom = new Date(challenge.validFromUtc);
    const validUntil = new Date(challenge.validUntilUtc);
    if (
      Number.isNaN(validFrom.getTime()) ||
      Number.isNaN(validUntil.getTime()) ||
      now < validFrom ||
      now >= validUntil
    ) {
      throw new RangeError("Le défi officiel n’est pas actif.");
    }
  }
  return challenge;
}

function sessionExpiry(challenge, now = new Date()) {
  const maximumDuration = 45 * 60 * 1000;
  if (challenge.period === "permanent") {
    return new Date(now.getTime() + maximumDuration);
  }
  const challengeEnd = new Date(challenge.validUntilUtc).getTime();
  return new Date(Math.min(challengeEnd, now.getTime() + maximumDuration));
}

function rankedSubmissionTimingRejection({
  completedAtUtc,
  startedAtUtc,
  expiresAtUtc,
}) {
  const completedAt = new Date(completedAtUtc);
  const startedAt = new Date(startedAtUtc);
  const expiresAt = new Date(expiresAtUtc);
  const graceMilliseconds = 2 * 60 * 1000;
  if (
    Number.isNaN(completedAt.getTime()) ||
    Number.isNaN(startedAt.getTime()) ||
    Number.isNaN(expiresAt.getTime()) ||
    expiresAt.getTime() <= startedAt.getTime()
  ) {
    return "Les dates de la session officielle sont invalides.";
  }
  if (
    completedAt < new Date(startedAt.getTime() - graceMilliseconds) ||
    completedAt > new Date(expiresAt.getTime() + graceMilliseconds)
  ) {
    return "La session officielle a expiré.";
  }
  return null;
}

function questionDurationSeconds(modeId, difficultyId) {
  const standard = {
    discovery: 25,
    easy: 20,
    intermediate: 17,
    hard: 14,
    expert: 10,
  };
  const ultimate = {
    discovery: 18,
    easy: 16,
    intermediate: 14,
    hard: 12,
    expert: 10,
  };
  const source = modeId === "ultimate" ? ultimate : standard;
  return source[difficultyId] || (modeId === "ultimate" ? 15 : 20);
}

function scoringRulesFor(challenge) {
  if (!Number.isSafeInteger(challenge.questionCount) ||
      challenge.questionCount < 1 || challenge.questionCount > 50) {
    throw new TypeError("Le nombre de questions officiel est invalide.");
  }
  return {
    modeId: challenge.modeId,
    difficultyId: challenge.difficultyId,
    questionCount: challenge.questionCount,
    questionDurationSeconds: questionDurationSeconds(
      challenge.modeId,
      challenge.difficultyId,
    ),
  };
}

function bundledChallengePack() {
  return bundledPack;
}

module.exports = {
  bundledChallengePack,
  competitiveSignature,
  expandChallengePack,
  mergeBundledPermanentChallenges,
  rankedSubmissionTimingRejection,
  resolveOfficialChallenge,
  scoringRulesFor,
  sessionExpiry,
};
