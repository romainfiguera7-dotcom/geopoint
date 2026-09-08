"use strict";

const COUNTRY_THRESHOLDS = {
  discovery: [150, 350, 650, 950, 1300, 1800, 2500],
  easy: [120, 300, 550, 850, 1150, 1650, 2200],
  intermediate: [100, 250, 500, 750, 1000, 1500, 2000],
  hard: [75, 180, 350, 550, 800, 1200, 1700],
  expert: [50, 125, 250, 400, 600, 900, 1300],
};

const CAPITAL_THRESHOLDS = {
  discovery: [20, 50, 100, 200, 300, 500, 750, 1000],
  easy: [15, 40, 80, 150, 250, 400, 650, 900],
  intermediate: [12, 30, 60, 120, 200, 350, 550, 800],
  hard: [10, 25, 50, 100, 160, 280, 450, 700],
  expert: [8, 20, 40, 75, 120, 220, 350, 600],
};

const CAPITAL_CORRECT_RADIUS = {
  discovery: 300,
  easy: 220,
  intermediate: 150,
  hard: 90,
  expert: 50,
};

function thresholdScore(distance, thresholds, scores) {
  for (let index = 0; index < thresholds.length; index += 1) {
    if (distance <= thresholds[index]) return scores[index];
  }
  return 0;
}

function timeBonus(elapsedSeconds, ultimate) {
  if (elapsedSeconds <= 3) return 20;
  if (elapsedSeconds <= 5) return 15;
  if (elapsedSeconds <= (ultimate ? 8 : 7)) return 10;
  if (elapsedSeconds <= 10 || (ultimate && elapsedSeconds <= 11)) return 5;
  return 0;
}

function scoreAnswer(answer, rules) {
  if (answer.modeId === "ultimate") {
    return answer.isCorrect ? 100 + timeBonus(answer.elapsedSeconds, true) : 0;
  }
  const distance = answer.distanceInKilometers;
  let precision = 0;
  if (answer.modeId === "find_capital") {
    if (distance == null) return 0;
    precision = thresholdScore(
      distance,
      CAPITAL_THRESHOLDS[rules.difficultyId] || CAPITAL_THRESHOLDS.easy,
      [100, 95, 90, 80, 70, 55, 35, 20],
    );
  } else if (answer.isCorrect) {
    precision = 100;
  } else if (distance != null) {
    precision = thresholdScore(
      distance,
      COUNTRY_THRESHOLDS[rules.difficultyId] || COUNTRY_THRESHOLDS.intermediate,
      [95, 90, 80, 70, 60, 40, 20],
    );
  }
  return precision === 0 ? 0 :
    precision + timeBonus(answer.elapsedSeconds, false);
}

function answerIsCorrect(answer, rules) {
  if (answer.modeId !== "find_capital") return answer.isCorrect;
  if (answer.distanceInKilometers == null) return false;
  const radius = CAPITAL_CORRECT_RADIUS[rules.difficultyId] || 220;
  return answer.distanceInKilometers <= radius;
}

function validateAnswerMode(answer, rules) {
  const allowed = rules.modeId === "mixed" ?
    ["find_country", "find_capital", "find_flag"] : [rules.modeId];
  if (!allowed.includes(answer.modeId)) {
    throw new RangeError("Un mode de réponse ne correspond pas au défi.");
  }
  if (answer.elapsedSeconds > rules.questionDurationSeconds) {
    throw new RangeError("Un temps de réponse dépasse la durée autorisée.");
  }
  if (answer.modeId === "find_capital" &&
      answer.isCorrect !== answerIsCorrect(answer, rules)) {
    throw new RangeError("Une réponse capitale possède un état incohérent.");
  }
}

function recalculatePerformance(submission, rules) {
  if (submission.answerEvidence.length !== rules.questionCount) {
    throw new RangeError("Le nombre de preuves ne correspond pas au défi.");
  }
  let score = 0;
  let correctAnswers = 0;
  let elapsedSeconds = 0;
  let totalDistance = 0;
  let answersWithDistance = 0;
  for (const answer of submission.answerEvidence) {
    validateAnswerMode(answer, rules);
    score += scoreAnswer(answer, rules);
    if (answerIsCorrect(answer, rules)) correctAnswers += 1;
    elapsedSeconds += answer.elapsedSeconds;
    if (answer.distanceInKilometers != null) {
      totalDistance += answer.distanceInKilometers;
      answersWithDistance += 1;
    }
  }
  return {
    score,
    correctAnswers,
    elapsedSeconds,
    averageDistanceKilometers: answersWithDistance === 0 ? 0 :
      totalDistance / answersWithDistance,
  };
}

function performanceMatchesClaim(submission, recalculated) {
  return submission.score === recalculated.score &&
    submission.correctAnswers === recalculated.correctAnswers &&
    submission.elapsedSeconds === recalculated.elapsedSeconds &&
    Math.abs(
      submission.averageDistanceKilometers -
      recalculated.averageDistanceKilometers,
    ) <= 0.01;
}

function comparePerformance(candidate, reference) {
  if (candidate.score !== reference.score) {
    return candidate.score - reference.score;
  }
  if (candidate.averageDistanceKilometers !==
      reference.averageDistanceKilometers) {
    return reference.averageDistanceKilometers -
      candidate.averageDistanceKilometers;
  }
  return reference.elapsedSeconds - candidate.elapsedSeconds;
}

module.exports = {
  comparePerformance,
  performanceMatchesClaim,
  recalculatePerformance,
  scoreAnswer,
};
