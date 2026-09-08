"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  challengeEntry,
  leaderboardSortKey,
  publicProfile,
  rankedEntries,
  seasonBoardId,
  seasonEntry,
} = require("../src/leaderboard");

const first = {
  submissionId: "first",
  challengeId: "daily_01",
  rankingGroupId: "daily_01",
  score: 450,
  correctAnswers: 4,
  averageDistanceKilometers: 80,
  elapsedSeconds: 45,
  completedAtUtc: "2026-09-05T12:00:00.000Z",
};

test("masque un pseudonyme qui attend la modération", () => {
  const entry = challengeEntry(
    "firebase_uid_1234",
    first,
    {displayName: "Nom en attente", avatarId: "atlas"},
    "daily",
    "2026-09",
  );
  assert.equal(entry.displayName, "Explorateur 1234");
  assert.equal(entry.avatarId, "atlas");
});

test("ne publie jamais le pseudonyme d'un profil enfant", () => {
  const profile = publicProfile({
    moderationStatus: "approved",
    displayName: "Prénom enfant",
    avatarId: "atlas",
    isChild: true,
  }, "firebase_uid_5678");
  assert.equal(profile.displayName, "Explorateur 5678");
});

test("additionne uniquement les meilleurs scores de la saison", () => {
  const firstSeason = seasonEntry(
    "uid_a",
    null,
    "daily_01",
    first,
    {moderationStatus: "approved", displayName: "Romain"},
    "2026-09",
  );
  const secondSeason = seasonEntry(
    "uid_a",
    firstSeason,
    "weekly_01",
    {...first, score: 900, challengeId: "weekly_01"},
    {moderationStatus: "approved", displayName: "Romain"},
    "2026-09",
  );
  const improved = seasonEntry(
    "uid_a",
    secondSeason,
    "daily_01",
    {...first, score: 500},
    {moderationStatus: "approved", displayName: "Romain"},
    "2026-09",
  );
  assert.equal(improved.score, 1400);
  assert.equal(improved.challengeCount, 2);
});

test("départage par score, précision puis temps", () => {
  const ranked = rankedEntries([
    {...first, uid: "b", displayName: "B", avatarId: "default"},
    {
      ...first,
      uid: "a",
      displayName: "A",
      avatarId: "default",
      averageDistanceKilometers: 70,
    },
    {
      ...first,
      uid: "c",
      displayName: "C",
      avatarId: "default",
      score: 600,
    },
  ], "a");
  assert.deepEqual(ranked.map((entry) => entry.displayName), ["C", "A", "B"]);
  assert.equal(ranked[1].isCurrentPlayer, true);
});

test("normalise l'identifiant de saison", () => {
  assert.equal(seasonBoardId("2026-09"), "season_2026_09");
});

test("fabrique une clé de tri stable selon le départage officiel", () => {
  const betterScore = leaderboardSortKey({...first, uid: "a", score: 500});
  const lowerScore = leaderboardSortKey({...first, uid: "b", score: 450});
  const precise = leaderboardSortKey({
    ...first,
    uid: "c",
    score: 450,
    averageDistanceKilometers: 70,
  });
  assert.ok(betterScore < lowerScore);
  assert.ok(precise < lowerScore);
});
