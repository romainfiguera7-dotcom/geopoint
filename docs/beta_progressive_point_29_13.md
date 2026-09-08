# Point 29.13 — Tests et bêta progressive

## Objectif

Publier la première bêta Android sans utiliser la clé de débogage et conserver
une procédure identique pour chaque nouvelle version.

## Protections intégrées

- `release` utilise exclusivement `android/key.properties` et la clé d’envoi ;
- une compilation `release` sans signature s’arrête avec une explication ;
- la clé, ses mots de passe et les fichiers `.jks` sont exclus du dépôt ;
- App Check utilise déjà Play Integrity hors mode debug ;
- l’application Android affiche le nom `GeoPoint` et possède explicitement
  l’autorisation réseau ;
- `tool/check_android_beta.ps1` lance l’analyse, les tests Flutter, les tests
  Firebase et la création de l’App Bundle signé.

## Parcours de publication

1. Créer une seule fois la clé d’envoi avec
   `tool/prepare_android_signing.ps1`.
2. Sauvegarder hors du projet `upload-keystore.jks`, `key.properties` et le mot
   de passe. Perdre la clé d’envoi compliquerait les futures mises à jour.
3. Créer l’App Bundle avec `tool/check_android_beta.ps1`.
4. Dans Google Play Console, activer Play App Signing et importer le fichier
   `build/app/outputs/bundle/release/app-release.aab` en test interne.
5. Copier dans Firebase App Check l’empreinte SHA-256 du certificat de
   signature de l’application fournie par Google Play, en plus de l’empreinte
   de la clé d’envoi locale.
6. Vérifier sur l’installation Google Play : démarrage, Firebase, lancement
   d’un défi, classement, historique, amis et contrôle d’un profil enfant.
7. Ouvrir ensuite le test fermé et conserver les testeurs inscrits pendant
   toute la période requise par la Play Console.

## Règle Google Play actuelle

Pour un compte développeur personnel créé après le 13 novembre 2023, Google
demande actuellement au moins 12 testeurs inscrits sans interruption pendant
14 jours avant la demande d’accès à la production :
https://support.google.com/googleplay/android-developer/answer/14151465

Documentation officielle sur la signature :
https://developer.android.com/studio/publish/app-signing

Documentation App Check Flutter :
https://firebase.google.com/docs/app-check/flutter/default-providers
