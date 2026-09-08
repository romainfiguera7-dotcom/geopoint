"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  requireApiVersion,
  requireDisplayName,
  requireIdentifier,
  validateAdminCompetitionRequest,
  validateAdminDashboardRequest,
  validateAdminScoreActionRequest,
  validateChallengeRewardBatch,
  validateFriendCodeRequest,
  validateFriendRelationRequest,
  validateIdentityRegistration,
  validateLeaderboardRequest,
  validateMigrationSnapshot,
  validateOfficialSessionRequest,
  validateRankingSubmissionBatch,
  validateSeasonRewardRequest,
} = require("../src/validation");

test("borne les commandes du contrôle interne", () => {
  assert.deepEqual(validateAdminDashboardRequest({
    apiVersion: 1,
    query: " submission_01 ",
    limit: 20,
  }), {query: "submission_01", limit: 20});
  assert.equal(validateAdminScoreActionRequest({
    apiVersion: 1,
    action: "invalidate",
    playerId: "player_01",
    submissionId: "ranking:daily:1",
    reason: "Contrôle manuel du score",
  }).action, "invalidate");
  assert.equal(validateAdminScoreActionRequest({
    apiVersion: 1,
    action: "restore_expired",
    playerId: "player_01",
    submissionId: "ranking:daily:2",
    reason: "Correction de l’ancien contrôle d’expiration",
  }).action, "restore_expired");
  assert.equal(validateAdminCompetitionRequest({
    apiVersion: 1,
    action: "rebuild",
    rankingGroupId: "daily_01",
    reason: "Recalcul demandé après contrôle",
  }).action, "rebuild");
});

test("accepte une inscription joueur valide", () => {
  const value = validateIdentityRegistration({
    apiVersion: 1,
    localPlayerId: "player_001",
    displayName: "  Malo   Explorer  ",
    avatarId: "default",
    profileSchemaVersion: 5,
    hasLocalProgress: true,
  });
  assert.equal(value.displayName, "Malo Explorer");
  assert.equal(value.hasLocalProgress, true);
  assert.equal(value.profileType, "adult");
});

test("exige une tranche d'âge pour un profil enfant", () => {
  assert.throws(() => validateIdentityRegistration({
    apiVersion: 1,
    localPlayerId: "child_001",
    displayName: "Petit explorateur",
    avatarId: "default",
    profileSchemaVersion: 6,
    hasLocalProgress: false,
    profileType: "child",
  }), /childAgeGroup/);
  const value = validateIdentityRegistration({
    apiVersion: 1,
    localPlayerId: "child_001",
    displayName: "Petit explorateur",
    avatarId: "default",
    profileSchemaVersion: 6,
    hasLocalProgress: false,
    profileType: "child",
    childAgeGroup: "6_8",
  });
  assert.equal(value.profileType, "child");
  assert.equal(value.childAgeGroup, "6_8");
});

test("refuse un identifiant pouvant modifier un chemin Firestore", () => {
  assert.throws(
    () => requireIdentifier("../players/admin", "playerId"),
    /invalide/,
  );
});

test("refuse une version de contrat inconnue", () => {
  assert.throws(() => requireApiVersion({apiVersion: 99}), /Version/);
});

test("limite le nom public du joueur", () => {
  assert.throws(() => requireDisplayName("x"), /invalide/);
  assert.throws(() => requireDisplayName("x".repeat(25)), /invalide/);
});

test("valide une photographie de migration bornée", () => {
  const value = validateMigrationSnapshot({
    apiVersion: 1,
    localPlayerId: "player_001",
    profile: {
      schemaVersion: 5,
      totalXp: 1250,
      gamesPlayed: 12,
      correctAnswers: 40,
      totalAnswers: 60,
      totalScore: 5400,
      totalDistanceInKilometers: 1200.5,
      totalElapsedSeconds: 3600,
      createdAt: "2026-01-01T00:00:00.000Z",
      lastPlayedAt: "2026-09-01T00:00:00.000Z",
    },
    passport: {
      schemaVersion: 1,
      currentLicenseId: 3,
      totalAttempts: 15,
      validatedStampCount: 4,
    },
  });
  assert.equal(value.profile.totalXp, 1250);
  assert.equal(value.passport.currentLicenseId, 3);
});

test("refuse une progression négative", () => {
  assert.throws(
    () => validateMigrationSnapshot({
      apiVersion: 1,
      localPlayerId: "player_001",
      profile: {
        schemaVersion: 5,
        totalXp: -1,
        gamesPlayed: 0,
        correctAnswers: 0,
        totalAnswers: 0,
        totalScore: 0,
        totalDistanceInKilometers: 0,
        totalElapsedSeconds: 0,
      },
      passport: {
        schemaVersion: 1,
        currentLicenseId: 1,
        totalAttempts: 0,
        validatedStampCount: 0,
      },
    }),
    /totalXp/,
  );
});

