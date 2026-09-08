# GeoPoint — Schéma Firebase du point 29.3

## Architecture retenue

- Région Cloud Functions : `europe-west1`.
- Firestore : comptes, profils publics, migrations, packs, tentatives,
  récompenses et futurs classements.
- Realtime Database : réservée au futur temps réel ; accès entièrement refusé
  pour le moment.
- Cloud Functions callable : seule porte d'écriture pour les données sensibles.
- Firebase Authentication : l'identifiant `request.auth.uid` devient
  l'identifiant joueur en ligne. Le mode de connexion pourra être choisi plus
  tard sans modifier le schéma.
- Firebase App Check : exigé sur les cinq fonctions dès leur déploiement.
- Projet de développement : `geopoint-dev`, partagé entre Android et iOS.
- Identifiant des applications : `com.romainfiguera.geopoint`.
- Le démarrage Firebase échoue de manière sûre : GeoPoint conserve alors son
  profil local et désactive les passerelles distantes pour la session.

## Collections Firestore

| Chemin | Rôle | Lecture client | Écriture client |
| --- | --- | --- | --- |
| `players/{uid}` | Profil privé et état de migration | Propriétaire | Refusée |
| `public_profiles/{uid}` | Nom et avatar pour le classement | Joueur connecté | Refusée |
| `profile_migrations/{uid}/requests/{id}` | Photographie locale à contrôler | Propriétaire | Refusée |
| `challenge_packs/{packId}` | Packs publiés | Via fonction | Refusée |
| `server_config/public` | Pack actif et configuration | Via fonction | Refusée |
| `ranking_submissions/{uid}/submissions/{id}` | Tentatives classées | Propriétaire | Refusée |
| `reward_claims/{uid}/claims/{id}` | Récompenses à valider | Propriétaire | Refusée |
| `leaderboards/{boardId}/entries/{uid}` | Classements publiés | Via fonction | Refusée |

Les comptes portant le custom claim Firebase `admin: true` peuvent lire les
données nécessaires à la modération. Même un administrateur ne réalise pas
d'écriture directe depuis l'application : les écritures passent par le SDK
Admin des fonctions.

## Fonctions callable

### `getServerStatus`

Retourne la version du contrat, la version du schéma, la région, l'heure serveur
et les capacités disponibles.

### `registerPlayerIdentity`

Crée ou actualise les documents privé et public du joueur authentifié. Le
serveur utilise exclusivement l'UID du jeton Firebase ; un identifiant distant
fourni par le client n'est jamais accepté comme autorité.

### `submitProfileMigration`

Enregistre une photographie bornée des anciens totaux. Elle reste en état
`pending_server_validation` : elle ne crédite pas directement l'XP et ne donne
aucun avantage de classement. La requête est idempotente pour un même compte et
un même profil local.

### `getProfileMigrationStatus`

Permet au client de savoir si la migration est en attente, terminée ou refusée.
La migration concerne la progression locale ; les scores recalculés restent
rattachés à l'UID Firebase.

### `getActiveChallengePack`

Retourne uniquement le pack désigné par `server_config/public` et marqué
`published`, avec une heure serveur.

### `getChallengeLeaderboards`

Retourne le top 25 quotidien et hebdomadaire, la saison mensuelle et la position
du joueur, sans exposer les UID Firebase.

## Limites volontaires de cette étape

- Les scores sont recalculés, contrôlés par l'anti-triche puis publiés par les
  points 29.5 à 29.7.
- Les sessions officielles sont désormais ajoutées par le point 29.4 dans
  `challenge_sessions/{uid}/sessions/{sessionId}` et restent non modifiables
  par le client.
- Les classements quotidien, hebdomadaire et saisonnier sont maintenant servis
  par la Function protégée du point 29.7.
- Aucun accès Realtime Database n'est ouvert avant le mode multijoueur.
- Aucun secret ni fichier de compte de service n'est inclus. Les options
  FlutterFire présentes dans l'application sont des identifiants clients
  publics protégés par les règles, Authentication et App Check.

## Références officielles

- Configuration FlutterFire : https://firebase.google.com/docs/flutter/setup
- Fonctions callable et App Check :
  https://firebase.google.com/docs/functions/callable
- Conditions des règles Firestore :
  https://firebase.google.com/docs/firestore/security/rules-conditions
- Firebase Local Emulator Suite :
  https://firebase.google.com/docs/emulator-suite/connect_and_prototype
- Gestion des runtimes Cloud Functions :
  https://firebase.google.com/docs/functions/manage-functions
