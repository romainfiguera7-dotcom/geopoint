"use strict";

const POLICY_VERSION = 1;
const QUARANTINE_THRESHOLD = 70;

function addSignal(signals, code, weight, details) {
  signals.push({code, weight, details});
}

function evaluateRankedAttempt({submission, recalculated, rules, sessionAgeSeconds}) {
  const answers = submission.answerEvidence;
  const questionCount = answers.length;
  const correctRatio = questionCount === 0 ? 0 :
    recalculated.correctAnswers / questionCount;
  const instantAnswers = answers.filter(
    (answer) => answer.elapsedSeconds <= 1,
  ).length;
  const instantRatio = questionCount === 0 ? 0 :
    instantAnswers / questionCount;
  const signals = [];

  if (sessionAgeSeconds + 2 < recalculated.elapsedSeconds) {
    addSignal(
      signals,
      "elapsed_exceeds_session_age",
      100,
      {
        sessionAgeSeconds,
        claimedElapsedSeconds: recalculated.elapsedSeconds,
      },
    );
  }

  if (questionCount >= 8 && correctRatio >= 0.9 && instantRatio >= 0.9) {
    addSignal(
      signals,
      "near_instant_high_accuracy_run",
      75,
      {questionCount, correctRatio, instantRatio},
    );
  }

  const maximumScore = questionCount * 120;
  if (questionCount >= 10 &&
      recalculated.score === maximumScore &&
      recalculated.elapsedSeconds <= questionCount * 2) {
    addSignal(
      signals,
      "maximum_score_speed_burst",
      100,
      {
        questionCount,
        score: recalculated.score,
        elapsedSeconds: recalculated.elapsedSeconds,
      },
    );
  }

  const preciseCapitalAnswers = answers.filter((answer) =>
    answer.modeId === "find_capital" &&
    answer.isCorrect &&
    answer.distanceInKilometers != null &&
    answer.distanceInKilometers <= 0.05 &&
    answer.elapsedSeconds <= 2,
  ).length;
  if (preciseCapitalAnswers >= 4) {
    addSignal(
      signals,
      "repeated_instant_pinpoint_capitals",
      90,
      {preciseCapitalAnswers},
    );
  }

  const incompleteManualAnswers = answers.filter((answer) =>
    answer.modeId !== "ultimate" &&
    !answer.isCorrect &&
    answer.elapsedSeconds < rules.questionDurationSeconds &&
    answer.distanceInKilometers == null,
  ).length;
  if (incompleteManualAnswers >= 2) {
    addSignal(
      signals,
      "repeated_missing_manual_distance",
      70,
      {incompleteManualAnswers},
    );
  }

  const riskScore = Math.min(
    100,
    signals.reduce((total, signal) => total + signal.weight, 0),
  );
  return {
    policyVersion: POLICY_VERSION,
    decision: riskScore >= QUARANTINE_THRESHOLD ? "quarantine" : "allow",
    riskScore,
    signals,
  };
}

module.exports = {
  POLICY_VERSION,
  QUARANTINE_THRESHOLD,
  evaluateRankedAttempt,
};
