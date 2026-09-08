# GeoPoint — Classements du point 29.7

## Résultat

Chaque meilleur score validé et accepté par l'anti-triche est publié dans deux
tableaux :

- `leaderboards/{rankingGroupId}/entries/{uid}` pour le défi concerné ;
- `leaderboards/season_YYYY_MM/entries/{uid}` pour la saison mensuelle.

Le classement saisonnier additionne le meilleur score du joueur sur chaque
défi. Une nouvelle tentative moins bonne ne diminue jamais le total. Le
départage reste le score, la précision moyenne, puis le temps total.

Le client charge uniquement le top 25 et sa propre entrée. Cette limite évite
des lectures Firestore inutiles. Le nombre total de participants et le rang
personnel exact sont obtenus par des agrégations serveur.

## Vie privée

- aucun e-mail, identifiant de connexion ou achat n'est publié ;
- un pseudonyme en attente de modération est remplacé par « Explorateur XXXX » ;
- les variantes enfant restent hors classement ;
- une tentative en quarantaine n'est jamais publiée ;
- les écritures sont réservées aux Cloud Functions.

La migration de progression locale ne bloque plus les nouveaux scores : la
tentative est déjà rattachée à l'UID Firebase, protégée par App Check et
entièrement recalculée côté serveur.

## Écran Flutter

Le hub Défis contient une carte « Classements ». L'écran propose trois onglets :

1. Jour : meilleur score du défi quotidien actif ;
2. Semaine : meilleur score du défi hebdomadaire actif ;
3. Saison : somme des meilleurs scores de tous les défis du mois.

Le joueur voit le top 25, sa ligne surlignée et, s'il est au-delà, une carte
avec sa position exacte.

Depuis la correction suivant le point 29.8, la tentative est envoyée à Firebase
dès la fin de la partie, avant l'affichage du résultat. La carte Classement
indique alors si le score est validé, en attente de connexion, refusé ou placé
en vérification. Le retour au hub conserve une seconde synchronisation de
secours pour les résultats restés hors ligne.

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

Après le déploiement, terminer au moins une nouvelle partie afin de créer la
première entrée publique. Les anciens records sont publiés automatiquement lors
de la prochaine tentative validée du même défi.
