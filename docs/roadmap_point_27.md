# Point 27 — Progression longue du joueur

## État d'avancement

- Étape 27.1 terminée : 12 grands niveaux, 48 paliers et départ à 0 XP.
- Étape 27.2 terminée : courbe initiale de 0 à Maître du monde IV.
- Étape 27.3 terminée : registre central, sources XP et anti-doublon.
- Étape 27.4 en cours : les parties normales, la première réussite du jour, les
  découvertes, les maîtrises, les missions d'expédition et les accomplissements
  utilisent le registre XP.
- Étape 27.5 terminée : anti-doublon, absence de plafond quotidien et refus
  technique des gains publicitaires, payants, tutoriels ou d'entraînement.
- Étape 27.6 terminée : chacun des 48 paliers possède désormais une récompense
  visuelle sans avantage compétitif.
- Étape 27.7 terminée : le Passeport affiche en permanence le prochain palier,
  sa récompense et deux blocs distincts pour l'XP joueur et le GeoBrain.
- Étape 27.8 terminée : une célébration courte est réservée au passage d'un
  grand niveau et les petits paliers n'imposent plus d'écran.
- Étape 27.9 terminée : les seuils, les grands niveaux, le niveau maximal et la
  remise à zéro de l'XP peuvent être simulés avec des commandes réservées au
  mode debug.
- Étape 27.10 terminée : les 48 seuils et trois rythmes de jeu sont testés, et
  le bilan d'équilibrage conserve la courbe actuelle pour la bêta.
- Point 27 terminé côté implémentation. Il reste à confirmer les 170 tests et le
  parcours visuel sur le Pixel 10 avant de passer au point 28.

## Objectif

Créer une progression de compte durable et motivante, sans la confondre avec
la connaissance réelle mesurée par le GeoBrain.

- L'XP joueur mesure l'activité générale dans GeoPoint.
- Le GeoBrain mesure la maîtrise géographique par pays et par thème.
- Les deux progressions sont enregistrées, affichées et classées séparément.
- Tous les joueurs commencent la nouvelle progression à 0 XP.
- Aucune ancienne XP et aucune ancienne action ne sont converties.
- L'XP ne peut jamais être achetée ni obtenue en regardant une publicité.

## 27.1 — Créer le socle de progression

- Remplacer les 100 anciens niveaux par 12 grands niveaux.
- Ajouter quatre paliers internes par grand niveau : I, II, III et IV.
- Conserver une barre d'XP vers le prochain palier.
- Distinguer dans le modèle un passage de palier d'un passage de grand niveau.
- Réinitialiser une seule fois l'ancienne XP joueur lors du chargement.
- Conserver séparément les statistiques, le Passeport et le GeoBrain.

### Grands niveaux retenus

1. Premiers pas
2. Curieux du monde
3. Éclaireur
4. Explorateur
5. Voyageur
6. Aventurier
7. Guide du monde
8. Navigateur
9. Géographe
10. Cartographe
11. Grand cartographe
12. Maître du monde

## 27.2 — Équilibrer la courbe d'XP

- Démarrage rapide : Premiers pas II à 100 XP et Curieux du monde I à 400 XP.
- Allonger progressivement chaque grand niveau.
- Première base d'équilibrage : Maître du monde I à 55 000 XP.
- Dernier palier : Maître du monde IV à 66 250 XP.
- Garder une borne d'équilibrage à 70 000 XP pour mesurer la fin de parcours.
- Ajuster les seuils après des simulations de joueurs occasionnels et réguliers.

## 27.3 — Créer un registre unique des gains d'XP

- Définir un type pour chaque source d'XP.
- Enregistrer la valeur de base, les bonus, la valeur accordée et la date.
- Empêcher qu'une même récompense unique soit accordée plusieurs fois.
- Centraliser les gains afin que les modes de jeu ne modifient jamais l'XP
  directement.

### Règles techniques retenues

- Chaque gain possède un identifiant stable empêchant une double validation.
- Les découvertes, maîtrises, missions, défis, objectifs et accomplissements
  conservent leur identifiant de déblocage sans limite de durée.
