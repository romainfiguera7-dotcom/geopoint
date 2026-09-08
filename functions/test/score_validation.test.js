"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  comparePerformance,
  performanceMatchesClaim,
  recalculatePerformance,
} = require("../src/score_validation");

const countryRules = {
  modeId: "find_country",
  difficultyId: "intermediate",
  questionCount: 3,
  questionDurationSeconds: 17,
};

test("recalcule score, précision et temps d'une partie", () => {
  const submission = {
    answerEvidence: [
      {modeId: "find_country", isCorrect: true, elapsedSeconds: 3},
      {
        modeId: "find_country",
        isCorrect: false,
        elapsedSeconds: 8,
        distanceInKilometers: 200,
      },
      {
        modeId: "find_country",
        isCorrect: false,
        elapsedSeconds: 17,
        distanceInKilometers: 2500,
      },
    ],
  };
  assert.deepEqual(recalculatePerformance(submission, countryRules), {
    score: 215,
    correctAnswers: 1,
    elapsedSeconds: 28,
    averageDistanceKilometers: 1350,
  });
});

test("recalcule la réussite capitale à partir de la distance", () => {
  const result = recalculatePerformance(
    {
      answerEvidence: [{
        modeId: "find_capital",
        isCorrect: true,
        elapsedSeconds: 5,
        distanceInKilometers: 80,
      }],
    },
    {
      modeId: "find_capital",
      difficultyId: "hard",
      questionCount: 1,
      questionDurationSeconds: 14,
    },
  );
  assert.equal(result.score, 95);
  assert.equal(result.correctAnswers, 1);
});

test("refuse un total client différent du recalcul", () => {
  const recalculated = {
    score: 120,
    correctAnswers: 1,
    elapsedSeconds: 3,
    averageDistanceKilometers: 0,
  };
  assert.equal(performanceMatchesClaim({...recalculated}, recalculated), true);
  assert.equal(
    performanceMatchesClaim({...recalculated, score: 999}, recalculated),
    false,
  );
});

test("conserve le score supérieur puis départage distance et temps", () => {
  const reference = {
    score: 500,
    averageDistanceKilometers: 30,
    elapsedSeconds: 45,
  };
  assert.ok(comparePerformance({...reference, score: 501}, reference) > 0);
  assert.ok(comparePerformance({
    ...reference,
    averageDistanceKilometers: 20,
  }, reference) > 0);
  assert.ok(
    comparePerformance({...reference, elapsedSeconds: 40}, reference) > 0,
  );
});
