"use strict";

const crypto = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {GoogleAuth} = require("google-auth-library");
const {
  requireApiVersion,
  requireIdentifier,
  validateFriendCodeRequest,
  validateFriendRelationRequest,
  validateAdminCompetitionRequest,
  validateAdminDashboardRequest,
  validateAdminScoreActionRequest,
  validateChallengeRewardBatch,
  validateIdentityRegistration,
  validateLeaderboardRequest,
  validateMigrationSnapshot,
  validateOfficialSessionRequest,
  validateRankingSubmissionBatch,
  validateSeasonRewardRequest,
} = require("./src/validation");
const {
  bundledChallengePack,
  expandChallengePack,
  mergeBundledPermanentChallenges,
  rankedSubmissionTimingRejection,
  resolveOfficialChallenge,
  scoringRulesFor,
  sessionExpiry,
} = require("./src/challenge_session");
const {
  comparePerformance,
  performanceMatchesClaim,
  recalculatePerformance,
} = require("./src/score_validation");
const {evaluateRankedAttempt} = require("./src/anti_cheat");
const {
  challengeEntry,
  leaderboardSortKey,
  publicProfile,
  rankedEntries,
  seasonBoardId,
  seasonEntry,
} = require("./src/leaderboard");
const {
  PUBLISHED_STATUS,
  auditRecord,
  bestRecordsByGroup,
  candidateFromSubmission,
  scoreActionTransition,
} = require("./src/admin_control");
const {buildPublicRankingHistory} = require("./src/ranking_history");
const {
  isChildPlayer,
  resolveProfileSafety,
} = require("./src/profile_safety");
const {
  MAX_FRIENDS,
  MAX_PENDING_REQUESTS,
  formatFriendCode,
  friendPairId,
  generateFriendCode,
  normalizeFriendCode,
  socialAllowed,
} = require("./src/friends");
const {
  POLICY_VERSION: SEASON_REWARD_POLICY_VERSION,
  parseSeasonKey,
  seasonClaimOpensAt,
  seasonRewardClaimId,
  seasonRewardForRank,
  seasonRewardTiers,
} = require("./src/season_reward");
const {
  applyReward,
  challengeSucceeded,
  normalizeReward,
  normalizeWallet,
  rewardClaimId,
} = require("./src/challenge_wallet");

initializeApp();

const REGION = "europe-west1";
const API_VERSION = 1;
const SCHEMA_VERSION = 8;
const AD_FREE_PRODUCT_ID = "geopoint_no_ads";
const ANDROID_PACKAGE_NAME = "com.romainfiguera.geopoint";

setGlobalOptions({
  region: REGION,
  memory: "256MiB",
  timeoutSeconds: 30,
  maxInstances: 10,
});

function requireAuthenticatedUser(request) {
  const uid = request.auth && request.auth.uid;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Une connexion Firebase est nécessaire.",
    );
  }
  return uid;
}

function requireAdministrator(request) {
  const uid = requireAuthenticatedUser(request);
  if (!request.auth.token || request.auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Ce compte ne possède pas le rôle administrateur PointGeo.",
    );
  }
  return uid;
}

function validated(parse) {
  try {
    return parse();
  } catch (error) {
    if (error instanceof TypeError || error instanceof RangeError) {
      throw new HttpsError("invalid-argument", error.message);
    }
    throw error;
  }
}

function migrationRequestId(uid, localPlayerId) {
  const digest = crypto
    .createHash("sha256")
    .update(`${uid}:${localPlayerId}:profile-v1`)
    .digest("hex")
    .slice(0, 32);
  return `profile_v1_${digest}`;
}