- Les identifiants des parties ordinaires sont conservés dans un historique
  roulant afin d'éviter les doubles clics et doubles sauvegardes.
- Le registre conserve les 50 derniers gains pour l'affichage et le diagnostic.
- La valeur de base, le bonus et la valeur réellement accordée sont enregistrés
  séparément.

## 27.4 — Brancher les sources d'XP

- Partie terminée.
- Première réussite du jour.
- Défi terminé ou réussi.
- Mission et examen d'expédition terminés.
- Première découverte d'un pays.
- Première maîtrise d'un pays ou d'un thème.
- Objectif et accomplissement validés.
- Série quotidienne ou hebdomadaire.
- Futurs événements temporaires clairement identifiés.
- Le tutoriel et le mode entraînement restent sans XP.

### Parties normales — branchement validé

- Chaque session reçoit un identifiant de gain stable.
- Le calcul XP passe par le registre avant de modifier le profil.
- Le profil sauvegarde dans la même opération l'XP accordée, le registre et les
  statistiques de la partie.
- L'écran de résultat affiche l'XP réellement accordée.
- Il n'existe aucun plafond quotidien : chaque partie valide accorde son barème
  complet, même pendant une longue session.
- Le garde-fou historique de fin de partie reste actif en complément de
  l'anti-doublon du registre.

### Barème provisoire des parties

- Partie terminée : 15 XP.
- Bonne réponse : 3 XP.
- Partie parfaite : 10 XP supplémentaires.
- Précision moyenne inférieure ou égale à 50 km : 5 XP supplémentaires.
- Difficulté : 0 / 5 / 10 / 15 / 20 XP.
- Maximum actuel d'une partie normale experte parfaite : 80 XP.

### Bonus d'activité et de connaissance validés

- Première partie réussie de la journée locale : 20 XP.
- Une partie est réussie dès qu'elle contient au moins une bonne réponse.
- Première découverte d'un pays après le démarrage de la progression : 5 XP.
- Première maîtrise GeoBrain d'un pays : 40 XP.
- Une découverte correspond au premier passage de « jamais rencontré » à
  « rencontré », même si la première réponse est incorrecte.
- Une maîtrise est accordée uniquement lorsque le statut général GeoBrain du
  pays devient « Maîtrisé » ; une bonne réponse isolée ne suffit pas.
- Les pays déjà découverts ou maîtrisés avant la nouvelle progression ne sont
  jamais convertis rétroactivement en XP.
- Chaque récompense possède un identifiant permanent : une révision, un oubli
  ou une nouvelle partie ne peuvent pas redonner le même bonus.
- L'écran de résultat détaille la partie, la première réussite, les découvertes
  et les maîtrises avant d'afficher le total XP.

### Missions d'expédition validées

- Première validation d'une mission ordinaire avec au moins une étoile : 40 XP.
- Première validation d'un examen, d'un niveau Maître ou d'une finale
  Silhouettes : 100 XP.
- Une amélioration de score ou d'étoiles sur une mission déjà validée ne redonne
  pas le bonus.
- Les missions validées avant le démarrage de la nouvelle progression ne sont
  pas converties rétroactivement en XP.
- La progression d'expédition est sauvegardée avant l'attribution du bonus.
- L'identifiant associe l'expédition et la mission afin d'empêcher toute double
  attribution après un redémarrage ou un double clic.
- Dans les parties cartographiques, le bonus est ajouté au détail du résultat.
- Dans les finales Silhouettes, une confirmation courte affiche le gain au retour
  vers l'expédition.
- Les défis quotidiens et événements restent sans XP tant que leur écran est
  indiqué « Bientôt » et qu'aucune validation réelle n'existe.

### Accomplissements validés

- Premier déblocage d'un palier d'accomplissement normal : 25 XP.
- Premier déblocage d'un palier majeur : 75 XP.
- Une référence initiale permanente est créée avant le premier calcul : tous les
  paliers déjà terminés y sont inscrits sans ajouter la moindre XP.
