"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  QUARANTINE_THRESHOLD,
  evaluateRankedAttempt,
} = require("../src/anti_cheat");

const rules = {
  modeId: "find_country",
  difficultyId: "intermediate",
  questionCount: 10,
  questionDurationSeconds: 17,
};

function evaluation(answerEvidence, overrides = {}) {
  const score = overrides.score ?? 0;
  const correctAnswers = overrides.correctAnswers ?? 0;
  const elapsedSeconds = overrides.elapsedSeconds ?? answerEvidence.reduce(
    (total, answer) => total + answer.elapsedSeconds,
    0,
  );
  return evaluateRankedAttempt({
    submission: {answerEvidence},
    recalculated: {
      score,
      correctAnswers,
      elapsedSeconds,
      averageDistanceKilometers: 0,
    },
    rules: overrides.rules ?? rules,
    sessionAgeSeconds: overrides.sessionAgeSeconds ?? 120,
  });
}

test("laisse passer une excellente partie humaine", () => {
  const answers = Array.from({length: 10}, (_, index) => ({
    modeId: "find_country",
    isCorrect: index < 9,
    elapsedSeconds: 3 + (index % 5),
    ...(index === 9 ? {distanceInKilometers: 240} : {}),
  }));
  const result = evaluation(answers, {
    score: 1080,
    correctAnswers: 9,
  });
  assert.equal(result.decision, "allow");
  assert.equal(result.riskScore, 0);
});

test("ne sanctionne jamais une seule réponse instantanée", () => {
  const answers = Array.from({length: 10}, (_, index) => ({
    modeId: "find_country",
    isCorrect: true,
    elapsedSeconds: index === 0 ? 0 : 5,
  }));
  const result = evaluation(answers, {
    score: 1100,
    correctAnswers: 10,
  });
  assert.equal(result.decision, "allow");
});

test("met en quarantaine un score maximal automatisé", () => {
  const answers = Array.from({length: 10}, () => ({
    modeId: "find_country",
    isCorrect: true,
    elapsedSeconds: 1,
  }));
  const result = evaluation(answers, {
    score: 1200,
    correctAnswers: 10,
  });
  assert.equal(result.decision, "quarantine");
  assert.ok(result.riskScore >= QUARANTINE_THRESHOLD);
  assert.ok(result.signals.some(
    (signal) => signal.code === "maximum_score_speed_burst",
  ));
});

test("met en quarantaine des capitales parfaites répétées", () => {
  const answers = Array.from({length: 6}, () => ({
    modeId: "find_capital",
    isCorrect: true,
    elapsedSeconds: 2,
    distanceInKilometers: 0.02,
  }));
  const result = evaluation(answers, {
    score: 720,
    correctAnswers: 6,
    rules: {
      modeId: "find_capital",
      difficultyId: "intermediate",
      questionCount: 6,
      questionDurationSeconds: 17,
    },
  });
  assert.equal(result.decision, "quarantine");
  assert.ok(result.signals.some(
    (signal) => signal.code === "repeated_instant_pinpoint_capitals",
  ));
});

test("détecte un temps total impossible pour l'âge de la session", () => {
  const answers = Array.from({length: 10}, () => ({
    modeId: "find_country",
    isCorrect: false,
    elapsedSeconds: 10,
    distanceInKilometers: 1000,
  }));
  const result = evaluation(answers, {
    elapsedSeconds: 100,
    sessionAgeSeconds: 20,
  });
  assert.equal(result.decision, "quarantine");
  assert.ok(result.signals.some(
    (signal) => signal.code === "elapsed_exceeds_session_age",
  ));
});
