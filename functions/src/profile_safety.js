"use strict";

const CHILD_AGE_GROUPS = new Set(["6_8", "9_11", "12_14", "15_17"]);

function normalizedProfileType(value) {
  return value === "child" ? "child" : "adult";
}

function normalizedChildAgeGroup(value) {
  return CHILD_AGE_GROUPS.has(value) ? value : null;
}

function isChildPlayer(player) {
  return Boolean(player) && (
    player.isChild === true ||
    player.profileType === "child" ||
    player.audience === "child"
  );
}

function resolveProfileSafety(currentPlayer, requestedType, requestedAgeGroup) {
  const child = isChildPlayer(currentPlayer) ||
    normalizedProfileType(requestedType) === "child";
  return {
    profileType: child ? "child" : "adult",
    isChild: child,
    childAgeGroup: child ? normalizedChildAgeGroup(requestedAgeGroup) ||
      normalizedChildAgeGroup(currentPlayer && currentPlayer.childAgeGroup) : null,
    advertisementsAllowed: !child,
    socialAllowed: !child,
    publicRankingAllowed: !child,
    purchasesAllowed: !child,
  };
}

module.exports = {
  CHILD_AGE_GROUPS,
  isChildPlayer,
  normalizedChildAgeGroup,
  normalizedProfileType,
  resolveProfileSafety,
};
