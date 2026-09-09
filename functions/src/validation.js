"use strict";

const {normalizeFriendCode} = require("./friends");
const {
  normalizedChildAgeGroup,
  normalizedProfileType,
} = require("./profile_safety");

const IDENTIFIER_PATTERN = /^[a-zA-Z0-9_-]+$/;
const CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f\u007f]/;

function requireObject(value, fieldName) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError(`${fieldName} doit être un objet.`);
  }
  return value;
}

function requireApiVersion(data) {
  const source = requireObject(data, "data");
  if (source.apiVersion !== 1) {
    throw new RangeError("Version de contrat PointGeo non prise en charge.");
  }
  return source;
}

function requireIdentifier(value, fieldName, maxLength = 128) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (
    normalized.length === 0 ||
    normalized.length > maxLength ||
    !IDENTIFIER_PATTERN.test(normalized)
  ) {
    throw new TypeError(`${fieldName} est invalide.`);
  }
  return normalized;
}

function requireDisplayName(value) {
  const normalized = typeof value === "string"
    ? value.trim().replace(/\s+/g, " ")
    : "";
  if (
    normalized.length < 2 ||
    normalized.length > 24 ||
    CONTROL_CHARACTER_PATTERN.test(normalized)
  ) {
    throw new TypeError("displayName est invalide.");
  }
  return normalized;
}

function requireInteger(value, fieldName, minimum, maximum) {
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new TypeError(`${fieldName} est invalide.`);
  }
  return value;
}

function requireNumber(value, fieldName, minimum, maximum) {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new TypeError(`${fieldName} est invalide.`);
  }
  return value;
}

function optionalIsoDate(value, fieldName) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    throw new TypeError(`${fieldName} est invalide.`);
  }
  return new Date(value).toISOString();
}

function requireDocumentId(value, fieldName, maxLength = 256) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (
    normalized.length === 0 ||
    normalized.length > maxLength ||
    normalized.includes("/") ||
    CONTROL_CHARACTER_PATTERN.test(normalized)
  ) {
    throw new TypeError(`${fieldName} est invalide.`);
  }
  return normalized;
}

function validateIdentityRegistration(data) {
  const source = requireApiVersion(data);
  const profileType = normalizedProfileType(source.profileType);
  const childAgeGroup = normalizedChildAgeGroup(source.childAgeGroup);
  if (profileType === "child" && childAgeGroup === null) {
    throw new TypeError("childAgeGroup est invalide.");
  }
  return {
    localPlayerId: requireIdentifier(source.localPlayerId, "localPlayerId"),
    displayName: requireDisplayName(source.displayName),
    avatarId: requireIdentifier(source.avatarId, "avatarId", 64),
    profileSchemaVersion: requireInteger(
      source.profileSchemaVersion,
      "profileSchemaVersion",
      1,
      1000,
    ),
    hasLocalProgress: source.hasLocalProgress === true,
    profileType,
    childAgeGroup: profileType === "child" ? childAgeGroup : null,
  };
}

