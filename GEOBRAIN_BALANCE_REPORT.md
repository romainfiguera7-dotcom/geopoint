# GeoBrain — Rapport d’équilibrage du point 26.10

## Profils simulés

| Profil | Historique simulé | Résultat attendu |
| --- | --- | --- |
| Nouveau joueur | Aucune tentative | Difficulté facile, aucune révision, découverte progressive |
| Joueur régulier | 10 réussites réparties sur plusieurs jours | Connaissance maîtrisée, difficulté relevée d’un palier |
| Joueur revenant | Connaissance maîtrisée puis 90 jours d’absence | Confiance réduite progressivement, statut positif « À réviser » |

## Garde-fous vérifiés

- Une seule réussite ne peut pas produire une maîtrise.
- Le statut `Maîtrisé` demande au moins huit preuves et un score de 80 %.
- Les réponses récentes ont davantage de poids que les anciennes.
- Deux erreurs consécutives diminuent nettement la confiance.
- Une connaissance maîtrisée et encore stable n’est pas proposée inutilement.
- La mémoire de sélection évite de reprendre le même pays dans deux séances
  successives lorsque le catalogue permet de faire autrement.
- Deux historiques différents produisent des suggestions différentes.
- Les pays annoncés par une suggestion de révision existent dans l’historique
  correspondant du joueur.

## Équité des petits pays

La taille géographique et la distance enregistrée ne participent pas au calcul
de maîtrise d’une réponse déjà validée. Les mêmes réussites donnent donc le
même score à la France et à Saint-Marin. Les seuils sont communs à tous les
pays et territoires.

## Mode enfant et aides

Une réussite en mode enfant reste encourageante et fait progresser le score,
mais son poids est volontairement limité :

- poids du contexte enfant : 55 % ;
- poids d’une difficulté découverte : 70 % ;
- poids supplémentaire d’une réussite avec aide : 45 %.

Les erreurs restent informatives et ne sont pas masquées par l’aide. Les
tentatives du mode enfant ne provoquent jamais une hausse automatique de la
difficulté adulte.

## Oubli et retour

L’oubli ne modifie pas le score sauvegardé. Après la période de grâce, seule la
confiance affichée diminue progressivement, avec un plancher à 65 % du score
enregistré. Le joueur voit toujours « À réviser » et jamais « Perdu ».

## Couverture automatique

Le point 26.10 ajoute 13 scénarios intégrés. Le projet contient désormais 118
tests automatisés couvrant la maîtrise, l’oubli, la difficulté adaptative, la
sélection personnalisée, les suggestions et le tableau de bord GeoBrain.
