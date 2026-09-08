"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

const uid = process.argv[2] && process.argv[2].trim();
if (!uid || uid.includes("/") || uid.length > 128) {
  console.error("Usage : npm run admin:grant -- UID_FIREBASE");
  process.exitCode = 1;
} else {
  initializeApp();
  getAuth().getUser(uid)
    .then((user) => getAuth().setCustomUserClaims(uid, {
      ...(user.customClaims || {}),
      admin: true,
    }))
    .then(() => {
      console.log(`Rôle administrateur GeoPoint accordé à ${uid}.`);
    })
    .catch((error) => {
      console.error("Impossible d'accorder le rôle administrateur :", error);
      process.exitCode = 1;
    });
}