function validateMigrationSnapshot(data) {
  const source = requireApiVersion(data);
  const profile = requireObject(source.profile, "profile");
  const passport = requireObject(source.passport, "passport");
  return {
    localPlayerId: requireIdentifier(source.localPlayerId, "localPlayerId"),
    profile: {
      schemaVersion: requireInteger(
        profile.schemaVersion,
        "profile.schemaVersion",
        1,
        1000,
      ),
      totalXp: requireInteger(profile.totalXp, "profile.totalXp", 0, 1000000000),
      gamesPlayed: requireInteger(
        profile.gamesPlayed,
        "profile.gamesPlayed",
        0,
        100000000,
      ),
      correctAnswers: requireInteger(
        profile.correctAnswers,
        "profile.correctAnswers",
        0,
        1000000000,
      ),
      totalAnswers: requireInteger(
        profile.totalAnswers,
        "profile.totalAnswers",
        0,
        1000000000,
      ),
      totalScore: requireInteger(
        profile.totalScore,
        "profile.totalScore",
        0,
        1000000000000,
      ),
      totalDistanceInKilometers: requireNumber(
        profile.totalDistanceInKilometers,
        "profile.totalDistanceInKilometers",
        0,
        1000000000000,
      ),
      totalElapsedSeconds: requireInteger(
        profile.totalElapsedSeconds,
        "profile.totalElapsedSeconds",
        0,
        1000000000000,
      ),
      createdAt: optionalIsoDate(profile.createdAt, "profile.createdAt"),
      lastPlayedAt: optionalIsoDate(
        profile.lastPlayedAt,
        "profile.lastPlayedAt",
      ),
    },
    passport: {
      schemaVersion: requireInteger(
        passport.schemaVersion,
        "passport.schemaVersion",
        1,
        1000,
      ),
      currentLicenseId: requireInteger(
        passport.currentLicenseId,
        "passport.currentLicenseId",
        1,
        1000,
      ),
      totalAttempts: requireInteger(
        passport.totalAttempts,
        "passport.totalAttempts",
        0,
        100000000,
      ),
      validatedStampCount: requireInteger(
        passport.validatedStampCount,
        "passport.validatedStampCount",
        0,
        100000,
      ),
    },
  };
}

function validateOfficialSessionRequest(data) {
  const source = requireApiVersion(data);
  const competitiveSignature = typeof source.competitiveSignature === "string" ?
    source.competitiveSignature.trim() : "";
  if (competitiveSignature.length === 0 || competitiveSignature.length > 1024) {
    throw new TypeError("competitiveSignature est invalide.");
  }
  return {
    launchId: requireIdentifier(source.launchId, "launchId"),
    challengeId: requireIdentifier(source.challengeId, "challengeId"),
    rankingGroupId: requireIdentifier(
      source.rankingGroupId,
      "rankingGroupId",
    ),
    competitiveSignature,
  };
}

function validateAnswerEvidence(value, index) {
  const source = requireObject(value, `answerEvidence[${index}]`);
  const distance = source.distanceInKilometers == null ? null :
    requireNumber(
      source.distanceInKilometers,
      `answerEvidence[${index}].distanceInKilometers`,
      0,
      25000,
    );
  if (typeof source.isCorrect !== "boolean") {
    throw new TypeError(`answerEvidence[${index}].isCorrect est invalide.`);
  }
  return {
    modeId: requireIdentifier(
      source.modeId,
      `answerEvidence[${index}].modeId`,
      32,
    ),
    isCorrect: source.isCorrect,
    elapsedSeconds: requireInteger(
      source.elapsedSeconds,
      `answerEvidence[${index}].elapsedSeconds`,
      0,
      300,
    ),
    distanceInKilometers: distance,
  };
}

function validateRankingSubmission(value, index) {
  const source = requireObject(value, `submissions[${index}]`);
  const evidence = source.answerEvidence;
  if (!Array.isArray(evidence) || evidence.length < 1 || evidence.length > 50) {
    throw new TypeError(`submissions[${index}].answerEvidence est invalide.`);
  }
  const competitiveSignature = typeof source.competitiveSignature === "string" ?
    source.competitiveSignature.trim() : "";
  if (competitiveSignature.length === 0 || competitiveSignature.length > 1024) {
    throw new TypeError(
      `submissions[${index}].competitiveSignature est invalide.`,
    );
  }
  const completedAtUtc = optionalIsoDate(
    source.completedAtUtc,
    `submissions[${index}].completedAtUtc`,
  );
  if (completedAtUtc === null) {
    throw new TypeError(`submissions[${index}].completedAtUtc est invalide.`);
  }
  return {
    playerId: requireIdentifier(source.playerId, `submissions[${index}].playerId`),
    submissionId: requireDocumentId(
      source.submissionId,
      `submissions[${index}].submissionId`,
    ),
    officialSessionId: requireIdentifier(
      source.officialSessionId,
      `submissions[${index}].officialSessionId`,
    ),
    challengeId: requireIdentifier(
      source.challengeId,
      `submissions[${index}].challengeId`,
    ),
    rankingGroupId: requireIdentifier(
      source.rankingGroupId,
      `submissions[${index}].rankingGroupId`,
    ),
    attemptNumber: requireInteger(
      source.attemptNumber,
      `submissions[${index}].attemptNumber`,
      1,
      1000000,
    ),
    competitiveSignature,
    completedAtUtc,
    score: requireInteger(source.score, `submissions[${index}].score`, 0, 6000),
    correctAnswers: requireInteger(
      source.correctAnswers,
      `submissions[${index}].correctAnswers`,
      0,
      50,
    ),
    averageDistanceKilometers: requireNumber(
      source.averageDistanceKilometers,
      `submissions[${index}].averageDistanceKilometers`,
      0,
      25000,
    ),
    elapsedSeconds: requireInteger(
      source.elapsedSeconds,
      `submissions[${index}].elapsedSeconds`,
      0,
      15000,
    ),
    answerEvidence: evidence.map(validateAnswerEvidence),
  };
}

