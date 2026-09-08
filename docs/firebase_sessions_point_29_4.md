# GeoPoint — Sessions officielles du point 29.4

## Objectif

Une tentative sur un défi standard classé ne commence qu'après la création d'une
session Firebase officielle. Le serveur ne fait confiance ni à l'identifiant
du joueur ni aux dates envoyées par l'app : il utilise Firebase Auth, App Check,
son horloge et le catalogue de défis officiel.

## Garanties

- une session appartient au `uid` Firebase authentifié ;
- le défi doit exister, être actif et posséder un `rankingGroupId` ;
- la signature compétitive Flutter doit être identique à celle recalculée par
  la Function ;
- un `launchId` rejoué renvoie la même session au lieu d'en créer deux ;
- une session expire après 45 minutes au maximum, ou à la fin du défi ;
- le client peut lire sa session mais ne peut jamais l'écrire ;
- l'état de migration est conservé à titre d'audit. Depuis le point 29.7, une
  migration de progression en attente n'empêche ni la validation ni la
  publication d'un score, car la tentative est déjà liée à l'UID Firebase.

## Collections

- `challenge_sessions/{uid}/sessions/{sessionId}` : preuve serveur de la
  tentative active ;
- `challenge_session_requests/{uid}/requests/{launchId}` : clé d'idempotence
  du lancement.

## Déploiement

Depuis la racine du projet :

```powershell
firebase deploy --only "firestore:rules,firestore:indexes,functions"
```

Le déploiement doit afficher la nouvelle Function
`startOfficialChallengeSession(europe-west1)`.

## Validation sur l'app

1. Lancer `flutter run`.
2. Ouvrir n'importe quel défi standard.
3. Vérifier que « Classement automatique activé » est affiché.
4. Démarrer la partie.
5. Dans Firestore, vérifier l'apparition d'un document sous
   `challenge_sessions/{uid}/sessions`.

Le message « La partie classée n'a pas pu être sécurisée » signifie que la
session n'a pas été créée. Dans ce cas la partie classée ne démarre pas et
aucun score non signé n'est ajouté.
