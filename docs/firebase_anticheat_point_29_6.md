# GeoPoint — Anti-triche et quarantaine du point 29.6

## Principe

Le score reste d'abord recalculé selon le point 29.5. Une seconde analyse
cherche ensuite des combinaisons impossibles ou extrêmement improbables sur
l'ensemble de la partie. Un signal isolé et plausible ne suffit pas.

La politique contrôle notamment :

- la compatibilité entre le temps de jeu et l'âge réel de la session Firebase ;
- une série presque entièrement correcte à vitesse quasi instantanée ;
- un score maximal répété à une vitesse incompatible avec une partie humaine ;
- plusieurs capitales placées à quelques dizaines de mètres presque
  instantanément ;
- des preuves manuelles répétées auxquelles manque une distance attendue.

## Décisions

- `allow` : la tentative peut mettre à jour le meilleur résultat ;
- `quarantine` : la tentative est conservée mais n'entre pas dans le record ;
- `rejected` : la session ou les totaux sont objectivement invalides.

Les détails d'une quarantaine sont écrits dans
`ranking_reviews/{uid}/submissions/{submissionId}`. Cette collection est
inaccessible au joueur et réservée aux administrateurs. L'app reçoit seulement
un message générique de vérification automatique.

La validation ou le refus manuel d'une quarantaine sera intégré aux outils
internes du point 29.12.

## Protection contre les faux positifs

Une seule bonne réponse très rapide reste acceptée. Les règles travaillent sur
des séries longues ou des incohérences temporelles objectives. Une tentative
en quarantaine ne supprime jamais un record précédemment validé.

## Déploiement

Depuis la racine du projet :

```powershell
flutter analyze
flutter test
npm --prefix functions run check
firebase deploy --only "firestore:rules,firestore:indexes,functions"
```

Le statut Firebase doit maintenant annoncer la capacité
`ranked_score_quarantine`.
