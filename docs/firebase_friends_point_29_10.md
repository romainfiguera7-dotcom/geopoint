# Point 29.10 — Amis par code et classements privés

## Expérience joueur

L'écran `CLASSEMENTS` possède désormais deux portées :

- `MONDE` affiche le classement public existant ;
- `AMIS` recalcule les rangs uniquement entre le joueur et ses amis.

Les onglets `JOUR`, `SEMAINE` et `SAISON` restent disponibles dans les deux
portées. Le score utilisé est toujours la meilleure partie du défi : ajouter
des amis ne change ni le calcul, ni l'anti-triche, ni les récompenses.

Le bouton de gestion des amis est accessible depuis `CLASSEMENTS` et par un
raccourci dans `MON PASSEPORT`. Il permet de :

- copier son code personnel au format `GP-ABCD-EFGH` ;
- ajouter un joueur avec son code ;
- accepter ou refuser une demande reçue ;
- annuler une demande envoyée ;
- supprimer ou bloquer un ami ;
- consulter et débloquer les joueurs bloqués.

## Données Firebase

- `friend_codes/{code}` associe un code aléatoire à un UID sans être lisible
  directement par le client.
- `friend_requests/{pairId}` conserve l'état d'une demande pour une paire de
  joueurs.
- `friendships/{uid}/members/{friendUid}` contient la relation symétrique.
- `friend_blocks/{uid}/blocked/{blockedUid}` contient les blocages privés.

Toutes les écritures utilisent le SDK Admin dans les Cloud Functions. Les
règles Firestore interdisent toute lecture ou écriture directe, y compris sur
`public_profiles`. Les réponses callables n'affichent jamais l'adresse e-mail
ni l'identifiant Firebase ; l'identifiant interne reçu par Flutter sert
uniquement aux actions sur la relation.

## Protections

- Firebase Authentication et App Check sont obligatoires.
- Les codes utilisent huit caractères aléatoires sans caractères ambigus.
- Un joueur ne peut pas s'ajouter lui-même.
- Une paire ne peut posséder qu'une demande active.
- Les limites sont de 50 amis et 20 demandes en attente.
- Un délai empêche les envois répétés en rafale.
- Les blocages sont vérifiés dans les deux sens.
- Un profil déjà signalé comme enfant est refusé par les fonctions sociales.
  Le raccordement définitif avec les profils familiaux sera renforcé au point
  29.11.

## Déploiement

Le point 29.10 ajoute trois callables en `europe-west1` :

- `getFriendDashboard` ;
- `sendFriendRequest` ;
- `updateFriendRelation`.

Il modifie également `getChallengeLeaderboards`, les règles Firestore et deux
index composites destinés aux demandes entrantes et sortantes.