function validateRankingSubmissionBatch(data) {
  const source = requireApiVersion(data);
  if (!Array.isArray(source.submissions) ||
      source.submissions.length < 1 || source.submissions.length > 10) {
    throw new TypeError("submissions doit contenir entre 1 et 10 résultats.");
  }
  return source.submissions.map(validateRankingSubmission);
}

function validateLeaderboardRequest(data) {
  const source = requireApiVersion(data);
  if (!Array.isArray(source.rankingGroupIds) ||
      source.rankingGroupIds.length > 50) {
    throw new TypeError("rankingGroupIds doit contenir au plus 50 éléments.");
  }
  const rankingGroupIds = source.rankingGroupIds.map((value, index) =>
    requireIdentifier(value, `rankingGroupIds[${index}]`));
  const seasonKey = typeof source.seasonKey === "string" ?
    source.seasonKey.trim() : "";
  const seasonParts = /^(\d{4})-(\d{2})$/.exec(seasonKey);
  const seasonMonth = seasonParts ? Number(seasonParts[2]) : 0;
  if (!seasonParts || seasonMonth < 1 || seasonMonth > 12) {
    throw new TypeError("seasonKey est invalide.");
  }
  const scope = source.scope == null ? "global" : source.scope;
  if (scope !== "global" && scope !== "friends") {
    throw new TypeError("scope est invalide.");
  }
  return {rankingGroupIds, seasonKey, scope};
}

function validateFriendCodeRequest(data) {
  const source = requireApiVersion(data);
  return {friendCode: normalizeFriendCode(source.friendCode)};
}

function validateFriendRelationRequest(data) {
  const source = requireApiVersion(data);
  const action = typeof source.action === "string" ? source.action.trim() : "";
  const requestActions = new Set(["accept", "decline", "cancel"]);
  const playerActions = new Set(["remove", "block", "unblock"]);
  if (!requestActions.has(action) && !playerActions.has(action)) {
    throw new TypeError("action est invalide.");
  }
  return requestActions.has(action) ? {
    action,
    requestId: requireDocumentId(source.requestId, "requestId", 64),
    playerId: null,
  } : {
    action,
    requestId: null,
    playerId: requireIdentifier(source.playerId, "playerId", 128),
  };
}

function validateSeasonRewardRequest(data) {
  const source = requireApiVersion(data);
  const seasonKey = typeof source.seasonKey === "string" ?
    source.seasonKey.trim() : "";
  const seasonParts = /^(\d{4})-(\d{2})$/.exec(seasonKey);
  const seasonYear = seasonParts ? Number(seasonParts[1]) : 0;
  const seasonMonth = seasonParts ? Number(seasonParts[2]) : 0;
  if (!seasonParts || seasonYear < 2020 || seasonYear > 2200 ||
      seasonMonth < 1 || seasonMonth > 12) {
    throw new TypeError("seasonKey est invalide.");
  }
  return {seasonKey};
}