- Chaque palier futur utilise ensuite un identifiant permanent et ne peut être
  récompensé qu'une seule fois, même après un redémarrage.
- Plusieurs paliers franchis au cours de la même partie sont additionnés dans le
  détail XP du résultat.
- Les accomplissements de voyage personnel restent purement décoratifs : ils ne
  donnent aucune XP et ne créent aucun avantage compétitif.
- Les paliers liés aux étoiles et aux étapes d'expédition sont aussi vérifiés au
  retour des finales Silhouettes et lors d'une amélioration d'étoiles.
- Aucun plafond quotidien ne limite les accomplissements réellement obtenus.

## 27.5 — Empêcher l'exploitation artificielle

- Ne mettre aucun plafond quotidien sur le temps de jeu.
- Refuser l'XP d'une partie abandonnée ou sans action réelle.
- Empêcher les doubles validations après un redémarrage ou un double clic.
- Ne donner aucune XP pour une publicité, un achat ou une relance payante.

### Règle d'équilibrage retenue

- Une partie valide accorde toujours la totalité de son XP.
- L'anti-abus repose sur l'identifiant unique de la session, la validation réelle
  de la fin de partie et l'absence d'XP pour les actions payantes ou passives.
- Le barème pourra être ajusté après les tests, sans limiter le nombre de parties.

## 27.6 — Définir les récompenses

- Chaque palier I déverrouille le titre du nouveau grand niveau.
- Chaque palier II déverrouille un nouveau cadre de Passeport.
- Chaque palier III déverrouille un nouvel arrière-plan de Passeport.
- Chaque palier IV déverrouille un nouvel objet d'avatar.
- Les 12 grands niveaux et les 36 paliers internes possèdent donc tous au moins
  une récompense clairement identifiée.
- La rareté progresse avec le parcours : commune, peu commune, rare, épique puis
  légendaire pour Maître du monde.
- Un saut de plusieurs niveaux déverrouille toutes les récompenses intermédiaires
  sans en perdre aucune.
- Les nouveautés sont regroupées dans l'écran positif de progression après une
  partie ; les finales Silhouettes résument également les récompenses obtenues.
- Les catégories Cadres et Arrière-plans sont accessibles dans Mes collections.
- Les emblèmes restent liés aux accomplissements, à l'exploration et à la
  maîtrise GeoBrain ; ils ne sont pas distribués artificiellement par l'XP.
- Aucun objet ne modifie le score, le temps, la précision, le GeoBrain ou un
  classement.
- Aucun mode principal n'est bloqué par un niveau joueur.

## 27.7 — Mettre à jour le Passeport

- Le grand niveau et son palier sont affichés ensemble : par exemple
  « Cartographe III ».
- Le badge d'en-tête utilise le niveau interne réel de 1 à 48 et non plus le seul
  numéro du grand niveau.
- La carte Niveau joueur affiche l'XP du palier, l'XP totale et une barre claire.
- Le prochain palier, l'XP restante et sa récompense sont toujours visibles dans
  cette carte, y compris lorsqu'un passage débloque plusieurs objets.
- Au niveau maximum, l'objectif est remplacé par un état final explicite sans
  inventer de niveau supplémentaire.
- La maîtrise GeoBrain possède une carte indépendante avec son pourcentage de
  rétention, les pays maîtrisés et les pays à réviser.
- Les textes expliquent directement que l'XP mesure l'activité tandis que le
  GeoBrain mesure les connaissances réelles.
- La carte GeoBrain ouvre son tableau détaillé ; elle ne transforme jamais le
  pourcentage de maîtrise en XP.
- L'XP seule ne doit jamais devenir un classement de connaissances.

## 27.8 — Créer le passage de niveau

- La célébration plein écran apparaît uniquement lorsque le numéro du grand
  niveau augmente, dans les parties cartographiques comme dans les finales
  Silhouettes.
- L'ancien palier et le nouveau palier sont affichés côte à côte.
- Toutes les récompenses de niveau traversées sont listées, y compris lors d'un
  saut de plusieurs paliers ou de plusieurs grands niveaux.
