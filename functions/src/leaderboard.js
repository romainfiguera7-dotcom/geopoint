"use strict";

function publicProfile(profile, uid) {
  const suffix = uid.slice(-4).toUpperCase().padStart(4, "0");
  const protectedChild = profile && (
    profile.isChild === true ||
    profile.moderationStatus === "protected_child"
  );
  const approved = !protectedChild && profile &&
    profile.moderationStatus === "approved";
  return {
    displayName: approved && typeof profile.displayName === "string" ?
      profile.displayName : `Explorateur ${suffix}`,
    avatarId: profile && typeof profile.avatarId === "string" ?
      profile.avatarId : "default",
  };
}

function leaderboardSortKey(entry) {
  const invertedScore = 999999999 - Math.min(999999999, entry.score);
  const distance = Math.round(entry.averageDistanceKilometers * 1000);
  const elapsed = entry.elapsedSeconds;
  return [
    String(invertedScore).padStart(9, "0"),
    String(distance).padStart(11, "0"),
    String(elapsed).padStart(10, "0"),
    entry.uid,
  ].join("|");
}

function challengeEntry(uid, record, profile, period, seasonKey) {
  const entry = {
    uid,
    ...publicProfile(profile, uid),
    challengeId: record.challengeId,
    rankingGroupId: record.rankingGroupId,
    period,
    seasonKey,
    submissionId: record.submissionId,
    score: record.score,
    correctAnswers: record.correctAnswers,
    averageDistanceKilometers: record.averageDistanceKilometers,
    elapsedSeconds: record.elapsedSeconds,
    completedAtUtc: record.completedAtUtc,
  };
  return {...entry, sortKey: leaderboardSortKey(entry)};
}

function seasonEntry(uid, previous, groupId, record, profile, seasonKey) {
  const contributions = previous && previous.contributions &&
    typeof previous.contributions === "object" ?
    {...previous.contributions} : {};
  contributions[groupId] = {
    score: record.score,
    correctAnswers: record.correctAnswers,
    averageDistanceKilometers: record.averageDistanceKilometers,
    elapsedSeconds: record.elapsedSeconds,
    completedAtUtc: record.completedAtUtc,
  };
  const values = Object.values(contributions);
  const distanceTotal = values.reduce(
    (total, item) => total + item.averageDistanceKilometers,
    0,
  );
  const entry = {
    uid,
    ...publicProfile(profile, uid),
    seasonKey,
    score: values.reduce((total, item) => total + item.score, 0),
    correctAnswers: values.reduce(
      (total, item) => total + item.correctAnswers,
      0,
    ),
    averageDistanceKilometers: values.length === 0 ?
      0 : distanceTotal / values.length,
    elapsedSeconds: values.reduce(
      (total, item) => total + item.elapsedSeconds,
      0,
    ),
    challengeCount: values.length,
    contributions,
  };
  return {...entry, sortKey: leaderboardSortKey(entry)};
}

function compareLeaderboardEntries(left, right) {
  if (left.score !== right.score) return right.score - left.score;
  if (left.averageDistanceKilometers !== right.averageDistanceKilometers) {
    return left.averageDistanceKilometers - right.averageDistanceKilometers;
  }
  if (left.elapsedSeconds !== right.elapsedSeconds) {
    return left.elapsedSeconds - right.elapsedSeconds;
  }
  if (String(left.uid) < String(right.uid)) return -1;
  if (String(left.uid) > String(right.uid)) return 1;
  return 0;
}

function rankedEntries(entries, currentUid, limit = 50) {
  return [...entries]
    .sort(compareLeaderboardEntries)
    .slice(0, limit)
    .map((entry, index) => ({
      rank: index + 1,
      displayName: entry.displayName,
      avatarId: entry.avatarId,
      score: entry.score,
      correctAnswers: entry.correctAnswers,
      averageDistanceKilometers: entry.averageDistanceKilometers,
      elapsedSeconds: entry.elapsedSeconds,
      challengeCount: entry.challengeCount || 1,
      isCurrentPlayer: entry.uid === currentUid,
    }));
}

function seasonBoardId(seasonKey) {
  return `season_${seasonKey.replace("-", "_")}`;
}

module.exports = {
  challengeEntry,
  compareLeaderboardEntries,
  leaderboardSortKey,
  publicProfile,
  rankedEntries,
  seasonBoardId,
  seasonEntry,
};