async function protectChildPublicData(database, uid, friendCode) {
  const [friends, sentRequests, receivedRequests, leaderboardEntries] =
    await Promise.all([
      database.collection(`friendships/${uid}/members`).get(),
      database.collection("friend_requests").where("senderUid", "==", uid).get(),
      database.collection("friend_requests")
        .where("recipientUid", "==", uid).get(),
      database.collectionGroup("entries").where("uid", "==", uid).get(),
    ]);
  const operations = [];
  const addDelete = (reference) => operations.push({type: "delete", reference});
  const addSet = (reference, data, options = undefined) =>
    operations.push({type: "set", reference, data, options});
  const addUpdate = (reference, data) =>
    operations.push({type: "update", reference, data});

  addSet(database.doc(`public_profiles/${uid}`), {
    schemaVersion: SCHEMA_VERSION,
    displayName: FieldValue.delete(),
    avatarId: "default",
    moderationStatus: "protected_child",
    isChild: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  if (typeof friendCode === "string" && friendCode.length > 0) {
    addSet(database.doc(`friend_codes/${friendCode}`), {
      active: false,
      protectedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  for (const document of friends.docs) {
    const friendUid = document.data().friendUid || document.id;
    addDelete(document.ref);
    if (typeof friendUid === "string" && friendUid.length > 0) {
      addDelete(database.doc(`friendships/${friendUid}/members/${uid}`));
    }
  }
  const requests = new Map([
    ...sentRequests.docs,
    ...receivedRequests.docs,
  ].map((document) => [document.ref.path, document]));
  for (const document of requests.values()) {
    if (document.data().status === "pending") {
      addUpdate(document.ref, {
        status: "protected_child",
        resolvedAtUtc: new Date().toISOString(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
  for (const document of leaderboardEntries.docs) addDelete(document.ref);

  for (let offset = 0; offset < operations.length; offset += 400) {
    const batch = database.batch();
    for (const operation of operations.slice(offset, offset + 400)) {
      if (operation.type === "delete") batch.delete(operation.reference);
      if (operation.type === "update") {
        batch.update(operation.reference, operation.data);
      }
      if (operation.type === "set") {
        batch.set(operation.reference, operation.data, operation.options);
      }
    }
    await batch.commit();
  }
}

exports.getServerStatus = onCall(
  {enforceAppCheck: true},
  async (request) => {
    validated(() => requireApiVersion(request.data));
    return {
      apiVersion: API_VERSION,
      schemaVersion: SCHEMA_VERSION,
      region: REGION,
      serverNowUtc: new Date().toISOString(),
      capabilities: [
        "identity_registration",
        "profile_migration_queue",
        "remote_challenge_pack",
        "official_challenge_sessions",
        "ranked_score_validation",
        "ranked_score_quarantine",
        "public_challenge_leaderboards",
        "season_leaderboards",
        "season_closure_rewards",
        "firebase_challenge_wallet",
        "challenge_reward_validation",
        "friend_codes",
        "friend_leaderboards",
        "protected_child_profiles",
        "admin_control_tools",
        "google_play_ad_free_purchase",
        "administrator_ad_free_gifts",
        "account_deletion",
      ],
    };
  },
);

async function deleteDocumentsInBatches(database, references) {
  const uniqueReferences = new Map(
    references.map((reference) => [reference.path, reference]),
  );
  const values = [...uniqueReferences.values()];
  for (let offset = 0; offset < values.length; offset += 400) {
    const batch = database.batch();
    for (const reference of values.slice(offset, offset + 400)) {
      batch.delete(reference);
    }
    await batch.commit();
  }
}

exports.deletePlayerAccount = onCall(
  {enforceAppCheck: true, invoker: "public", timeoutSeconds: 60},
  async (request) => {
    validated(() => requireApiVersion(request.data));
    const uid = requireAuthenticatedUser(request);
    const database = getFirestore();

    const relatedSnapshots = await Promise.all([
      database.collectionGroup("entries").where("uid", "==", uid).get(),
      database.collectionGroup("members")
        .where("friendUid", "==", uid).get(),
      database.collectionGroup("blocked")
        .where("blockedUid", "==", uid).get(),
      database.collection("friend_requests")
        .where("senderUid", "==", uid).get(),
      database.collection("friend_requests")
        .where("recipientUid", "==", uid).get(),
      database.collection("friend_codes").where("uid", "==", uid).get(),
      database.collection("purchase_receipts")
        .where("ownerUid", "==", uid).get(),
    ]);
    await deleteDocumentsInBatches(
      database,
      relatedSnapshots.flatMap((snapshot) =>
        snapshot.docs.map((document) => document.ref)),
    );

    const accountRoots = [
      "players",
      "public_profiles",
      "profile_migrations",
      "ranking_submissions",
      "ranking_records",
      "ranking_reviews",
      "challenge_sessions",
      "challenge_session_requests",
      "challenge_reward_claims",
      "season_reward_claims",
      "friendships",
      "friend_blocks",
    ];
    await Promise.all(accountRoots.map((collectionName) =>
      database.recursiveDelete(database.doc(`${collectionName}/${uid}`))));
    await getAuth().deleteUser(uid);

    return {
      apiVersion: API_VERSION,
      deleted: true,
      deletedAtUtc: new Date().toISOString(),
    };
  },
);

function adFreeEntitlementResponse(player) {
  const entitlement = player && player.monetization &&
    player.monetization.adFree;
  const active = entitlement && entitlement.active === true;
  return {
    apiVersion: API_VERSION,
    active,
    source: active && typeof entitlement.source === "string" ?
      entitlement.source : "none",
    grantedAtUtc: active ?
      firestoreDate(entitlement.grantedAt) || entitlement.grantedAtUtc || null :
      null,
    serverNowUtc: new Date().toISOString(),
  };
}

function validateAdFreePurchaseRequest(data) {
  const source = requireApiVersion(data);
  const platform = typeof source.platform === "string" ?
    source.platform.trim() : "";
  const productId = typeof source.productId === "string" ?
    source.productId.trim() : "";
  const purchaseToken = typeof source.purchaseToken === "string" ?
    source.purchaseToken.trim() : "";
  if (platform !== "android" || productId !== AD_FREE_PRODUCT_ID) {
    throw new TypeError("Produit sans publicité invalide.");
  }
  if (purchaseToken.length < 20 || purchaseToken.length > 2048 ||
      /[\u0000-\u001f\u007f]/.test(purchaseToken)) {
    throw new TypeError("Jeton Google Play invalide.");
  }
  return {productId, purchaseToken};
}

async function verifyGooglePlayOneTimeProduct(input) {
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const packageName = encodeURIComponent(ANDROID_PACKAGE_NAME);
  const productId = encodeURIComponent(input.productId);
  const token = encodeURIComponent(input.purchaseToken);
  try {
    const response = await client.request({
      method: "GET",
      url: "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
        `applications/${packageName}/purchases/products/${productId}/` +
        `tokens/${token}`,
    });
    const purchase = response.data || {};
    if (purchase.purchaseState !== 0 || purchase.consumptionState === 1) {
      throw new HttpsError(
        "failed-precondition",
        "Cet achat Google Play n’est pas actif.",
      );
    }
    return purchase;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Vérification Google Play refusée", error);
    throw new HttpsError(
      "failed-precondition",
      "Google Play n’a pas confirmé cet achat.",
    );
  }
}

exports.getAdFreeEntitlement = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    validated(() => requireApiVersion(request.data));
    const playerSnapshot = await getFirestore().doc(`players/${uid}`).get();
    return adFreeEntitlementResponse(playerSnapshot.data());
  },
);

exports.verifyAdFreePurchase = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateAdFreePurchaseRequest(request.data));
    const purchase = await verifyGooglePlayOneTimeProduct(input);
    const database = getFirestore();
    const tokenHash = crypto.createHash("sha256")
      .update(input.purchaseToken).digest("hex");
    const receiptRef = database.doc(`purchase_receipts/${tokenHash}`);
    const playerRef = database.doc(`players/${uid}`);
    await database.runTransaction(async (transaction) => {
      const receiptSnapshot = await transaction.get(receiptRef);
      const previousUid = receiptSnapshot.data() &&
        receiptSnapshot.data().ownerUid;
      let previousPlayerRef = null;
      let previousPlayer = null;
      if (typeof previousUid === "string" && previousUid !== uid) {
        previousPlayerRef = database.doc(`players/${previousUid}`);
        previousPlayer = (await transaction.get(previousPlayerRef)).data();
      }
      const previousEntitlement = previousPlayer &&
        previousPlayer.monetization && previousPlayer.monetization.adFree;
      if (previousPlayerRef !== null && previousEntitlement &&
          previousEntitlement.source === "google_play" &&
          previousEntitlement.tokenHash === tokenHash) {
        transaction.set(previousPlayerRef, {
          monetization: {
            adFree: {
              active: false,
              source: "transferred_restore",
              revokedAt: FieldValue.serverTimestamp(),
            },
          },
        }, {merge: true});
      }
      transaction.set(playerRef, {
        monetization: {
          adFree: {
            active: true,
            source: "google_play",
            productId: input.productId,
            tokenHash,
            orderId: purchase.orderId || null,
            grantedAt: FieldValue.serverTimestamp(),
          },
        },
      }, {merge: true});
      transaction.set(receiptRef, {
        schemaVersion: SCHEMA_VERSION,
        platform: "android",
        productId: input.productId,
        ownerUid: uid,
        orderId: purchase.orderId || null,
        purchaseTimeMillis: purchase.purchaseTimeMillis || null,
        verifiedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
    const updated = await playerRef.get();
    return adFreeEntitlementResponse(updated.data());
  },
);

exports.registerPlayerIdentity = onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateIdentityRegistration(request.data));
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const publicProfileRef = database.doc(`public_profiles/${uid}`);

    const registration = await database.runTransaction(
      async (transaction) => {
        const [playerSnapshot, publicProfileSnapshot] = await Promise.all([
          transaction.get(playerRef),
          transaction.get(publicProfileRef),
        ]);
        const current = playerSnapshot.data() || {};
        const currentPublicProfile = publicProfileSnapshot.data() || {};
        const currentMigration = current.migration || {};
        const previousStatus = currentMigration.status;
        const safety = resolveProfileSafety(
          current,
          input.profileType,
          input.childAgeGroup,
        );
        const status = previousStatus === "completed" ||
          previousStatus === "pending_server_validation"
          ? previousStatus
          : input.hasLocalProgress
            ? "required"
            : "not_required";
        const privateUpdate = {
          schemaVersion: SCHEMA_VERSION,
          localPlayerIds: FieldValue.arrayUnion(input.localPlayerId),
          requestedDisplayName: input.displayName,
          avatarId: input.avatarId,
          profileSchemaVersion: input.profileSchemaVersion,
          status: "active",
          ...safety,
          lastSeenAt: FieldValue.serverTimestamp(),
          migration: {
            status,
            updatedAt: FieldValue.serverTimestamp(),
          },
        };
        if (!playerSnapshot.exists) {
          privateUpdate.role = "player";
          privateUpdate.createdAt = FieldValue.serverTimestamp();
        }
        transaction.set(playerRef, privateUpdate, {merge: true});
        transaction.set(publicProfileRef, safety.isChild ? {
          schemaVersion: SCHEMA_VERSION,
          displayName: FieldValue.delete(),
          avatarId: "default",
          moderationStatus: "protected_child",
          isChild: true,
          updatedAt: FieldValue.serverTimestamp(),
        } : {
          schemaVersion: SCHEMA_VERSION,
          displayName: input.displayName,
          avatarId: input.avatarId,
          moderationStatus:
            currentPublicProfile.moderationStatus === "approved" &&
            currentPublicProfile.displayName === input.displayName ?
              "approved" : "pending",
          isChild: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {
          migrationStatus: status,
          safety,
          friendCode: existingFriendCode(current),
        };
      },
    );

    if (registration.safety.isChild) {
      await protectChildPublicData(database, uid, registration.friendCode);
    }

    return {
      apiVersion: API_VERSION,
      onlinePlayerId: uid,
      providerId: "firebase",
      migrationRequired: registration.migrationStatus === "required" ||
        registration.migrationStatus === "pending_server_validation",
      migrationStatus: registration.migrationStatus,
      profileType: registration.safety.profileType,
      childProtectionEnabled: registration.safety.isChild,
      childAgeGroup: registration.safety.childAgeGroup,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

exports.submitProfileMigration = onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const snapshot = validated(() => validateMigrationSnapshot(request.data));
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const requestId = migrationRequestId(uid, snapshot.localPlayerId);
    const migrationRef = database.doc(
      `profile_migrations/${uid}/requests/${requestId}`,
    );

    const status = await database.runTransaction(async (transaction) => {
      const playerSnapshot = await transaction.get(playerRef);
      const migrationSnapshot = await transaction.get(migrationRef);
      if (!playerSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "L’identité joueur doit être créée avant la migration.",
        );
      }
      const localPlayerIds = playerSnapshot.data().localPlayerIds || [];
      if (!localPlayerIds.includes(snapshot.localPlayerId)) {
        throw new HttpsError(
          "permission-denied",
          "Le profil local ne correspond pas au compte connecté.",
        );
      }
      if (migrationSnapshot.exists) {
        return migrationSnapshot.data().status;
      }

      transaction.create(migrationRef, {
        schemaVersion: SCHEMA_VERSION,
        status: "pending_server_validation",
        snapshot,
        appId: request.app ? request.app.appId : null,
        receivedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        playerRef,
        {
          migration: {
            status: "pending_server_validation",
            latestRequestId: requestId,
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
      return "pending_server_validation";
    });

    return {
      apiVersion: API_VERSION,
      requestId,
      status,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

exports.getProfileMigrationStatus = onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    validated(() => requireApiVersion(request.data));
    const playerSnapshot = await getFirestore().doc(`players/${uid}`).get();
    if (!playerSnapshot.exists) {
      throw new HttpsError("not-found", "Le profil joueur est introuvable.");
    }
    const migration = playerSnapshot.data().migration || {};
    return {
      apiVersion: API_VERSION,
      status: migration.status || "not_required",
      requestId: migration.latestRequestId || null,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

exports.getActiveChallengePack = onCall(
  {enforceAppCheck: true},
  async (request) => {
    validated(() => requireApiVersion(request.data));
    const database = getFirestore();
    const configSnapshot = await database.doc("server_config/public").get();
    const activePackId = configSnapshot.data() &&
      configSnapshot.data().activeChallengePackId;
    if (typeof activePackId !== "string" || activePackId.length === 0) {
      return {
        apiVersion: API_VERSION,
        pack: null,
        serverNowUtc: new Date().toISOString(),
      };
    }
    const normalizedPackId = validated(() =>
      requireIdentifier(activePackId, "activeChallengePackId"));
    const packSnapshot = await database
      .doc(`challenge_packs/${normalizedPackId}`)
      .get();
    const pack = packSnapshot.data();
    if (!packSnapshot.exists || pack.status !== "published") {
      throw new HttpsError("not-found", "Le pack actif est indisponible.");
    }
    if (
      !Number.isSafeInteger(pack.revision) ||
      typeof pack.publishedAtUtc !== "string" ||
      Number.isNaN(Date.parse(pack.publishedAtUtc)) ||
      typeof pack.jsonSource !== "string" ||
      pack.jsonSource.length === 0
    ) {
      throw new HttpsError("data-loss", "Le pack actif est invalide.");
    }
    return {
      apiVersion: API_VERSION,
      pack: {
        revision: pack.revision,
        publishedAtUtc: new Date(pack.publishedAtUtc).toISOString(),
        jsonSource: pack.jsonSource,
      },
      serverNowUtc: new Date().toISOString(),
    };
  },
);

async function loadOfficialChallengePack(database) {
  const configSnapshot = await database.doc("server_config/public").get();
  const activePackId = configSnapshot.data() &&
    configSnapshot.data().activeChallengePackId;
  if (typeof activePackId !== "string" || activePackId.length === 0) {
    return bundledChallengePack();
  }
  const normalizedPackId = validated(() =>
    requireIdentifier(activePackId, "activeChallengePackId"));
  const packSnapshot = await database
    .doc(`challenge_packs/${normalizedPackId}`)
    .get();
  const pack = packSnapshot.data();
  if (!packSnapshot.exists || pack.status !== "published") {
    throw new HttpsError("not-found", "Le pack officiel est indisponible.");
  }
  try {
    return mergeBundledPermanentChallenges(JSON.parse(pack.jsonSource));
  } catch (_) {
    throw new HttpsError("data-loss", "Le pack officiel est invalide.");
  }
}

function rewardValidationResult(claimId, decision, options = {}) {
  return {
    claimId,
    decision,
    ...(options.reward ? {confirmedReward: options.reward} : {}),
    ...(options.reason ? {rejectionReason: options.reason} : {}),
  };
}

exports.validateChallengeRewards = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() =>
      validateChallengeRewardBatch(request.data));
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const pack = await loadOfficialChallengePack(database);
    const challenges = new Map(
      expandChallengePack(pack).map((challenge) => [challenge.id, challenge]),
    );
    const claimRefs = input.claims.map((claim) => database.doc(
      `challenge_reward_claims/${uid}/claims/${claim.claimId}`,
    ));
    const rankingRefs = input.claims.map((claim) => database.doc(
      `ranking_records/${uid}/groups/${claim.challengeId}`,
    ));

    const transactionResult = await database.runTransaction(
      async (transaction) => {
        const playerSnapshot = await transaction.get(playerRef);
        if (!playerSnapshot.exists ||
            playerSnapshot.data().status !== "active") {
          throw new HttpsError(
            "failed-precondition",
            "L’identité joueur doit être enregistrée avant les récompenses.",
          );
        }
        const [claimSnapshots, rankingSnapshots] = await Promise.all([
          Promise.all(claimRefs.map((reference) => transaction.get(reference))),
          Promise.all(rankingRefs.map((reference) =>
            transaction.get(reference))),
        ]);
        let wallet = normalizeWallet(playerSnapshot.data());
        const results = [];

        for (let index = 0; index < input.claims.length; index += 1) {
          const claim = input.claims[index];
          const existing = claimSnapshots[index];
          if (existing.exists) {
            const reward = normalizeReward(existing.data().reward);
            wallet = applyReward(wallet, claim.claimId, reward);
            results.push(rewardValidationResult(
              claim.claimId,
              "confirmed",
              {reward},
            ));
            continue;
          }

          const challenge = challenges.get(claim.challengeId);
          if (!challenge || challenge.disabled === true ||
              rewardClaimId(challenge) !== claim.claimId) {
            results.push(rewardValidationResult(
              claim.claimId,
              "rejected",
              {reason: "La récompense ne correspond pas au défi officiel."},
            ));
            continue;
          }

          const rankingSnapshot = rankingSnapshots[index];
          const performance = rankingSnapshot.data();
          if (!rankingSnapshot.exists ||
              performance.challengeId !== claim.challengeId) {
            results.push(rewardValidationResult(
              claim.claimId,
              "pending",
              {reason: "Le résultat officiel est encore en cours de validation."},
            ));
            continue;
          }
          if (!challengeSucceeded(challenge, performance)) {
            results.push(rewardValidationResult(
              claim.claimId,
              "rejected",
              {reason: "Les conditions de réussite ne sont pas atteintes."},
            ));
            continue;
          }

          const reward = normalizeReward(challenge.reward);
          transaction.create(claimRefs[index], {
            schemaVersion: SCHEMA_VERSION,
            uid,
            claimId: claim.claimId,
            challengeId: claim.challengeId,
            reward,
            claimedAtUtc: claim.claimedAtUtc,
            confirmedAtUtc: new Date().toISOString(),
            createdAt: FieldValue.serverTimestamp(),
          });
          wallet = applyReward(wallet, claim.claimId, reward);
          results.push(rewardValidationResult(
            claim.claimId,
            "confirmed",
            {reward},
          ));
        }

        if (input.claims.length > 0) {
          transaction.set(playerRef, {
            economy: {
              wallet,
              updatedAt: FieldValue.serverTimestamp(),
            },
          }, {merge: true});
        }
        return {results, wallet};
      },
    );

    return {
      apiVersion: API_VERSION,
      serverNowUtc: new Date().toISOString(),
      results: transactionResult.results,
      wallet: transactionResult.wallet,
    };
  },
);

exports.startOfficialChallengeSession = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateOfficialSessionRequest(request.data));
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists || playerSnapshot.data().status !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "L’identité joueur doit être enregistrée avant la partie classée.",
      );
    }
    assertCompetitiveAllowed(playerSnapshot.data());

    const now = new Date();
    const pack = await loadOfficialChallengePack(database);
    let challenge;
    try {
      challenge = resolveOfficialChallenge(pack, input, now);
    } catch (error) {
      throw new HttpsError("failed-precondition", error.message);
    }
    const controlSnapshot = await database
      .doc(`challenge_controls/${input.rankingGroupId}`)
      .get();
    if (controlSnapshot.exists && controlSnapshot.data().disabled === true) {
      throw new HttpsError(
        "failed-precondition",
        "Cette compétition a été suspendue par PointGeo.",
      );
    }
    const expiresAt = sessionExpiry(challenge, now);
    const scoringRules = validated(() => scoringRulesFor(challenge));
    const requestRef = database.doc(
      `challenge_session_requests/${uid}/requests/${input.launchId}`,
    );
    const sessionId = `cs_${crypto.randomUUID().replaceAll("-", "")}`;
    const sessionRef = database.doc(
      `challenge_sessions/${uid}/sessions/${sessionId}`,
    );
    const migrationStatus = (playerSnapshot.data().migration || {}).status ||
      "not_required";
    // La migration protège la progression locale. Le score, lui, est déjà
    // rattaché à l'UID Firebase et entièrement recalculé par le serveur.
    const rankingEligible = true;

    const result = await database.runTransaction(async (transaction) => {
      const existingRequest = await transaction.get(requestRef);
      if (existingRequest.exists) {
        const data = existingRequest.data();
        if (data.challengeId !== input.challengeId) {
          throw new HttpsError(
            "already-exists",
            "Cette demande de lancement est déjà utilisée.",
          );
        }
        return {
          sessionId: data.sessionId,
          startedAtUtc: data.startedAtUtc,
          expiresAtUtc: data.expiresAtUtc,
          rankingEligible: data.rankingEligible === true,
          migrationStatus: data.migrationStatus,
        };
      }
      const startedAtUtc = now.toISOString();
      const expiresAtUtc = expiresAt.toISOString();
      const common = {
        schemaVersion: SCHEMA_VERSION,
        uid,
        challengeId: input.challengeId,
        rankingGroupId: input.rankingGroupId,
        competitiveSignature: input.competitiveSignature,
        startedAtUtc,
        expiresAtUtc,
        rankingEligible,
        migrationStatus,
        challengePeriod: challenge.period,
        seasonKey: pack.monthKey,
        scoringRules,
      };
      transaction.create(sessionRef, {
        ...common,
        sessionId,
        launchId: input.launchId,
        status: "active",
        appId: request.app ? request.app.appId : null,
        authProvider: request.auth.token.firebase &&
          request.auth.token.firebase.sign_in_provider || null,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(requestRef, {
        ...common,
        sessionId,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {
        sessionId,
        startedAtUtc,
        expiresAtUtc,
        rankingEligible,
        migrationStatus,
      };
    });

    return {
      apiVersion: API_VERSION,
      ...result,
      challengeId: input.challengeId,
      rankingGroupId: input.rankingGroupId,
      competitiveSignature: input.competitiveSignature,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

function rejectedRankingResult(submissionId, reason) {
  return {
    submissionId,
    decision: "rejected",
    reason,
  };
}

function quarantinedRankingResult(submissionId) {
  return {
    submissionId,
    decision: "quarantined",
    reason: "Tentative placée en vérification automatique.",
  };
}

async function validateRankedSubmission(database, uid, submission) {
  const submissionRef = database.doc(
    `ranking_submissions/${uid}/submissions/${submission.submissionId}`,
  );
  const sessionRef = database.doc(
    `challenge_sessions/${uid}/sessions/${submission.officialSessionId}`,
  );
  const bestRef = database.doc(
    `ranking_records/${uid}/groups/${submission.rankingGroupId}`,
  );
  const reviewRef = database.doc(
    `ranking_reviews/${uid}/submissions/${submission.submissionId}`,
  );

  return database.runTransaction(async (transaction) => {
    const [existingSnapshot, sessionSnapshot, bestSnapshot] =
      await Promise.all([
        transaction.get(submissionRef),
        transaction.get(sessionRef),
        transaction.get(bestRef),
      ]);
    if (existingSnapshot.exists) {
      const existing = existingSnapshot.data();
      return {
        submissionId: submission.submissionId,
        decision: existing.clientDecision || "rejected",
        reason: existing.clientReason || null,
      };
    }

    const session = sessionSnapshot.data();
    let rejectionReason = null;
    if (!sessionSnapshot.exists) {
      rejectionReason = "Session officielle introuvable.";
    } else if (session.status !== "active") {
      rejectionReason = "Session officielle déjà utilisée.";
    } else if (
      session.challengeId !== submission.challengeId ||
      session.rankingGroupId !== submission.rankingGroupId ||
      session.competitiveSignature !== submission.competitiveSignature
    ) {
      rejectionReason = "Le résultat ne correspond pas à sa session.";
    }

    const now = new Date();
    const startedAt = new Date(session && session.startedAtUtc);
    if (rejectionReason === null) {
      rejectionReason = rankedSubmissionTimingRejection({
        completedAtUtc: submission.completedAtUtc,
        startedAtUtc: session.startedAtUtc,
        expiresAtUtc: session.expiresAtUtc,
      });
    }

    let recalculated = null;
    if (rejectionReason === null) {
      try {
        recalculated = recalculatePerformance(
          submission,
          session.scoringRules,
        );
        if (!performanceMatchesClaim(submission, recalculated)) {
          rejectionReason = "Le score transmis ne correspond pas au recalcul.";
        }
      } catch (error) {
        rejectionReason = error.message;
      }
    }

    const baseRecord = {
      schemaVersion: SCHEMA_VERSION,
      uid,
      ...submission,
      receivedAt: FieldValue.serverTimestamp(),
    };
    if (rejectionReason !== null) {
      transaction.create(submissionRef, {
        ...baseRecord,
        status: "rejected",
        clientDecision: "rejected",
        clientReason: rejectionReason,
      });
      if (sessionSnapshot.exists && session.status === "active") {
        transaction.update(sessionRef, {
          status: "rejected",
          submissionId: submission.submissionId,
          closedAt: FieldValue.serverTimestamp(),
        });
      }
      return rejectedRankingResult(submission.submissionId, rejectionReason);
    }

    const sessionAgeSeconds = Math.max(
      0,
      (now.getTime() - startedAt.getTime()) / 1000,
    );
    const antiCheat = evaluateRankedAttempt({
      submission,
      recalculated,
      rules: session.scoringRules,
      sessionAgeSeconds,
    });
    if (antiCheat.decision === "quarantine") {
      const clientReason =
        "Tentative placée en vérification automatique.";
      transaction.create(submissionRef, {
        ...baseRecord,
        recalculated,
        status: "quarantined",
        isBest: false,
        clientDecision: "quarantined",
        clientReason,
      });
      transaction.set(reviewRef, {
        schemaVersion: SCHEMA_VERSION,
        uid,
        submissionId: submission.submissionId,
        challengeId: submission.challengeId,
        rankingGroupId: submission.rankingGroupId,
        officialSessionId: submission.officialSessionId,
        status: "pending_review",
        antiCheat,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(sessionRef, {
        status: "quarantined",
        submissionId: submission.submissionId,
        closedAt: FieldValue.serverTimestamp(),
      });
      return quarantinedRankingResult(submission.submissionId);
    }

    const candidate = {
      submissionId: submission.submissionId,
      challengeId: submission.challengeId,
      rankingGroupId: submission.rankingGroupId,
      officialSessionId: submission.officialSessionId,
      attemptNumber: submission.attemptNumber,
      completedAtUtc: submission.completedAtUtc,
      ...recalculated,
      rankingEligible: session.rankingEligible === true,
      migrationStatus: session.migrationStatus,
    };
    const previousBest = bestSnapshot.data();
    const isBest = !bestSnapshot.exists ||
      comparePerformance(candidate, previousBest) > 0;
    if (session.rankingEligible === true) {
      const period = typeof session.challengePeriod === "string" ?
        session.challengePeriod : "daily";
      const seasonKey = typeof session.seasonKey === "string" ?
        session.seasonKey : submission.completedAtUtc.slice(0, 7);
      const boardRef = database.doc(
        `leaderboards/${submission.rankingGroupId}`,
      );
      const entryRef = database.doc(
        `leaderboards/${submission.rankingGroupId}/entries/${uid}`,
      );
      const seasonId = seasonBoardId(seasonKey);
      const seasonRef = database.doc(`leaderboards/${seasonId}`);
      const seasonEntryRef = database.doc(
        `leaderboards/${seasonId}/entries/${uid}`,
      );
      const [profileSnapshot, entrySnapshot, previousSeasonSnapshot] =
        await Promise.all([
          transaction.get(database.doc(`public_profiles/${uid}`)),
          transaction.get(entryRef),
          transaction.get(seasonEntryRef),
        ]);
      const previousSeason = previousSeasonSnapshot.data();
      const previousContributions = previousSeason &&
        previousSeason.contributions;
      const seasonContributionMissing = !previousContributions ||
        !previousContributions[submission.rankingGroupId];
      if (isBest || !entrySnapshot.exists || seasonContributionMissing) {
        const publishedBest = isBest ? candidate : previousBest;
        const profile = profileSnapshot.data() || {};
        transaction.set(boardRef, {
          schemaVersion: SCHEMA_VERSION,
          type: "challenge",
          period,
          challengeId: publishedBest.challengeId,
          rankingGroupId: submission.rankingGroupId,
          seasonKey,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(entryRef, {
          schemaVersion: SCHEMA_VERSION,
          ...challengeEntry(
            uid,
            publishedBest,
            profile,
            period,
            seasonKey,
          ),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(seasonRef, {
          schemaVersion: SCHEMA_VERSION,
          type: "season",
          seasonKey,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(seasonEntryRef, {
          schemaVersion: SCHEMA_VERSION,
          ...seasonEntry(
            uid,
            previousSeason,
            submission.rankingGroupId,
            publishedBest,
            profile,
            seasonKey,
          ),
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (!isBest && previousBest.rankingEligible !== true) {
          transaction.set(bestRef, {
            rankingEligible: true,
            migrationStatus: session.migrationStatus,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      }
    }
    if (isBest) {
      transaction.set(bestRef, {
        schemaVersion: SCHEMA_VERSION,
        uid,
        ...candidate,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    const storedStatus = session.rankingEligible === true ?
      "validated" : "validated_pending_identity";
    transaction.create(submissionRef, {
      ...baseRecord,
      recalculated,
      status: storedStatus,
      isBest,
      clientDecision: "confirmed",
    });
    transaction.update(sessionRef, {
      status: "completed",
      submissionId: submission.submissionId,
      validatedScore: recalculated.score,
      isBest,
      closedAt: FieldValue.serverTimestamp(),
    });
    return {
      submissionId: submission.submissionId,
      decision: "confirmed",
      bestUpdated: isBest,
    };
  });
}

exports.submitRankedResults = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const submissions = validated(() =>
      validateRankingSubmissionBatch(request.data));
    if (submissions.some((submission) => submission.playerId !== uid)) {
      throw new HttpsError(
        "permission-denied",
        "L’identité du classement ne correspond pas au joueur connecté.",
      );
    }
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Profil joueur absent.");
    }
    assertCompetitiveAllowed(playerSnapshot.data());
    const results = [];
    for (const submission of submissions) {
      results.push(await validateRankedSubmission(database, uid, submission));
    }
    return {
      apiVersion: API_VERSION,
      serverNowUtc: new Date().toISOString(),
      results,
    };
  },
);

async function readLeaderboard(database, uid, metadata) {
  const entriesRef = database.collection(
    `leaderboards/${metadata.boardId}/entries`,
  );
  const [topSnapshot, countSnapshot, currentSnapshot] = await Promise.all([
    entriesRef.orderBy("sortKey", "asc").limit(25).get(),
    entriesRef.count().get(),
    entriesRef.doc(uid).get(),
  ]);
  const entries = rankedEntries(
    topSnapshot.docs.map((document) => document.data()),
    uid,
    25,
  );
  const visibleCurrent = entries.find((entry) => entry.isCurrentPlayer);
  const currentData = currentSnapshot.data();
  let currentPlayerEntry = null;
  if (!visibleCurrent && currentSnapshot.exists) {
    const exactRankSnapshot = typeof currentData.sortKey === "string" ?
      await entriesRef.where("sortKey", "<", currentData.sortKey).count().get() :
      null;
    currentPlayerEntry = {
      rank: exactRankSnapshot == null ? null :
        exactRankSnapshot.data().count + 1,
      displayName: currentData.displayName,
      avatarId: currentData.avatarId,
      score: currentData.score,
      correctAnswers: currentData.correctAnswers,
      averageDistanceKilometers: currentData.averageDistanceKilometers,
      elapsedSeconds: currentData.elapsedSeconds,
      challengeCount: currentData.challengeCount || 1,
      isCurrentPlayer: true,
    };
  }
  return {
    ...metadata,
    totalParticipants: countSnapshot.data().count,
    entries,
    currentPlayerEntry,
  };
}

function assertSocialAllowed(player) {
  if (!socialAllowed(player)) {
    throw new HttpsError(
      "failed-precondition",
      "Les fonctions sociales ne sont pas disponibles pour ce profil.",
    );
  }
}

function assertCompetitiveAllowed(player) {
  if (isChildPlayer(player) || player.publicRankingAllowed === false) {
    throw new HttpsError(
      "failed-precondition",
      "Les classements ne sont pas disponibles pour ce profil.",
    );
  }
}

function existingFriendCode(player) {
  try {
    return normalizeFriendCode(player && player.friendCode);
  } catch (_) {
    return null;
  }
}

async function ensureFriendCode(database, uid) {
  const playerRef = database.doc(`players/${uid}`);
  const initialSnapshot = await playerRef.get();
  if (!initialSnapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Le profil joueur doit être initialisé avant d'utiliser les amis.",
    );
  }
  const initialPlayer = initialSnapshot.data();
  assertSocialAllowed(initialPlayer);
  const existing = existingFriendCode(initialPlayer);
  if (existing !== null) return existing;

  for (let attempt = 0; attempt < 6; attempt += 1) {
    const candidate = generateFriendCode();
    const codeRef = database.doc(`friend_codes/${candidate}`);
    try {
      return await database.runTransaction(async (transaction) => {
        const [playerSnapshot, codeSnapshot] = await Promise.all([
          transaction.get(playerRef),
          transaction.get(codeRef),
        ]);
        const player = playerSnapshot.data();
        if (!playerSnapshot.exists) {
          throw new HttpsError("failed-precondition", "Profil joueur absent.");
        }
        assertSocialAllowed(player);
        const assigned = existingFriendCode(player);
        if (assigned !== null) return assigned;
        if (codeSnapshot.exists) throw new Error("friend-code-collision");
        transaction.create(codeRef, {
          schemaVersion: SCHEMA_VERSION,
          uid,
          active: true,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.set(playerRef, {
          friendCode: candidate,
          friendCodeCreatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return candidate;
      });
    } catch (error) {
      if (error.message !== "friend-code-collision") throw error;
    }
  }
  throw new HttpsError(
    "internal",
    "Impossible de créer un code ami pour le moment.",
  );
}

async function readPublicProfiles(database, uids) {
  const uniqueUids = [...new Set(uids)].filter((value) =>
    typeof value === "string" && value.length > 0);
  if (uniqueUids.length === 0) return new Map();
  const snapshots = await database.getAll(
    ...uniqueUids.map((playerUid) =>
      database.doc(`public_profiles/${playerUid}`)),
  );
  return new Map(snapshots.map((snapshot, index) => [
    uniqueUids[index],
    publicProfile(snapshot.data(), uniqueUids[index]),
  ]));
}

function publicFriendItem(playerId, profile, values = {}) {
  return {
    playerId,
    displayName: profile.displayName,
    avatarId: profile.avatarId,
    ...values,
  };
}

exports.getFriendDashboard = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    validated(() => requireApiVersion(request.data));
    const database = getFirestore();
    const friendCode = await ensureFriendCode(database, uid);
    const friendsRef = database.collection(`friendships/${uid}/members`);
    const requestsRef = database.collection("friend_requests");
    const blockedRef = database.collection(`friend_blocks/${uid}/blocked`);
    const [friendsSnapshot, receivedSnapshot, sentSnapshot, blockedSnapshot] =
      await Promise.all([
        friendsRef.limit(MAX_FRIENDS).get(),
        requestsRef
          .where("recipientUid", "==", uid)
          .where("status", "==", "pending")
          .limit(MAX_PENDING_REQUESTS)
          .get(),
        requestsRef
          .where("senderUid", "==", uid)
          .where("status", "==", "pending")
          .limit(MAX_PENDING_REQUESTS)
          .get(),
        blockedRef.limit(MAX_FRIENDS).get(),
      ]);
    const friendUids = friendsSnapshot.docs.map((document) =>
      document.data().friendUid || document.id);
    const received = receivedSnapshot.docs.map((document) => ({
      requestId: document.id,
      ...document.data(),
    }));
    const sent = sentSnapshot.docs.map((document) => ({
      requestId: document.id,
      ...document.data(),
    }));
    const blockedUids = blockedSnapshot.docs.map((document) =>
      document.data().blockedUid || document.id);
    const profiles = await readPublicProfiles(database, [
      ...friendUids,
      ...received.map((item) => item.senderUid),
      ...sent.map((item) => item.recipientUid),
      ...blockedUids,
    ]);
    const profileFor = (playerId) => profiles.get(playerId) ||
      publicProfile(null, playerId);
    const friends = friendUids.map((playerId, index) => publicFriendItem(
      playerId,
      profileFor(playerId),
      {friendsSinceUtc: friendsSnapshot.docs[index].data().createdAtUtc},
    )).sort((left, right) =>
      left.displayName.localeCompare(right.displayName, "fr"));
    const recentFirst = (left, right) =>
      Date.parse(right.createdAtUtc) - Date.parse(left.createdAtUtc);
    const receivedRequests = received.map((item) => publicFriendItem(
      item.senderUid,
      profileFor(item.senderUid),
      {requestId: item.requestId, createdAtUtc: item.createdAtUtc},
    )).sort(recentFirst);
    const sentRequests = sent.map((item) => publicFriendItem(
      item.recipientUid,
      profileFor(item.recipientUid),
      {requestId: item.requestId, createdAtUtc: item.createdAtUtc},
    )).sort(recentFirst);
    return {
      apiVersion: API_VERSION,
      serverNowUtc: new Date().toISOString(),
      friendCode: formatFriendCode(friendCode),
      limits: {
        maximumFriends: MAX_FRIENDS,
        maximumPendingRequests: MAX_PENDING_REQUESTS,
      },
      friends,
      receivedRequests,
      sentRequests,
      blockedPlayers: blockedUids.map((playerId) => publicFriendItem(
        playerId,
        profileFor(playerId),
      )),
    };
  },
);

exports.sendFriendRequest = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateFriendCodeRequest(request.data));
    const database = getFirestore();
    await ensureFriendCode(database, uid);
    const [codeSnapshot, pendingSnapshot] = await Promise.all([
      database.doc(`friend_codes/${input.friendCode}`).get(),
      database.collection("friend_requests")
        .where("senderUid", "==", uid)
        .where("status", "==", "pending")
        .limit(MAX_PENDING_REQUESTS)
        .get(),
    ]);
    if (!codeSnapshot.exists || codeSnapshot.data().active !== true) {
      throw new HttpsError("not-found", "Ce code ami est introuvable.");
    }
    if (pendingSnapshot.size >= MAX_PENDING_REQUESTS) {
      throw new HttpsError(
        "resource-exhausted",
        "Trop de demandes sont déjà en attente.",
      );
    }
    const targetUid = codeSnapshot.data().uid;
    if (typeof targetUid !== "string" || targetUid.length === 0) {
      throw new HttpsError("not-found", "Ce code ami est introuvable.");
    }
    if (targetUid === uid) {
      throw new HttpsError(
        "invalid-argument",
        "Tu ne peux pas utiliser ton propre code ami.",
      );
    }
    const recipientPendingSnapshot = await database
      .collection("friend_requests")
      .where("recipientUid", "==", targetUid)
      .where("status", "==", "pending")
      .limit(MAX_PENDING_REQUESTS)
      .get();
    if (recipientPendingSnapshot.size >= MAX_PENDING_REQUESTS) {
      throw new HttpsError(
        "resource-exhausted",
        "Ce joueur ne peut pas recevoir de nouvelle demande actuellement.",
      );
    }
    const pairId = friendPairId(uid, targetUid);
    const now = new Date().toISOString();
    const senderRef = database.doc(`players/${uid}`);
    const recipientRef = database.doc(`players/${targetUid}`);
    const requestRef = database.doc(`friend_requests/${pairId}`);
    const senderFriendRef = database.doc(
      `friendships/${uid}/members/${targetUid}`,
    );
    const senderBlockRef = database.doc(
      `friend_blocks/${uid}/blocked/${targetUid}`,
    );
    const recipientBlockRef = database.doc(
      `friend_blocks/${targetUid}/blocked/${uid}`,
    );
    await database.runTransaction(async (transaction) => {
      const [
        senderSnapshot,
        recipientSnapshot,
        existingRequest,
        friendshipSnapshot,
        senderBlockSnapshot,
        recipientBlockSnapshot,
      ] = await Promise.all([
        transaction.get(senderRef),
        transaction.get(recipientRef),
        transaction.get(requestRef),
        transaction.get(senderFriendRef),
        transaction.get(senderBlockRef),
        transaction.get(recipientBlockRef),
      ]);
      if (!senderSnapshot.exists || !recipientSnapshot.exists) {
        throw new HttpsError("not-found", "Ce joueur est indisponible.");
      }
      assertSocialAllowed(senderSnapshot.data());
      assertSocialAllowed(recipientSnapshot.data());
      if (senderBlockSnapshot.exists || recipientBlockSnapshot.exists) {
        throw new HttpsError(
          "permission-denied",
          "Cette demande ne peut pas être envoyée.",
        );
      }
      if (friendshipSnapshot.exists) {
        throw new HttpsError("already-exists", "Ce joueur est déjà ton ami.");
      }
      const lastRequestAt = Date.parse(
        senderSnapshot.data().lastFriendRequestAtUtc || "",
      );
      if (Number.isFinite(lastRequestAt) && Date.now() - lastRequestAt < 5000) {
        throw new HttpsError(
          "resource-exhausted",
          "Attends quelques secondes avant une nouvelle demande.",
        );
      }
      if (existingRequest.exists &&
          existingRequest.data().status === "pending") {
        throw new HttpsError(
          "already-exists",
          "Une demande est déjà en attente entre ces deux joueurs.",
        );
      }
      transaction.set(requestRef, {
        schemaVersion: SCHEMA_VERSION,
        senderUid: uid,
        recipientUid: targetUid,
        status: "pending",
        createdAtUtc: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(senderRef, {
        lastFriendRequestAtUtc: now,
      }, {merge: true});
    });
    return {
      apiVersion: API_VERSION,
      status: "sent",
      requestId: pairId,
      serverNowUtc: now,
    };
  },
);

async function updateFriendRequest(database, uid, input) {
  const requestRef = database.doc(`friend_requests/${input.requestId}`);
  const initialSnapshot = await requestRef.get();
  if (!initialSnapshot.exists || initialSnapshot.data().status !== "pending") {
    throw new HttpsError("not-found", "Cette demande n'est plus disponible.");
  }
  const initial = initialSnapshot.data();
  const ownsAction = input.action === "cancel" ?
    initial.senderUid === uid : initial.recipientUid === uid;
  if (!ownsAction) {
    throw new HttpsError("permission-denied", "Action non autorisée.");
  }
  if (input.action !== "accept") {
    await database.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(requestRef);
      const current = snapshot.data();
      if (!snapshot.exists || current.status !== "pending") {
        throw new HttpsError("not-found", "Demande déjà traitée.");
      }
      transaction.update(requestRef, {
        status: input.action === "cancel" ? "cancelled" : "declined",
        resolvedAtUtc: new Date().toISOString(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return;
  }

  const senderUid = initial.senderUid;
  const recipientUid = initial.recipientUid;
  const [senderFriends, recipientFriends] = await Promise.all([
    database.collection(`friendships/${senderUid}/members`)
      .limit(MAX_FRIENDS).get(),
    database.collection(`friendships/${recipientUid}/members`)
      .limit(MAX_FRIENDS).get(),
  ]);
  if (senderFriends.size >= MAX_FRIENDS ||
      recipientFriends.size >= MAX_FRIENDS) {
    throw new HttpsError(
      "resource-exhausted",
      "La limite de 50 amis est atteinte.",
    );
  }
  const senderRef = database.doc(`players/${senderUid}`);
  const recipientRef = database.doc(`players/${recipientUid}`);
  const senderFriendRef = database.doc(
    `friendships/${senderUid}/members/${recipientUid}`,
  );
  const recipientFriendRef = database.doc(
    `friendships/${recipientUid}/members/${senderUid}`,
  );
  const senderBlockRef = database.doc(
    `friend_blocks/${senderUid}/blocked/${recipientUid}`,
  );
  const recipientBlockRef = database.doc(
    `friend_blocks/${recipientUid}/blocked/${senderUid}`,
  );
  const now = new Date().toISOString();
  await database.runTransaction(async (transaction) => {
    const [
      requestSnapshot,
      senderSnapshot,
      recipientSnapshot,
      senderBlockSnapshot,
      recipientBlockSnapshot,
    ] = await Promise.all([
      transaction.get(requestRef),
      transaction.get(senderRef),
      transaction.get(recipientRef),
      transaction.get(senderBlockRef),
      transaction.get(recipientBlockRef),
    ]);
    const current = requestSnapshot.data();
    if (!requestSnapshot.exists || current.status !== "pending" ||
        current.recipientUid !== uid) {
      throw new HttpsError("not-found", "Demande déjà traitée.");
    }
    if (!senderSnapshot.exists || !recipientSnapshot.exists) {
      throw new HttpsError("not-found", "Un profil joueur est indisponible.");
    }
    assertSocialAllowed(senderSnapshot.data());
    assertSocialAllowed(recipientSnapshot.data());
    if (senderBlockSnapshot.exists || recipientBlockSnapshot.exists) {
      throw new HttpsError("permission-denied", "Action non autorisée.");
    }
    transaction.set(senderFriendRef, {
      friendUid: recipientUid,
      createdAtUtc: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(recipientFriendRef, {
      friendUid: senderUid,
      createdAtUtc: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(requestRef, {
      status: "accepted",
      resolvedAtUtc: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function updateFriendPlayer(database, uid, input) {
  const targetUid = input.playerId;
  if (targetUid === uid) {
    throw new HttpsError("invalid-argument", "Action impossible sur ton profil.");
  }
  const ownFriendRef = database.doc(`friendships/${uid}/members/${targetUid}`);
  const targetFriendRef = database.doc(`friendships/${targetUid}/members/${uid}`);
  const ownBlockRef = database.doc(`friend_blocks/${uid}/blocked/${targetUid}`);
  if (input.action === "unblock") {
    await ownBlockRef.delete();
    return;
  }
  if (input.action === "remove") {
    await database.runTransaction(async (transaction) => {
      transaction.delete(ownFriendRef);
      transaction.delete(targetFriendRef);
    });
    return;
  }
  const [targetSnapshot, blockedSnapshot] = await Promise.all([
    database.doc(`players/${targetUid}`).get(),
    database.collection(`friend_blocks/${uid}/blocked`)
      .limit(MAX_FRIENDS)
      .get(),
  ]);
  if (!targetSnapshot.exists) {
    throw new HttpsError("not-found", "Ce joueur est indisponible.");
  }
  assertSocialAllowed(targetSnapshot.data());
  if (blockedSnapshot.size >= MAX_FRIENDS &&
      !blockedSnapshot.docs.some((document) => document.id === targetUid)) {
    throw new HttpsError(
      "resource-exhausted",
      "La limite de joueurs bloqués est atteinte.",
    );
  }
  const requestRef = database.doc(`friend_requests/${friendPairId(uid, targetUid)}`);
  await database.runTransaction(async (transaction) => {
    const requestSnapshot = await transaction.get(requestRef);
    transaction.set(ownBlockRef, {
      blockedUid: targetUid,
      createdAtUtc: new Date().toISOString(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(ownFriendRef);
    transaction.delete(targetFriendRef);
    if (requestSnapshot.exists) {
      transaction.update(requestRef, {
        status: "blocked",
        resolvedAtUtc: new Date().toISOString(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
}

exports.updateFriendRelation = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateFriendRelationRequest(request.data));
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Profil joueur absent.");
    }
    assertSocialAllowed(playerSnapshot.data());
    if (input.requestId !== null) {
      await updateFriendRequest(database, uid, input);
    } else {
      await updateFriendPlayer(database, uid, input);
    }
    return {
      apiVersion: API_VERSION,
      status: "updated",
      action: input.action,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

async function readFriendUids(database, uid) {
  const snapshot = await database
    .collection(`friendships/${uid}/members`)
    .limit(MAX_FRIENDS)
    .get();
  return [...new Set([uid, ...snapshot.docs.map((document) =>
    document.data().friendUid || document.id)])];
}

async function readFriendLeaderboard(database, uid, metadata, participantUids) {
  const snapshots = await database.getAll(
    ...participantUids.map((playerUid) => database.doc(
      `leaderboards/${metadata.boardId}/entries/${playerUid}`,
    )),
  );
  const allEntries = rankedEntries(
    snapshots.filter((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.data()),
    uid,
    participantUids.length,
  );
  return {
    ...metadata,
    totalParticipants: allEntries.length,
    entries: allEntries.slice(0, 25),
    currentPlayerEntry: allEntries.find((entry) => entry.isCurrentPlayer) || null,
  };
}

async function readCurrentPlayerRankingHistory(database, uid, challenges) {
  const snapshot = await database
    .collection(`ranking_submissions/${uid}/submissions`)
    .orderBy("completedAtUtc", "desc")
    .limit(20)
    .get();
  const challengeTitles = Object.fromEntries(
    challenges.map((challenge) => [challenge.id, challenge.title]),
  );
  return buildPublicRankingHistory(
    snapshot.docs.map((document) => document.data()),
    challengeTitles,
  );
}

exports.getChallengeLeaderboards = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateLeaderboardRequest(request.data));
    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Profil joueur absent.");
    }
    assertCompetitiveAllowed(playerSnapshot.data());
    const pack = await loadOfficialChallengePack(database);
    if (pack.monthKey !== input.seasonKey) {
      throw new HttpsError(
        "failed-precondition",
        "La saison demandée n'est pas active.",
      );
    }
    const challenges = expandChallengePack(pack);
    let friendUids = null;
    if (input.scope === "friends") {
      assertSocialAllowed(playerSnapshot.data());
      friendUids = await readFriendUids(database, uid);
    }
    const readRequestedLeaderboard = (metadata) => input.scope === "friends" ?
      readFriendLeaderboard(database, uid, metadata, friendUids) :
      readLeaderboard(database, uid, metadata);
    const boards = [];
    for (const groupId of input.rankingGroupIds) {
      const challenge = challenges.find((item) =>
        item.rankingGroupId === groupId && item.disabled !== true);
      if (!challenge) {
        throw new HttpsError(
          "not-found",
          "Le classement demandé est introuvable.",
        );
      }
      boards.push(await readRequestedLeaderboard({
        boardId: groupId,
        type: challenge.period,
        title: challenge.title,
        seasonKey: input.seasonKey,
      }));
    }
    boards.push(await readRequestedLeaderboard({
      boardId: seasonBoardId(input.seasonKey),
      type: "season",
      title: `Saison ${input.seasonKey}`,
      seasonKey: input.seasonKey,
    }));
    const currentPlayerHistory = await readCurrentPlayerRankingHistory(
      database,
      uid,
      challenges,
    );
    return {
      apiVersion: API_VERSION,
      serverNowUtc: new Date().toISOString(),
      scope: input.scope,
      seasonRewardPolicy: {
        version: SEASON_REWARD_POLICY_VERSION,
        claimOpensAtUtc: seasonClaimOpensAt(input.seasonKey).toISOString(),
        tiers: seasonRewardTiers(),
      },
      boards,
      currentPlayerHistory,
    };
  },
);

function firestoreDate(value) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (typeof value === "string" && !Number.isNaN(Date.parse(value))) {
    return new Date(value).toISOString();
  }
  return null;
}

function publicAdminSubmission(document) {
  const data = document.data();
  const pathParts = document.ref.path.split("/");
  const playerId = data.uid || pathParts[1] || "";
  const performance = data.recalculated || data;
  return {
    playerId,
    submissionId: data.submissionId || document.id,
    challengeId: data.challengeId || "",
    rankingGroupId: data.rankingGroupId || "",
    status: data.status || "unknown",
    score: Number.isFinite(performance.score) ? performance.score : 0,
    correctAnswers: Number.isFinite(performance.correctAnswers) ?
      performance.correctAnswers : 0,
    averageDistanceKilometers:
      Number.isFinite(performance.averageDistanceKilometers) ?
        performance.averageDistanceKilometers : 0,
    elapsedSeconds: Number.isFinite(performance.elapsedSeconds) ?
      performance.elapsedSeconds : 0,
    completedAtUtc: firestoreDate(data.completedAtUtc),
    receivedAtUtc: firestoreDate(data.receivedAt),
    reason: data.clientReason || null,
  };
}

async function writeAdminAudit(database, values) {
  const now = new Date();
  await database.collection("admin_audit_logs").add({
    schemaVersion: SCHEMA_VERSION,
    ...auditRecord({...values, now}),
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function commitAdminOperations(database, operations) {
  for (let offset = 0; offset < operations.length; offset += 400) {
    const batch = database.batch();
    for (const operation of operations.slice(offset, offset + 400)) {
      if (operation.type === "delete") batch.delete(operation.ref);
      if (operation.type === "update") {
        batch.update(operation.ref, operation.data);
      }
      if (operation.type === "set") {
        batch.set(operation.ref, operation.data, operation.options || {});
      }
    }
    await batch.commit();
  }
}

async function rebuildPlayerRankings(database, uid) {
  const [submissionSnapshot, recordSnapshot, publishedSnapshot, profileSnapshot] =
    await Promise.all([
      database.collection(`ranking_submissions/${uid}/submissions`)
        .limit(500).get(),
      database.collection(`ranking_records/${uid}/groups`).get(),
      database.collectionGroup("entries").where("uid", "==", uid).get(),
      database.doc(`public_profiles/${uid}`).get(),
    ]);
  const eligibleDocuments = submissionSnapshot.docs.filter((document) =>
    PUBLISHED_STATUS.has(document.data().status));
  const sessionReferences = eligibleDocuments.map((document) => database.doc(
    `challenge_sessions/${uid}/sessions/${document.data().officialSessionId}`,
  ));
  const sessionSnapshots = sessionReferences.length === 0 ? [] :
    await database.getAll(...sessionReferences);
  const candidates = [];
  for (let index = 0; index < eligibleDocuments.length; index += 1) {
    if (!sessionSnapshots[index].exists) continue;
    try {
      candidates.push(candidateFromSubmission(
        eligibleDocuments[index].data(),
        sessionSnapshots[index].data(),
      ));
    } catch (_) {
      // Une ancienne tentative incomplète reste consultable, mais n'est pas
      // republiée tant que ses preuves ne permettent pas un recalcul sûr.
    }
  }
  const best = bestRecordsByGroup(candidates);
  const profile = profileSnapshot.data() || {};
  const operations = [];
  for (const document of recordSnapshot.docs) {
    operations.push({type: "delete", ref: document.ref});
  }
  for (const document of publishedSnapshot.docs) {
    operations.push({type: "delete", ref: document.ref});
  }
  const seasons = new Map();
  for (const [groupId, candidate] of best) {
    const recordRef = database.doc(`ranking_records/${uid}/groups/${groupId}`);
    const boardRef = database.doc(`leaderboards/${groupId}`);
    const entryRef = database.doc(`leaderboards/${groupId}/entries/${uid}`);
    operations.push({type: "set", ref: recordRef, data: {
      schemaVersion: SCHEMA_VERSION,
      uid,
      ...candidate,
      updatedAt: FieldValue.serverTimestamp(),
    }});
    operations.push({type: "set", ref: boardRef, data: {
      schemaVersion: SCHEMA_VERSION,
      type: "challenge",
      period: candidate.challengePeriod,
      challengeId: candidate.challengeId,
      rankingGroupId: groupId,
      seasonKey: candidate.seasonKey,
      updatedAt: FieldValue.serverTimestamp(),
    }, options: {merge: true}});
    operations.push({type: "set", ref: entryRef, data: {
      schemaVersion: SCHEMA_VERSION,
      ...challengeEntry(
        uid,
        candidate,
        profile,
        candidate.challengePeriod,
        candidate.seasonKey,
      ),
      updatedAt: FieldValue.serverTimestamp(),
    }});
    const previous = seasons.get(candidate.seasonKey);
    seasons.set(candidate.seasonKey, seasonEntry(
      uid,
      previous,
      groupId,
      candidate,
      profile,
      candidate.seasonKey,
    ));
  }
  for (const [seasonKey, entry] of seasons) {
    const boardId = seasonBoardId(seasonKey);
    operations.push({type: "set", ref: database.doc(`leaderboards/${boardId}`),
      data: {
        schemaVersion: SCHEMA_VERSION,
        type: "season",
        seasonKey,
        updatedAt: FieldValue.serverTimestamp(),
      }, options: {merge: true}});
    operations.push({type: "set",
      ref: database.doc(`leaderboards/${boardId}/entries/${uid}`),
      data: {
        schemaVersion: SCHEMA_VERSION,
        ...entry,
        updatedAt: FieldValue.serverTimestamp(),
      }});
  }
  await commitAdminOperations(database, operations);
  return {bestCount: best.size, seasonCount: seasons.size};
}

exports.getAdminControlDashboard = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    requireAdministrator(request);
    const input = validated(() => validateAdminDashboardRequest(request.data));
    const database = getFirestore();
    const pendingQuery = database.collectionGroup("submissions")
      .where("status", "==", "pending_review").limit(input.limit);
    const [pendingSnapshot, pendingCount, rejectedCount, activeSessionCount,
      recentAudits] = await Promise.all([
      pendingQuery.get(),
      database.collectionGroup("submissions")
        .where("status", "==", "pending_review").count().get(),
      database.collectionGroup("submissions")
        .where("status", "==", "rejected").count().get(),
      database.collectionGroup("sessions")
        .where("status", "==", "active").count().get(),
      database.collection("admin_audit_logs")
        .orderBy("createdAt", "desc").limit(15).get(),
    ]);
    const pendingSubmissionRefs = pendingSnapshot.docs.map((document) => {
      const data = document.data();
      return database.doc(
        `ranking_submissions/${data.uid}/submissions/${data.submissionId}`,
      );
    });
    const pendingSubmissions = pendingSubmissionRefs.length === 0 ? [] :
      await database.getAll(...pendingSubmissionRefs);
    const results = pendingSubmissions.filter((item) => item.exists)
      .map(publicAdminSubmission);
    let player = null;
    let competition = null;
    if (input.query.length > 0) {
      const [playerSnapshot, boardSnapshot, controlSnapshot, exactSubmissions] =
        await Promise.all([
          database.doc(`players/${input.query}`).get(),
          database.doc(`leaderboards/${input.query}`).get(),
          database.doc(`challenge_controls/${input.query}`).get(),
          database.collectionGroup("submissions")
            .where("submissionId", "==", input.query).limit(input.limit).get(),
        ]);
      if (playerSnapshot.exists) {
        const data = playerSnapshot.data();
        player = {
          playerId: input.query,
          status: data.status || "unknown",
          profileType: data.profileType || "adult",
          totalXp: data.totalXp || 0,
          gamesPlayed: data.gamesPlayed || 0,
          migrationStatus: data.migration && data.migration.status || null,
        };
        const playerSubmissions = await database
          .collection(`ranking_submissions/${input.query}/submissions`)
          .limit(input.limit).get();
        results.push(...playerSubmissions.docs.map(publicAdminSubmission));
      }
      if (boardSnapshot.exists || controlSnapshot.exists) {
        const board = boardSnapshot.data() || {};
        const control = controlSnapshot.data() || {};
        competition = {
          rankingGroupId: input.query,
          challengeId: board.challengeId || "",
          type: board.type || "challenge",
          seasonKey: board.seasonKey || "",
          disabled: control.disabled === true,
          disabledReason: control.reason || null,
          updatedAtUtc: firestoreDate(control.updatedAt) ||
            firestoreDate(board.updatedAt),
        };
      }
      results.push(...exactSubmissions.docs
        .filter((document) => document.data().recalculated)
        .map(publicAdminSubmission));
      const challengeSubmissions = await database.collectionGroup("submissions")
        .where("challengeId", "==", input.query).limit(input.limit).get();
      results.push(...challengeSubmissions.docs
        .filter((document) => document.data().recalculated)
        .map(publicAdminSubmission));
      const searchedScore = Number(input.query);
      if (Number.isSafeInteger(searchedScore) && searchedScore >= 0) {
        const scoreSubmissions = await database.collectionGroup("submissions")
          .where("recalculated.score", "==", searchedScore)
          .limit(input.limit).get();
        results.push(...scoreSubmissions.docs.map(publicAdminSubmission));
      }
    }
    const uniqueResults = [...new Map(results.map((item) => [
      `${item.playerId}/${item.submissionId}`,
      item,
    ])).values()];
    return {
      apiVersion: API_VERSION,
      serverNowUtc: new Date().toISOString(),
      counters: {
        pendingReviews: pendingCount.data().count,
        rejectedSubmissions: rejectedCount.data().count,
        activeSessions: activeSessionCount.data().count,
      },
      player,
      competition,
      submissions: uniqueResults.slice(0, input.limit),
      auditLogs: recentAudits.docs.map((document) => {
        const data = document.data();
        return {
          auditId: document.id,
          action: data.action,
          target: data.target,
          reason: data.reason,
          actorUid: data.actorUid,
          before: data.before,
          after: data.after,
          createdAtUtc: firestoreDate(data.createdAt) || data.createdAtUtc,
        };
      }),
    };
  },
);

exports.adminGrantAdFreeByFriendCode = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const actorUid = requireAdministrator(request);
    const source = validated(() => requireApiVersion(request.data));
    const friendCode = validated(() => normalizeFriendCode(source.friendCode));
    const reason = validated(() => {
      const value = typeof source.reason === "string" ?
        source.reason.trim().replace(/\s+/g, " ") : "";
      if (value.length < 5 || value.length > 300 ||
          /[\u0000-\u001f\u007f]/.test(value)) {
        throw new TypeError("reason est invalide.");
      }
      return value;
    });
    const database = getFirestore();
    const codeSnapshot = await database.doc(`friend_codes/${friendCode}`).get();
    const targetUid = codeSnapshot.data() && codeSnapshot.data().uid;
    if (!codeSnapshot.exists || codeSnapshot.data().active !== true ||
        typeof targetUid !== "string" || targetUid.length === 0) {
      throw new HttpsError("not-found", "Ce code ami est introuvable.");
    }
    const playerRef = database.doc(`players/${targetUid}`);
    const publicProfileRef = database.doc(`public_profiles/${targetUid}`);
    const [playerSnapshot, publicProfileSnapshot] = await Promise.all([
      playerRef.get(),
      publicProfileRef.get(),
    ]);
    if (!playerSnapshot.exists) {
      throw new HttpsError("not-found", "Le compte de cet ami est introuvable.");
    }
    const previous = playerSnapshot.data().monetization &&
      playerSnapshot.data().monetization.adFree;
    await playerRef.set({
      monetization: {
        adFree: {
          active: true,
          source: "administrator_gift",
          grantedBy: actorUid,
          grantedAt: FieldValue.serverTimestamp(),
        },
      },
    }, {merge: true});
    await writeAdminAudit(database, {
      actorUid,
      action: "grant_ad_free",
      target: targetUid,
      reason,
      before: previous && previous.active === true ? "active" : "inactive",
      after: "active:administrator_gift",
    });
    const publicProfileData = publicProfileSnapshot.data() || {};
    return {
      apiVersion: API_VERSION,
      status: "granted",
      friendCode: formatFriendCode(friendCode),
      displayName: typeof publicProfileData.displayName === "string" ?
        publicProfileData.displayName : "Ami PointGeo",
      serverNowUtc: new Date().toISOString(),
    };
  },
);

function validatedChallengePackJson(data) {
  const source = requireApiVersion(data);
  const jsonSource = typeof source.jsonSource === "string" ?
    source.jsonSource.trim() : "";
  if (jsonSource.length === 0 || jsonSource.length > 750000) {
    throw new TypeError("Le pack JSON est vide ou trop volumineux.");
  }
  let pack;
  try {
    pack = JSON.parse(jsonSource);
  } catch (_) {
    throw new TypeError("Le pack JSON est illisible.");
  }
  if (!pack || typeof pack !== "object" || Array.isArray(pack) ||
      pack.schemaVersion !== 1) {
    throw new TypeError("La version du pack n’est pas prise en charge.");
  }
  pack.id = requireIdentifier(pack.id, "pack.id", 128);
  if (typeof pack.title !== "string" || pack.title.trim().length < 3 ||
      pack.title.trim().length > 120) {
    throw new TypeError("pack.title est invalide.");
  }
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(pack.monthKey || "")) {
    throw new TypeError("pack.monthKey est invalide.");
  }
  const from = new Date(pack.validFromUtc);
  const until = new Date(pack.validUntilUtc);
  if (Number.isNaN(from.getTime()) || Number.isNaN(until.getTime()) ||
      from >= until) {
    throw new TypeError("La période du pack est invalide.");
  }
  const permanent = expandChallengePack(bundledChallengePack())
    .filter((challenge) => challenge.period === "permanent")
    .map((challenge) => ({
      ...challenge,
      validFromUtc: pack.validFromUtc,
      validUntilUtc: pack.validUntilUtc,
    }));
  const existingIds = new Set(
    (Array.isArray(pack.challenges) ? pack.challenges : [])
      .map((challenge) => challenge && challenge.id),
  );
  pack.challenges = [
    ...(Array.isArray(pack.challenges) ? pack.challenges : []),
    ...permanent.filter((challenge) => !existingIds.has(challenge.id)),
  ];
  const challenges = expandChallengePack(pack);
  if (challenges.length === 0 || challenges.length > 500) {
    throw new TypeError("Le pack doit contenir entre 1 et 500 défis.");
  }
  const ids = new Set();
  const allowedPeriods = new Set(["daily", "weekly", "monthly", "permanent"]);
  const allowedModes = new Set([
    "find_country", "find_capital", "find_flag", "ultimate", "mixed",
  ]);
  for (const challenge of challenges) {
    if (!challenge || typeof challenge !== "object") {
      throw new TypeError("Un défi du pack est invalide.");
    }
    const id = requireIdentifier(challenge.id, "challenge.id", 128);
    if (ids.has(id)) throw new TypeError(`Le défi ${id} est défini deux fois.`);
    ids.add(id);
    if (!allowedPeriods.has(challenge.period) ||
        !allowedModes.has(challenge.modeId)) {
      throw new TypeError(`Le défi ${id} utilise un type inconnu.`);
    }
    const challengeFrom = new Date(challenge.validFromUtc);
    const challengeUntil = new Date(challenge.validUntilUtc);
    if (Number.isNaN(challengeFrom.getTime()) ||
        Number.isNaN(challengeUntil.getTime()) ||
        challengeFrom >= challengeUntil) {
      throw new TypeError(`La période du défi ${id} est invalide.`);
    }
    if (typeof challenge.title !== "string" ||
        typeof challenge.description !== "string" ||
        !Number.isSafeInteger(challenge.questionCount) ||
        challenge.questionCount < 1 || challenge.questionCount > 100 ||
        !challenge.successCondition || !challenge.retryPolicy ||
        !challenge.reward) {
      throw new TypeError(`La configuration du défi ${id} est incomplète.`);
    }
  }
  return {
    pack,
    jsonSource: JSON.stringify(pack),
    challenges,
  };
}

exports.adminPublishChallengePack = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const actorUid = requireAdministrator(request);
    const publication = validated(() =>
      validatedChallengePackJson(request.data));
    const database = getFirestore();
    const packRef = database.doc(`challenge_packs/${publication.pack.id}`);
    const configRef = database.doc("server_config/public");
    const result = await database.runTransaction(async (transaction) => {
      const [packSnapshot, configSnapshot] = await Promise.all([
        transaction.get(packRef),
        transaction.get(configRef),
      ]);
      const previousRevision = packSnapshot.exists &&
        Number.isSafeInteger(packSnapshot.data().revision) ?
        packSnapshot.data().revision : 0;
      const revision = previousRevision + 1;
      const previousPackId = configSnapshot.data() &&
        configSnapshot.data().activeChallengePackId;
      if (typeof previousPackId === "string" &&
          previousPackId.length > 0 && previousPackId !== publication.pack.id) {
        transaction.set(database.doc(`challenge_packs/${previousPackId}`), {
          status: "archived",
          archivedAt: FieldValue.serverTimestamp(),
          archivedBy: actorUid,
        }, {merge: true});
      }
      transaction.set(packRef, {
        schemaVersion: SCHEMA_VERSION,
        revision,
        status: "published",
        monthKey: publication.pack.monthKey,
        jsonSource: publication.jsonSource,
        publishedAtUtc: new Date().toISOString(),
        publishedAt: FieldValue.serverTimestamp(),
        publishedBy: actorUid,
      });
      transaction.set(configRef, {
        activeChallengePackId: publication.pack.id,
        challengePackRevision: revision,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorUid,
      }, {merge: true});
      return {revision, previousPackId: previousPackId || "none"};
    });
    await writeAdminAudit(database, {
      actorUid,
      action: "publish_challenge_pack",
      target: publication.pack.id,
      reason: "Publication validée depuis PointGeo Studio",
      before: `${result.previousPackId}`,
      after: `${publication.pack.id}@${result.revision}`,
    });
    return {
      apiVersion: API_VERSION,
      status: "published",
      packId: publication.pack.id,
      revision: result.revision,
      challengeCount: publication.challenges.length,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

exports.adminUpdateRankedSubmission = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const actorUid = requireAdministrator(request);
    const input = validated(() => validateAdminScoreActionRequest(request.data));
    const database = getFirestore();
    const submissionRef = database.doc(
      `ranking_submissions/${input.playerId}/submissions/${input.submissionId}`,
    );
    const reviewRef = database.doc(
      `ranking_reviews/${input.playerId}/submissions/${input.submissionId}`,
    );
    const before = await database.runTransaction(async (transaction) => {
      const [submissionSnapshot, reviewSnapshot] = await Promise.all([
        transaction.get(submissionRef),
        transaction.get(reviewRef),
      ]);
      if (!submissionSnapshot.exists) {
        throw new HttpsError("not-found", "Cette tentative est introuvable.");
      }
      const current = submissionSnapshot.data();
      const nextStatus = validated(() =>
        scoreActionTransition(current.status, input.action));
      const restoredValues = {};
      if (input.action === "restore_expired") {
        if (current.clientReason !== "La session officielle a expiré.") {
          throw new HttpsError(
            "failed-precondition",
            "Seuls les refus causés par l’ancien contrôle d’expiration " +
              "peuvent être rétablis ainsi.",
          );
        }
        const sessionRef = database.doc(
          `challenge_sessions/${input.playerId}/sessions/` +
            `${current.officialSessionId}`,
        );
        const sessionSnapshot = await transaction.get(sessionRef);
        const session = sessionSnapshot.data();
        if (!sessionSnapshot.exists ||
            session.challengeId !== current.challengeId ||
            session.rankingGroupId !== current.rankingGroupId ||
            session.competitiveSignature !== current.competitiveSignature) {
          throw new HttpsError(
            "failed-precondition",
            "La session officielle ne permet pas de rétablir ce score.",
          );
        }
        let recalculated;
        try {
          recalculated = recalculatePerformance(current, session.scoringRules);
        } catch (error) {
          throw new HttpsError("failed-precondition", error.message);
        }
        if (!performanceMatchesClaim(current, recalculated)) {
          throw new HttpsError(
            "failed-precondition",
            "Le score refusé ne correspond pas au recalcul serveur.",
          );
        }
        Object.assign(restoredValues, {
          recalculated,
          clientDecision: "confirmed",
          clientReason: null,
          automaticRejectionReason: current.clientReason,
        });
        transaction.update(sessionRef, {
          status: "validated_manual",
          restoredSubmissionId: input.submissionId,
          restoredAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.update(submissionRef, {
        status: nextStatus,
        ...restoredValues,
        manualReview: {
          action: input.action,
          actorUid,
          reason: input.reason,
          reviewedAtUtc: new Date().toISOString(),
        },
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(reviewRef, {
        schemaVersion: SCHEMA_VERSION,
        uid: input.playerId,
        submissionId: input.submissionId,
        challengeId: current.challengeId,
        rankingGroupId: current.rankingGroupId,
        status: nextStatus,
        resolution: input.action,
        reason: input.reason,
        reviewedBy: actorUid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {status: current.status, nextStatus};
    });
    const rebuild = await rebuildPlayerRankings(database, input.playerId);
    await writeAdminAudit(database, {
      actorUid,
      action: input.action,
      target: `${input.playerId}/${input.submissionId}`,
      reason: input.reason,
      before: before.status,
      after: before.nextStatus,
    });
    return {
      apiVersion: API_VERSION,
      status: "updated",
      newStatus: before.nextStatus,
      rebuild,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

exports.adminUpdateCompetition = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const actorUid = requireAdministrator(request);
    const input = validated(() =>
      validateAdminCompetitionRequest(request.data));
    const database = getFirestore();
    const controlRef = database.doc(
      `challenge_controls/${input.rankingGroupId}`,
    );
    const previousSnapshot = await controlRef.get();
    const previous = previousSnapshot.data() || {};
    let affectedEntries = 0;
    if (input.action === "rebuild") {
      const snapshot = await database.collection(
        `leaderboards/${input.rankingGroupId}/entries`,
      ).limit(5000).get();
      const operations = snapshot.docs.map((document) => ({
        type: "update",
        ref: document.ref,
        data: {
          sortKey: leaderboardSortKey(document.data()),
          updatedAt: FieldValue.serverTimestamp(),
        },
      }));
      await commitAdminOperations(database, operations);
      affectedEntries = operations.length;
    } else {
      await controlRef.set({
        schemaVersion: SCHEMA_VERSION,
        rankingGroupId: input.rankingGroupId,
        disabled: input.action === "disable",
        reason: input.reason,
        updatedBy: actorUid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    await writeAdminAudit(database, {
      actorUid,
      action: `competition_${input.action}`,
      target: input.rankingGroupId,
      reason: input.reason,
      before: previous.disabled === true ? "disabled" : "enabled",
      after: input.action === "disable" ? "disabled" :
        input.action === "enable" ? "enabled" : "rebuilt",
    });
    return {
      apiVersion: API_VERSION,
      status: "updated",
      action: input.action,
      affectedEntries,
      serverNowUtc: new Date().toISOString(),
    };
  },
);

function publicSeasonRewardClaim(record, alreadyClaimed) {
  return {
    apiVersion: API_VERSION,
    status: "claimed",
    serverNowUtc: new Date().toISOString(),
    seasonKey: record.seasonKey,
    claimId: record.claimId,
    rank: record.rank,
    challengeCount: record.challengeCount,
    reward: record.reward,
    claimedAtUtc: record.claimedAtUtc,
    alreadyClaimed,
  };
}

exports.claimSeasonReward = onCall(
  {enforceAppCheck: true, invoker: "public"},
  async (request) => {
    const uid = requireAuthenticatedUser(request);
    const input = validated(() => validateSeasonRewardRequest(request.data));
    const now = new Date();
    const seasonParts = parseSeasonKey(input.seasonKey);
    const seasonStart = new Date(Date.UTC(
      seasonParts.year,
      seasonParts.month - 1,
      1,
    ));
    const oldestSupportedSeason = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth() - 24,
      1,
    ));
    if (seasonStart < oldestSupportedSeason) {
      throw new HttpsError(
        "failed-precondition",
        "Cette saison est trop ancienne pour être réclamée.",
      );
    }
    const claimOpensAt = seasonClaimOpensAt(input.seasonKey);
    if (now < claimOpensAt) {
      return {
        apiVersion: API_VERSION,
        status: "pending",
        serverNowUtc: now.toISOString(),
        seasonKey: input.seasonKey,
        claimOpensAtUtc: claimOpensAt.toISOString(),
      };
    }

    const database = getFirestore();
    const playerRef = database.doc(`players/${uid}`);
    const playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Profil joueur absent.");
    }
    assertCompetitiveAllowed(playerSnapshot.data());
    const claimRef = database.doc(
      `season_reward_claims/${uid}/seasons/${input.seasonKey}`,
    );
    const boardId = seasonBoardId(input.seasonKey);
    const entriesRef = database.collection(`leaderboards/${boardId}/entries`);
    const entryRef = entriesRef.doc(uid);
    const entrySnapshot = await entryRef.get();
    if (!entrySnapshot.exists) {
      return {
        apiVersion: API_VERSION,
        status: "not_qualified",
        serverNowUtc: now.toISOString(),
        seasonKey: input.seasonKey,
      };
    }
    const entry = entrySnapshot.data();
    if (typeof entry.sortKey !== "string" || entry.sortKey.length === 0) {
      throw new HttpsError(
        "data-loss",
        "La position de saison ne peut pas être déterminée.",
      );
    }
    const betterCount = await entriesRef
      .where("sortKey", "<", entry.sortKey)
      .count()
      .get();
    const rank = betterCount.data().count + 1;
    const reward = seasonRewardForRank(rank, input.seasonKey);
    const record = {
      schemaVersion: SCHEMA_VERSION,
      policyVersion: SEASON_REWARD_POLICY_VERSION,
      uid,
      seasonKey: input.seasonKey,
      claimId: seasonRewardClaimId(input.seasonKey),
      rank,
      challengeCount: entry.challengeCount || 1,
      score: entry.score || 0,
      reward,
      claimedAtUtc: now.toISOString(),
      createdAt: FieldValue.serverTimestamp(),
    };

    const transactionResult = await database.runTransaction(
      async (transaction) => {
        const [concurrentSnapshot, currentPlayerSnapshot] = await Promise.all([
          transaction.get(claimRef),
          transaction.get(playerRef),
        ]);
        if (concurrentSnapshot.exists) {
          const existingRecord = concurrentSnapshot.data();
          const wallet = applyReward(
            normalizeWallet(currentPlayerSnapshot.data()),
            existingRecord.claimId,
            existingRecord.reward,
          );
          transaction.set(playerRef, {
            economy: {
              wallet,
              updatedAt: FieldValue.serverTimestamp(),
            },
          }, {merge: true});
          return {record: existingRecord, alreadyClaimed: true};
        }
        transaction.create(claimRef, record);
        const wallet = applyReward(
          normalizeWallet(currentPlayerSnapshot.data()),
          record.claimId,
          record.reward,
        );
        transaction.set(playerRef, {
          economy: {
            wallet,
            updatedAt: FieldValue.serverTimestamp(),
          },
        }, {merge: true});
        return {record, alreadyClaimed: false};
      },
    );
    return publicSeasonRewardClaim(
      transactionResult.record,
      transactionResult.alreadyClaimed,
    );
  },
);