- Le prochain palier et la quantité d'XP restante sont affichés avant de
  continuer vers les résultats.
- L'animation d'entrée dure 420 ms et peut être désactivée indépendamment dans
  les Paramètres ; la préférence d'accessibilité du système réduisant les
  animations est également respectée.
- Désactiver l'animation conserve une présentation statique afin de ne perdre
  ni le nouveau niveau, ni les récompenses, ni le prochain objectif.
- Un simple gain d'XP ou un petit palier ne crée aucun écran forcé. Ses
  récompenses restent immédiatement acquises dans le Passeport.
- Les autres nouveautés réellement obtenues pendant la partie (tampon,
  maîtrise ou accomplissement) restent regroupées dans leur résumé habituel.
- Aucun son ni retour haptique n'est imposé dans cette version.

## 27.9 — Ajouter les outils de développement

- Une entrée « Outils XP de développement » apparaît dans les Paramètres
  uniquement lorsque l'application est lancée en mode debug.
- Une quantité positive et précise d'XP peut être ajoutée sans modifier les
  statistiques de jeu.
- Le profil peut être placé exactement à 1 XP du prochain palier interne.
- Le profil peut être placé exactement à 1 XP du prochain grand niveau afin que
  la partie suivante déclenche le véritable parcours de célébration.
- Le niveau Maître du monde IV peut être atteint directement à son seuil exact
  de 66 250 XP.
- La progression XP peut être remise à zéro avec confirmation. Cette commande
  réinitialise aussi le registre XP de test, mais conserve les parties, scores,
  réponses, temps de jeu, tampons, collections hors niveau, Atlas et GeoBrain.
- Chaque modification est sauvegardée puis synchronisée dans le Passeport 2.0,
  sans nécessiter de redémarrage de l'application.
- L'interface est masquée par `kDebugMode` et le contrôleur refuse également
  toute commande si une invocation était tentée dans une version de production.
- Ces outils ne constituent pas une migration : les vrais joueurs commencent
  toujours à 0 XP et ne reçoivent aucune conversion rétroactive.

## 27.10 — Tester et valider

- Les 12 titres, leurs quatre paliers et chacun des 48 seuils exacts sont
  contrôlés automatiquement.
- Les tests existants couvrent le redémarrage à 0 sans conversion rétroactive,
  la conservation des autres données, les récompenses uniques, les doubles
  validations et les longues sessions sans plafond quotidien.
- Un simulateur réutilisable s'appuie directement sur la courbe et le barème de
  première réussite réellement codés.
- Scénario occasionnel : 6 parties sur 2 jours et environ 300 XP par semaine.
- Scénario régulier : 20 parties sur 5 jours et environ 1 150 XP par semaine.
- Scénario intensif : 50 parties sur 7 jours et environ 3 300 XP par semaine.
- Maître du monde IV est estimé à 221 semaines pour un joueur occasionnel,
  58 semaines pour un joueur régulier et 21 semaines pour un joueur intensif.
- Sans les bonus uniques devenus plus rares, les estimations prudentes sont de
  272, 71 et 25 semaines : les parties continuent toujours d'accorder leur XP.
- Le rapport complet est conservé dans `docs/point_27_balance_report.md`.
- Décision V1 : conserver la courbe de 0 à 66 250 XP jusqu'aux premières
  données réelles de bêta.
- Validation finale à effectuer sur le Pixel 10 : `flutter analyze`, les 170
  tests, les outils debug, un petit palier, un grand niveau et le niveau maximal.

## Validation du point 27

- [x] Le prochain objectif est toujours visible.
- [x] La progression reste motivante sans devenir obligatoire.
- [x] L'XP et la maîtrise GeoBrain ne se modifient jamais directement entre elles.
- [x] Tous les nouveaux parcours commencent à 0 XP.
- [x] Aucun achat et aucune publicité ne donnent un niveau ou un avantage.
- [x] Aucun plafond quotidien ne limite les parties valides.
- [x] Les outils de simulation sont inaccessibles en production.
- [ ] Confirmation finale des tests et du rendu sur Pixel 10.
