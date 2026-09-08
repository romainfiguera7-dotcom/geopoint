# Point 29.9 — Podiums, fiches publiques et historique

## Expérience joueur

- Les trois meilleurs joueurs sont présentés sur un podium dans les onglets
  Jour, Semaine et Saison.
- Un appui sur un joueur ouvre une fiche résumant uniquement les statistiques
  déjà publiques du classement : rang, score, temps, précision et nombre de
  défis selon l'onglet.
- Le bouton `MON HISTORIQUE` ouvre les 20 dernières tentatives du joueur
  connecté, classées de la plus récente à la plus ancienne.
- Chaque tentative indique son état : validée, en vérification ou refusée.
- Le badge `MEILLEUR` identifie la partie actuellement retenue. Une nouvelle
  tentative moins bonne reste visible dans l'historique sans réduire le score
  classé.

## Contrat Firebase

`getChallengeLeaderboards` renvoie maintenant `currentPlayerHistory` en plus
des trois tableaux existants. Le serveur lit uniquement la sous-collection du
joueur authentifié et ne renvoie ni UID, ni preuve de réponse, ni information
anti-triche interne.

Chaque entrée publique contient seulement :

- l'identifiant technique de soumission et du défi ;
- le titre du défi et sa date de fin ;
- le score, les bonnes réponses et le temps ;
- l'état public de validation et l'indication de meilleure partie.

La fonction reste protégée par Firebase Authentication et App Check. Le rôle
Cloud Run `allUsers/run.invoker` autorise uniquement l'arrivée de l'appel HTTP ;
les contrôles Firebase sont ensuite obligatoires dans la callable.

## Déploiement

Seule la fonction `getChallengeLeaderboards` doit être redéployée pour cette
étape. Aucun changement de règles ou d'index Firestore n'est nécessaire : la
lecture porte sur un champ simple `completedAtUtc` et est limitée à 20 documents.
