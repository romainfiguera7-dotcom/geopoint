"use strict";

const crypto = require("node:crypto");
const {isChildPlayer} = require("./profile_safety");

const FRIEND_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const FRIEND_CODE_LENGTH = 8;
const MAX_FRIENDS = 50;
const MAX_PENDING_REQUESTS = 20;

function compactFriendCode(value) {
  return typeof value === "string" ?
    value.trim().toUpperCase().replace(/[\s-]+/g, "") : "";
}

function normalizeFriendCode(value) {
  const compact = compactFriendCode(value);
  const validCharacters = FRIEND_CODE_ALPHABET.replace(/[-\\\]^]/g, "\\$&");
  const pattern = new RegExp(`^GP[${validCharacters}]{${FRIEND_CODE_LENGTH}}$`);
  if (!pattern.test(compact)) {
    throw new TypeError("Le code ami est invalide.");
  }
  return compact;
}

function formatFriendCode(value) {
  const compact = normalizeFriendCode(value);
  return `${compact.slice(0, 2)}-${compact.slice(2, 6)}-${compact.slice(6)}`;
}

function generateFriendCode(randomBytes = crypto.randomBytes) {
  const bytes = randomBytes(FRIEND_CODE_LENGTH);
  let suffix = "";
  for (let index = 0; index < FRIEND_CODE_LENGTH; index += 1) {
    suffix += FRIEND_CODE_ALPHABET[bytes[index] % FRIEND_CODE_ALPHABET.length];
  }
  return `GP${suffix}`;
}

function friendPairId(firstUid, secondUid) {
  const members = [firstUid, secondUid].sort();
  return crypto
    .createHash("sha256")
    .update(`${members[0]}:${members[1]}`)
    .digest("hex")
    .slice(0, 40);
}

function socialAllowed(player) {
  return !isChildPlayer(player) && player && player.socialAllowed !== false;
}

module.exports = {
  FRIEND_CODE_ALPHABET,
  MAX_FRIENDS,
  MAX_PENDING_REQUESTS,
  formatFriendCode,
  friendPairId,
  generateFriendCode,
  normalizeFriendCode,
  socialAllowed,
};