test("valide une demande de session officielle bornée", () => {
  const value = validateOfficialSessionRequest({
    apiVersion: 1,
    launchId: "launch_123_1",
    challengeId: "weekly_01",
    rankingGroupId: "weekly_01",
    competitiveSignature: "find_country|intermediate|europe",
  });
  assert.equal(value.challengeId, "weekly_01");
  assert.throws(
    () => validateOfficialSessionRequest({
      apiVersion: 1,
      launchId: "../admin",
      challengeId: "weekly_01",
      rankingGroupId: "weekly_01",
      competitiveSignature: "signature",
    }),
    /launchId/,
  );
});

test("valide un lot de résultats classés avec ses preuves", () => {
  const results = validateRankingSubmissionBatch({
    apiVersion: 1,
    submissions: [{
      playerId: "firebase_uid_test",
      submissionId: "ranking:weekly_01:attempt:1",
      officialSessionId: "cs_test",
      challengeId: "weekly_01",
      rankingGroupId: "weekly_01",
      attemptNumber: 1,
      competitiveSignature: "find_country|intermediate|europe",
      completedAtUtc: "2026-09-05T12:05:00.000Z",
      score: 120,
      correctAnswers: 1,
      averageDistanceKilometers: 0,
      elapsedSeconds: 3,
      answerEvidence: [{
        modeId: "find_country",
        isCorrect: true,
        elapsedSeconds: 3,
      }],
    }],
  });
  assert.equal(results[0].submissionId, "ranking:weekly_01:attempt:1");
  assert.equal(results[0].answerEvidence[0].modeId, "find_country");
});

test("refuse un résultat classé sans session ni preuve", () => {
  assert.throws(
    () => validateRankingSubmissionBatch({
      apiVersion: 1,
      submissions: [{playerId: "firebase_uid_test"}],
    }),
    /answerEvidence/,
  );
});

test("valide une demande de classements bornée", () => {
  const request = validateLeaderboardRequest({
    apiVersion: 1,
    rankingGroupIds: ["daily_2026_09_05", "weekly_01"],
    seasonKey: "2026-09",
    scope: "friends",
  });
  assert.equal(request.rankingGroupIds.length, 2);
  assert.equal(request.seasonKey, "2026-09");
  assert.equal(request.scope, "friends");
});

test("valide un code ami et les actions de relation", () => {
  assert.equal(validateFriendCodeRequest({
    apiVersion: 1,
    friendCode: "gp-abcd-2345",
  }).friendCode, "GPABCD2345");
  assert.equal(validateFriendRelationRequest({
    apiVersion: 1,
    action: "accept",
    requestId: "request_1",
  }).requestId, "request_1");
  assert.equal(validateFriendRelationRequest({
    apiVersion: 1,
    action: "block",
    playerId: "uid_friend",
  }).playerId, "uid_friend");
});

test("refuse une saison de classement invalide", () => {
  assert.throws(
    () => validateLeaderboardRequest({
      apiVersion: 1,
      rankingGroupIds: [],
      seasonKey: "septembre",
    }),
    /seasonKey/,
  );
});

test("valide une demande de récompense de saison", () => {
  assert.deepEqual(
    validateSeasonRewardRequest({apiVersion: 1, seasonKey: "2026-09"}),
    {seasonKey: "2026-09"},
  );
  assert.throws(
    () => validateSeasonRewardRequest({apiVersion: 1, seasonKey: "2019-12"}),
    /seasonKey/,
  );
});

test("valide un lot de récompenses de défis", () => {
  const request = validateChallengeRewardBatch({
    apiVersion: 1,
    claims: [{
      claimId: "daily_2026_09_08@2026-09-08T00:00:00.000Z",
      challengeId: "daily_2026_09_08",
      claimedAtUtc: "2026-09-08T12:00:00.000Z",
      attemptsUsed: 1,
      rewardedAdvertisementRetriesUsed: 0,
      bestScore: 420,
      bestCorrectAnswers: 5,
      rewardSnapshot: {coins: 25},
    }],
  });
  assert.equal(request.claims.length, 1);
  assert.equal(request.claims[0].bestScore, 420);
  assert.throws(() => validateChallengeRewardBatch({
    apiVersion: 1,
    claims: [
      {
        claimId: "duplicate",
        challengeId: "daily_a",
        claimedAtUtc: "2026-09-08T12:00:00.000Z",
        attemptsUsed: 1,
        rewardedAdvertisementRetriesUsed: 0,
        bestScore: 10,
        bestCorrectAnswers: 1,
      },
      {
        claimId: "duplicate",
        challengeId: "daily_b",
        claimedAtUtc: "2026-09-08T12:00:00.000Z",
        attemptsUsed: 1,
        rewardedAdvertisementRetriesUsed: 0,
        bestScore: 10,
        bestCorrectAnswers: 1,
      },
    ],
  }), /deux fois/);
});