function validateChallengeRewardBatch(data) {
  const source = requireApiVersion(data);
  if (!Array.isArray(source.claims) || source.claims.length > 50) {
    throw new TypeError("claims est invalide.");
  }
  const seenClaimIds = new Set();
  const claims = source.claims.map((rawClaim, index) => {
    const claim = requireObject(rawClaim, `claims[${index}]`);
    const claimId = requireDocumentId(
      claim.claimId,
      `claims[${index}].claimId`,
      256,
    );
    if (seenClaimIds.has(claimId)) {
      throw new TypeError("Un claimId de récompense est présent deux fois.");
    }
    seenClaimIds.add(claimId);
    return {
      claimId,
      challengeId: requireIdentifier(
        claim.challengeId,
        `claims[${index}].challengeId`,
      ),
      claimedAtUtc: optionalIsoDate(
        claim.claimedAtUtc,
        `claims[${index}].claimedAtUtc`,
      ),
      attemptsUsed: requireInteger(
        claim.attemptsUsed,
        `claims[${index}].attemptsUsed`,
        1,
        100000,
      ),
      rewardedAdvertisementRetriesUsed: requireInteger(
        claim.rewardedAdvertisementRetriesUsed,
        `claims[${index}].rewardedAdvertisementRetriesUsed`,
        0,
        100000,
      ),
      bestScore: requireInteger(
        claim.bestScore,
        `claims[${index}].bestScore`,
        0,
        1000000000,
      ),
      bestCorrectAnswers: requireInteger(
        claim.bestCorrectAnswers,
        `claims[${index}].bestCorrectAnswers`,
        0,
        100000,
      ),
    };
  });
  return {claims};
}

function requireAdminReason(value) {
  const normalized = typeof value === "string" ?
    value.trim().replace(/\s+/g, " ") : "";
  if (normalized.length < 5 || normalized.length > 300 ||
      CONTROL_CHARACTER_PATTERN.test(normalized)) {
    throw new TypeError("reason est invalide.");
  }
  return normalized;
}

function validateAdminDashboardRequest(data) {
  const source = requireApiVersion(data);
  const query = typeof source.query === "string" ? source.query.trim() : "";
  if (query.length > 128 || query.includes("/") ||
      CONTROL_CHARACTER_PATTERN.test(query)) {
    throw new TypeError("query est invalide.");
  }
  return {
    query,
    limit: source.limit == null ? 30 :
      requireInteger(source.limit, "limit", 1, 50),
  };
}

function validateAdminScoreActionRequest(data) {
  const source = requireApiVersion(data);
  const allowed = new Set([
    "approve_quarantine",
    "reject_quarantine",
    "invalidate",
    "restore",
    "restore_expired",
  ]);
  const action = typeof source.action === "string" ? source.action.trim() : "";
  if (!allowed.has(action)) throw new TypeError("action est invalide.");
  return {
    action,
    playerId: requireIdentifier(source.playerId, "playerId", 128),
    submissionId: requireDocumentId(source.submissionId, "submissionId", 256),
    reason: requireAdminReason(source.reason),
  };
}

function validateAdminCompetitionRequest(data) {
  const source = requireApiVersion(data);
  const action = typeof source.action === "string" ? source.action.trim() : "";
  if (action !== "enable" && action !== "disable" && action !== "rebuild") {
    throw new TypeError("action est invalide.");
  }
  return {
    action,
    rankingGroupId: requireIdentifier(
      source.rankingGroupId,
      "rankingGroupId",
      128,
    ),
    reason: requireAdminReason(source.reason),
  };
}

module.exports = {
  requireApiVersion,
  requireDisplayName,
  requireIdentifier,
  validateAdminCompetitionRequest,
  validateAdminDashboardRequest,
  validateAdminScoreActionRequest,
  validateChallengeRewardBatch,
  validateFriendCodeRequest,
  validateFriendRelationRequest,
  validateLeaderboardRequest,
  validateIdentityRegistration,
  validateMigrationSnapshot,
  validateOfficialSessionRequest,
  validateRankingSubmissionBatch,
  validateSeasonRewardRequest,
};
