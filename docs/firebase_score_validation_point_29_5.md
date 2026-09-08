# GeoPoint — Validation des scores du point 29.5

## Résultat

La Function callable `submitRankedResults` accepte uniquement un joueur
Firebase authentifié et un jeton App Check valide. Pour chaque tentative, elle :

1. retrouve la session officielle appartenant au joueur ;
2. vérifie le défi, le groupe, la signature compétitive et les dates ;
3. recalcule le score, les bonnes réponses, la distance moyenne et le temps à
   partir des preuves de chaque question ;
4. refuse le résultat si un total transmis diffère du recalcul ;
5. archive la tentative dans `ranking_submissions` ;
6. remplace `ranking_records/{uid}/groups/{rankingGroupId}` uniquement si la
   tentative est meilleure.

Le départage est identique dans Flutter et Firebase : score le plus élevé,
puis distance moyenne la plus faible, puis temps total le plus court.

## Vie privée et migration

Une preuve contient seulement le mode, la réussite, le temps et, lorsque le
barème en a besoin, la distance. Aucun achat, aucune monnaie, aucun XP et
aucune position GPS précise ne sont envoyés.

Une tentative effectuée pendant la validation de migration est enregistrée et
reste rattachée à l'UID Firebase. Depuis le point 29.7, les nouveaux scores
entièrement validés peuvent être publiés sans attendre la migration de la
progression locale.

## Déploiement

Depuis la racine du projet :

```powershell
cd D:\romai\GEOPOINT\geopoint
dart format lib test
flutter analyze
flutter test
firebase deploy --only "firestore:rules,firestore:indexes,functions"
flutter run
```

Le déploiement doit créer ou mettre à jour :

- `submitRankedResults(europe-west1)` ;
- `startOfficialChallengeSession(europe-west1)` ;
- les règles privées de `ranking_records`.

## Test réel

1. Ouvrir n'importe quel défi standard.
2. Vérifier que « Classement automatique activé » est affiché.
3. Terminer une première partie.
4. Revenir au hub Défis pour déclencher la synchronisation.
5. Vérifier dans Firestore :
   `ranking_submissions/{uid}/submissions/{submissionId}` puis
   `ranking_records/{uid}/groups/{rankingGroupId}`.
6. Rejouer avec un score inférieur : la nouvelle tentative doit apparaître
   dans `ranking_submissions`, mais le document `ranking_records` ne doit pas
   être remplacé.
7. Rejouer avec un meilleur score : `ranking_records` doit contenir la nouvelle
   tentative.

Depuis le point 29.7, une nouvelle tentative validée publie le meilleur résultat
dans le classement du défi et met à jour la saison mensuelle.
