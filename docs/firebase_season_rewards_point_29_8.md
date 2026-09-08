# GeoPoint — Récompenses de saison du point 29.8

## Résultat

La saison mensuelle se clôture automatiquement une heure après le changement
de mois. Ce délai laisse expirer les dernières sessions officielles et fige le
classement avant le calcul des gains.

À la première ouverture du hub Défis durant la saison suivante, l'application
demande au serveur la récompense de la saison précédente. Firebase calcule le
rang exact, crée un reçu immuable et renvoie le gain autoritaire. Le portefeuille
local conserve le même identifiant de versement : même après un redémarrage ou
plusieurs appels, un gain ne peut être crédité qu'une fois.

## Paliers

| Rang final | Pièces | Diamants | Distinction |
|---|---:|---:|---|
| 1 | 600 | 5 | Emblème Champion de la saison |
| 2 à 3 | 400 | 3 | Podium |
| 4 à 10 | 250 | 2 | Top 10 |
| 11 à 25 | 150 | 1 | Top 25 |
| Tous les autres participants | 75 | 0 | Explorateur |

Une seule partie validée suffit pour participer. Aucun niveau, achat, quantité
d'XP, de pièces ou de diamants n'améliore le rang. Seuls les scores recalculés
et acceptés par l'anti-triche alimentent le classement.

## Sécurité et coût

- `claimSeasonReward` exige Firebase Auth et App Check ;
- le serveur lit uniquement l'entrée du joueur et compte les entrées mieux
  classées ;
- le reçu est stocké sous
  `season_reward_claims/{uid}/seasons/{seasonKey}` ;
- Firestore refuse toute écriture directe du client ;
- après le premier versement, l'application ne rappelle plus Firebase pour
  cette saison.

Il n'y a pas de tâche planifiée payante : la clôture est déterministe et le
versement est déclenché à la prochaine ouverture du hub.

## Déploiement

```powershell
cd D:\romai\GEOPOINT\geopoint
dart format lib test
flutter analyze
flutter test
npm --prefix functions run check
firebase deploy --only "firestore:rules,firestore:indexes,functions"
flutter run
```

Le déploiement doit annoncer la nouvelle fonction
`claimSeasonReward(europe-west1)`. Pendant la saison active, l'écran
Classements affiche le palier actuel et tous les gains disponibles. Le premier
versement réel aura lieu après la fin d'une saison contenant au moins une
participation validée.
