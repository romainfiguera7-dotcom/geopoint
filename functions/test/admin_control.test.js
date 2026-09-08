"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  auditRecord,
  bestRecordsByGroup,
  scoreActionTransition,
} = require("../src/admin_control");

test("encadre les transitions manuelles d'un score", () => {
  assert.equal(
    scoreActionTransition("quarantined", "approve_quarantine"),
    "validated_manual",
  );
  assert.equal(
    scoreActionTransition("validated", "invalidate"),
    "invalidated_manual",
  );
  assert.equal(
    scoreActionTransition("invalidated_manual", "restore"),
    "validated_manual",
  );
  assert.equal(
    scoreActionTransition("rejected", "restore_expired"),
    "validated_manual",
  );
  assert.throws(
    () => scoreActionTransition("rejected", "restore"),
    /impossible/,
  );
});

test("reconstruit le meilleur score de chaque compétition", () => {
  const best = bestRecordsByGroup([
    {rankingGroupId: "daily", rankingEligible: true, score: 100,
      averageDistanceKilometers: 20, elapsedSeconds: 12},
    {rankingGroupId: "daily", rankingEligible: true, score: 120,
      averageDistanceKilometers: 40, elapsedSeconds: 20},
    {rankingGroupId: "weekly", rankingEligible: false, score: 500,
      averageDistanceKilometers: 0, elapsedSeconds: 1},
  ]);
  assert.equal(best.get("daily").score, 120);
  assert.equal(best.has("weekly"), false);
});

test("fabrique une trace d'audit complète", () => {
  const record = auditRecord({
    actorUid: "admin_uid",
    action: "invalidate",
    target: "uid/submission",
    reason: "Score manifestement incorrect",
    before: "validated",
    after: "invalidated_manual",
    now: new Date("2026-09-07T12:00:00.000Z"),
  });
  assert.equal(record.actorUid, "admin_uid");
  assert.equal(record.createdAtUtc, "2026-09-07T12:00:00.000Z");
});
