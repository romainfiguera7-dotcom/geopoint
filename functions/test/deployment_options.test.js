"use strict";

const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {join} = require("node:path");
const test = require("node:test");

const source = readFileSync(join(__dirname, "..", "index.js"), "utf8");

test("expose publiquement les callables classées puis vérifie App Check", () => {
  const callableNames = [
    "startOfficialChallengeSession",
    "submitRankedResults",
    "getChallengeLeaderboards",
    "claimSeasonReward",
    "validateChallengeRewards",
    "getFriendDashboard",
    "sendFriendRequest",
    "updateFriendRelation",
    "getAdminControlDashboard",
    "adminUpdateRankedSubmission",
    "adminUpdateCompetition",
    "getAdFreeEntitlement",
    "verifyAdFreePurchase",
    "adminGrantAdFreeByFriendCode",
    "adminPublishChallengePack",
  ];
  for (const callableName of callableNames) {
    const declaration = new RegExp(
      `exports\\.${callableName} = onCall\\(\\s*` +
      `\\{enforceAppCheck: true, invoker: "public"\\}`,
    );
    assert.match(source, declaration, callableName);
  }
  assert.match(
    source,
    /exports\.deletePlayerAccount = onCall\(\s*\{enforceAppCheck: true, invoker: "public", timeoutSeconds: 60\}/,
    "deletePlayerAccount",
  );
});
