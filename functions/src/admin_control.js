"use strict";

const {comparePerformance, recalculatePerformance} =
  require("./score_validation");

const REVIEWABLE_STATUS = new Set(["quarantined"]);
const PUBLISHED_STATUS = new Set([
  "validated",
  "validated_manual",
  "validated_pending_identity",
]);

function scoreActionTransition(status, action) {
  if (action === "approve_quarantine" && REVIEWABLE_STATUS.has(status)) {
    return "validated_manual";
  }
  if (action === "reject_quarantine" && REVIEWABLE_STATUS.has(status)) {
    return "rejected_manual";
  }
  if (action === "invalidate" && PUBLISHED_STATUS.has(status)) {
    return "invalidated_manual";
  }
  if (action === "restore" && status === "invalidated_manual") {
    return "validated_manual";
  }
  if (action === "restore_expired" && status === "rejected") {
    return "validated_manual";
  }
  throw new RangeError(`Transition ${status}/${action} impossible.`);
}

function candidateFromSubmission(submission, session) {
  const recalculated = submission.recalculated ||
    recalculatePerformance(submission, session.scoringRules);
  return {
    submissionId: submission.submissionId,
    challengeId: submission.challengeId,
    rankingGroupId: submission.rankingGroupId,
    officialSessionId: submission.officialSessionId,
    attemptNumber: submission.attemptNumber,
    completedAtUtc: submission.completedAtUtc,
    ...recalculated,
    rankingEligible: session.rankingEligible === true,
    migrationStatus: session.migrationStatus,
    challengePeriod: session.challengePeriod || "daily",
    seasonKey: session.seasonKey ||
      String(submission.completedAtUtc).slice(0, 7),
  };
}

function bestRecordsByGroup(records) {
  const best = new Map();
  for (const record of records) {
    if (record.rankingEligible !== true) continue;
    const previous = best.get(record.rankingGroupId);
    if (!previous || comparePerformance(record, previous) > 0) {
      best.set(record.rankingGroupId, record);
    }
  }
  return best;
}

function auditRecord({actorUid, action, target, reason, before, after, now}) {
  return {
    actorUid,
    action,
    target,
    reason,
    before,
    after,
    createdAtUtc: now.toISOString(),
  };
}

module.exports = {
  PUBLISHED_STATUS,
  auditRecord,
  bestRecordsByGroup,
  candidateFromSubmission,
  scoreActionTransition,
};
