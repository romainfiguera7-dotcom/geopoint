"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  bundledChallengePack,
  competitiveSignature,
  expandChallengePack,
  mergeBundledPermanentChallenges,
  rankedSubmissionTimingRejection,
  resolveOfficialChallenge,
  scoringRulesFor,
  sessionExpiry,
} = require("../src/challenge_session");

const weeklySignature = [
  "find_country",
  "intermediate",
  "europe",
  "",
  "15",
  "-",
  "11",
  "900",
  "-",
  "1",
  "false",
  "0",
  "0",
  "true",
  "0",
  "true",
].join("|");

test("déplie le catalogue officiel embarqué", () => {
  const challenges = expandChallengePack(bundledChallengePack());
  assert.ok(challenges.length >= 35);
  assert.ok(challenges.some((item) => item.id === "weekly_01"));
  const standard = challenges.filter((item) =>
    (item.audience || "standard") === "standard",
  );
  assert.ok(standard.every((item) => item.rankingGroupId === item.id));
  assert.ok(standard.every((item) => item.minimumPlayerLevel === 1));
  assert.ok(standard.every(
    (item) => item.geoBrainPersonalizationAllowed === false,
  ));
});

test("rend aussi le défi quotidien classé", () => {
  const daily = expandChallengePack(bundledChallengePack())
    .find((item) => item.id === "daily_2026_09_05");
  assert.equal(daily.rankingGroupId, daily.id);
  assert.equal(daily.minimumPlayerLevel, 1);
});

test("complète un ancien pack distant avec les défis permanents inclus", () => {
  const oldRemotePack = {
    ...bundledChallengePack(),
    challenges: [],
  };
  const completed = mergeBundledPermanentChallenges(oldRemotePack);
  const permanentIds = completed.challenges
    .filter((challenge) => challenge.period === "permanent")
    .map((challenge) => challenge.id);
  assert.deepEqual(permanentIds, [
    "permanent_world",
    "permanent_europe",
    "permanent_africa",
    "permanent_americas",
    "permanent_asia",
    "permanent_oceania",
  ]);
});

test("calcule la même signature compétitive que Flutter", () => {
  const challenge = expandChallengePack(bundledChallengePack())
    .find((item) => item.id === "weekly_01");
  assert.equal(competitiveSignature(challenge), weeklySignature);
});

test("autorise uniquement le défi classé actif et identique", () => {
  const input = {
    challengeId: "weekly_01",
    rankingGroupId: "weekly_01",
    competitiveSignature: weeklySignature,
  };
  const challenge = resolveOfficialChallenge(
    bundledChallengePack(),
    input,
    new Date("2026-09-05T12:00:00.000Z"),
  );
  assert.equal(challenge.id, "weekly_01");
  assert.throws(
    () => resolveOfficialChallenge(
      bundledChallengePack(),
      {...input, competitiveSignature: "truquée"},
      new Date("2026-09-05T12:00:00.000Z"),
    ),
    /configuration compétitive/,
  );
});

test("refuse un défi officiel expiré", () => {
  assert.throws(
    () => resolveOfficialChallenge(
      bundledChallengePack(),
      {
        challengeId: "weekly_01",
        rankingGroupId: "weekly_01",
        competitiveSignature: weeklySignature,
      },
      new Date("2026-09-10T12:00:00.000Z"),
    ),
    /n’est pas actif/,
  );
});

test("conserve un défi permanent actif après la fin du pack", () => {
  const permanent = expandChallengePack(bundledChallengePack())
    .find((item) => item.id === "permanent_europe");
  const challenge = resolveOfficialChallenge(
    bundledChallengePack(),
    {
      challengeId: permanent.id,
      rankingGroupId: permanent.rankingGroupId,
      competitiveSignature: competitiveSignature(permanent),
    },
    new Date("2027-03-15T12:00:00.000Z"),
  );
  assert.equal(challenge.id, "permanent_europe");
  assert.equal(
    sessionExpiry(challenge, new Date("2027-03-15T12:00:00.000Z"))
      .toISOString(),
    "2027-03-15T12:45:00.000Z",
  );
});

test("borne une session à 45 minutes et à la fin du défi", () => {
  const challenge = {validUntilUtc: "2026-09-05T12:30:00.000Z"};
  assert.equal(
    sessionExpiry(challenge, new Date("2026-09-05T12:00:00.000Z"))
      .toISOString(),
    "2026-09-05T12:30:00.000Z",
  );
});

test("accepte une partie envoyée après la fin de sa session", () => {
  assert.equal(
    rankedSubmissionTimingRejection({
      startedAtUtc: "2026-09-07T12:00:00.000Z",
      expiresAtUtc: "2026-09-07T12:45:00.000Z",
      completedAtUtc: "2026-09-07T12:02:00.000Z",
    }),
    null,
  );
});

test("refuse une partie terminée après la fin de sa session", () => {
  assert.match(
    rankedSubmissionTimingRejection({
      startedAtUtc: "2026-09-07T12:00:00.000Z",
      expiresAtUtc: "2026-09-07T12:45:00.000Z",
      completedAtUtc: "2026-09-07T12:48:00.000Z",
    }),
    /expiré/,
  );
});

test("fige le barème dans la session officielle", () => {
  assert.deepEqual(
    scoringRulesFor({
      modeId: "find_country",
      difficultyId: "intermediate",
      questionCount: 15,
    }),
    {
      modeId: "find_country",
      difficultyId: "intermediate",
      questionCount: 15,
      questionDurationSeconds: 17,
    },
  );
});
