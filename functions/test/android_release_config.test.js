"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const projectRoot = path.resolve(__dirname, "../..");

test("interdit la clé de débogage pour une version Android release", () => {
  const gradle = fs.readFileSync(
    path.join(projectRoot, "android/app/build.gradle.kts"),
    "utf8",
  );
  assert.match(gradle, /signingConfigs\.getByName\("release"\)/);
  assert.doesNotMatch(gradle, /signingConfigs\.getByName\("debug"\)/);
  assert.match(gradle, /prepare_android_signing\.ps1/);
});

test("exclut les secrets de signature Android du dépôt", () => {
  const gitignore = fs.readFileSync(
    path.join(projectRoot, ".gitignore"),
    "utf8",
  );
  assert.match(gitignore, /android\/key\.properties/);
  assert.match(gitignore, /android\/app\/\*\.jks/);
});
