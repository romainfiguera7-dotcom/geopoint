# Point 27 — Bilan d'équilibrage de la progression XP

## Conclusion

La courbe actuelle peut être conservée pour la première version testable.

- Le début est rapide : les premières récompenses arrivent entre la première
  session et les premières semaines selon le rythme de jeu.
- La progression devient graduellement plus longue sans bloquer de contenu
  principal.
- Maître du monde IV reste un objectif de long terme : environ 4 ans et 3 mois
  pour un joueur occasionnel, 13 mois pour un joueur régulier et 5 mois pour un
  joueur intensif dans les scénarios de référence.
- Une fois les bonus uniques épuisés, la progression continue grâce aux parties
  sans plafond quotidien. Le temps maximal estimé passe alors à environ 5 ans
  et 3 mois, 16 mois ou 6 mois selon le profil.
- Aucun ajustement des 48 seuils n'est recommandé avant d'observer les données
  d'une bêta réelle.

## Hypothèses des scénarios

L'XP moyenne par partie exclut la première réussite du jour et les récompenses
uniques. La colonne « autres XP » lisse les découvertes, maîtrises, missions et
accomplissements réellement obtenus ; ce n'est ni un plafond ni un gain offert
automatiquement.

| Profil | Parties/semaine | XP moyenne/partie | Jours actifs | Première réussite | Autres XP/semaine | Total/semaine |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Occasionnel | 6 | 34 | 2 | 40 | 56 | 300 XP |
| Régulier | 20 | 42 | 5 | 100 | 210 | 1 150 XP |
| Intensif | 50 | 52 | 7 | 140 | 560 | 3 300 XP |

Les « autres XP » représentent environ 12 000 XP sur l'ensemble du parcours
dans chacun des trois scénarios. Cette hypothèse reste cohérente avec le stock
fini de découvertes, maîtrises, missions et accomplissements.

## Temps estimé pour chaque grand niveau

Les durées sont arrondies à la semaine supérieure. Les mois utilisent une
moyenne de 4,345 semaines.

| Objectif | Seuil | Occasionnel | Régulier | Intensif |
| --- | ---: | ---: | ---: | ---: |
| Premiers pas I | 0 XP | Départ | Départ | Départ |
| Curieux du monde I | 400 XP | 2 sem. | 1 sem. | 1 sem. |
| Éclaireur I | 1 200 XP | 4 sem. | 2 sem. | 1 sem. |
| Explorateur I | 2 500 XP | 9 sem. (2,1 mois) | 3 sem. | 1 sem. |
| Voyageur I | 4 500 XP | 15 sem. (3,5 mois) | 4 sem. | 2 sem. |
| Aventurier I | 7 500 XP | 25 sem. (5,8 mois) | 7 sem. | 3 sem. |
| Guide du monde I | 11 500 XP | 39 sem. (9 mois) | 10 sem. | 4 sem. |
| Navigateur I | 16 500 XP | 55 sem. (12,7 mois) | 15 sem. (3,5 mois) | 5 sem. |
| Géographe I | 23 000 XP | 77 sem. (17,7 mois) | 20 sem. (4,6 mois) | 7 sem. |
| Cartographe I | 31 500 XP | 105 sem. (24,2 mois) | 28 sem. (6,4 mois) | 10 sem. |
| Grand cartographe I | 42 000 XP | 140 sem. (32,2 mois) | 37 sem. (8,5 mois) | 13 sem. |
| Maître du monde I | 55 000 XP | 184 sem. (42,3 mois) | 48 sem. (11 mois) | 17 sem. |
| Maître du monde IV | 66 250 XP | 221 sem. (50,9 mois) | 58 sem. (13,3 mois) | 21 sem. (4,8 mois) |

## Fin des récompenses uniques

Lorsque les découvertes, maîtrises, missions et accomplissements deviennent
plus rares, seules les parties et les premières réussites continuent dans cette
estimation prudente.

| Profil | XP durable/semaine | Temps prudent jusqu'au niveau 48 |
| --- | ---: | ---: |
| Occasionnel | 244 XP | 272 semaines, soit environ 62,6 mois |
| Régulier | 940 XP | 71 semaines, soit environ 16,3 mois |
| Intensif | 2 740 XP | 25 semaines, soit environ 5,8 mois |

La progression ne s'arrête donc jamais artificiellement : chaque partie valide
continue de donner son barème complet, quelle que soit la durée de la session.

## Contrôles automatisés

- Les 12 titres et les quatre paliers de chaque grand niveau sont vérifiés.
- Chacun des 48 seuils ouvre exactement le niveau attendu.
- Les seuils sont strictement croissants de 0 à 66 250 XP.
- Les trois scénarios utilisent directement les seuils du jeu.
- Une augmentation du nombre de parties augmente toujours l'XP totale sans
  plafond quotidien.
- Les identifiants du registre empêchent les doubles récompenses.
- Les publicités, achats, relances payantes, tutoriels et entraînements restent
  techniquement exclus de l'XP.
- La séparation XP joueur / maîtrise GeoBrain reste inchangée.

## Décision V1

Conserver la courbe actuelle jusqu'à la bêta. Les quatre mesures prioritaires à
observer ensuite seront :

1. XP médiane réellement gagnée par partie.
2. Nombre médian de parties par joueur et par semaine.
3. Part réelle des découvertes, maîtrises, missions et accomplissements.
4. Taux d'abandon autour de Navigateur, Géographe et Cartographe.

Une correction de la courbe ne devra être faite qu'après ces observations, sans
ajouter de plafond quotidien et sans transformer l'XP en mesure de connaissance.
