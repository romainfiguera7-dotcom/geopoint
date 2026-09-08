"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildPublicRankingHistory,
  publicRankingHistoryEntry,
} = require("../src/ranking_history");

test("publie uniquement les champs utiles de l'historique personnel", () => {
  const entry = publicRankingHistoryEntry({
    submissionId: "ranking:daily:attempt:2",
    challengeId: "daily_2026_09_07",
    completedAtUtc: "2026-09-07T08:00:00.000Z",
    score: 575,
    correctAnswers: 5,
    elapsedSeconds: 42,
    status: "validated",
    isBest: true,
    uid: "champ_prive",
  }, {daily_2026_09_07: "Mix mondial"});

  assert.deepEqual(entry, {
    submissionId: "ranking:daily:attempt:2",
    challengeId: "daily_2026_09_07",
    challengeTitle: "Mix mondial",
    completedAtUtc: "2026-09-07T08:00:00.000Z",
    score: 575,
    correctAnswers: 5,
    elapsedSeconds: 42,
    status: "validated",
    isBest: true,
    reason: null,
  });
});

test("trie et borne l'historique en conservant les refus", () => {
  const history = buildPublicRankingHistory([
    {
      submissionId: "old",
      challengeId: "weekly_01",
      completedAtUtc: "2026-09-06T08:00:00.000Z",
      status: "rejected",
      clientReason: "Session expirée.",
    },
    {
      submissionId: "new",
      challengeId: "weekly_01",
      completedAtUtc: "2026-09-07T08:00:00.000Z",
      status: "quarantined",
    },
  ], {weekly_01: "Tour d'Europe"}, 1);

  assert.equal(history.length, 1);
  assert.equal(history[0].submissionId, "new");
  assert.equal(history[0].status, "quarantined");
});
