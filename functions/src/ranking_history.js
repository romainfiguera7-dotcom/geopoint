"use strict";

function normalizedStatus(record) {
  switch (record.status) {
    case "validated":
    case "validated_pending_identity":
      return "validated";
    case "quarantined":
      return "quarantined";
    default:
      return "rejected";
  }
}

function publicRankingHistoryEntry(record, challengeTitles = {}) {
  if (!record || typeof record !== "object") return null;
  const submissionId = typeof record.submissionId === "string" ?
    record.submissionId.trim() : "";
  const challengeId = typeof record.challengeId === "string" ?
    record.challengeId.trim() : "";
  const completedAtUtc = typeof record.completedAtUtc === "string" ?
    record.completedAtUtc.trim() : "";
  if (submissionId.length === 0 || challengeId.length === 0 ||
      Number.isNaN(Date.parse(completedAtUtc))) {
    return null;
  }
  const reason = typeof record.clientReason === "string" &&
    record.clientReason.trim().length > 0 ? record.clientReason.trim() : null;
  return {
    submissionId,
    challengeId,
    challengeTitle: typeof challengeTitles[challengeId] === "string" ?
      challengeTitles[challengeId] : "Défi PointGeo",
    completedAtUtc: new Date(completedAtUtc).toISOString(),
    score: Number.isSafeInteger(record.score) && record.score >= 0 ?
      record.score : 0,
    correctAnswers: Number.isSafeInteger(record.correctAnswers) &&
      record.correctAnswers >= 0 ? record.correctAnswers : 0,
    elapsedSeconds: Number.isSafeInteger(record.elapsedSeconds) &&
      record.elapsedSeconds >= 0 ? record.elapsedSeconds : 0,
    status: normalizedStatus(record),
    isBest: record.isBest === true,
    reason,
  };
}

function buildPublicRankingHistory(records, challengeTitles = {}, limit = 20) {
  return records
    .map((record) => publicRankingHistoryEntry(record, challengeTitles))
    .filter((entry) => entry !== null)
    .sort((left, right) =>
      Date.parse(right.completedAtUtc) - Date.parse(left.completedAtUtc))
    .slice(0, limit);
}

module.exports = {
  buildPublicRankingHistory,
  publicRankingHistoryEntry,
};
