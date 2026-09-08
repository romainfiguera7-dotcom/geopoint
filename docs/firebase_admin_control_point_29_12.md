# GeoPoint — Outils internes de contrôle du point 29.12

## Emplacement dans l'application

Le contrôle interne est accessible en version de développement depuis
`Défis > GeoPoint Studio > Contrôle interne`. Le bouton GeoPoint Studio reste
absent des versions publiques de production.

L'interface seule ne donne aucun droit. Chaque callable vérifie :

- Firebase Authentication ;
- Firebase App Check ;
- le custom claim Firebase `admin: true`.

## Fonctions livrées

- recherche par UID, identifiant de tentative ou groupe de classement ;
- file des tentatives placées en quarantaine ;
- validation ou refus manuel d'une quarantaine ;
- annulation et rétablissement d'un score déjà validé ;
- reconstruction des meilleurs scores du joueur et de ses contributions de
  saison après chaque décision ;
- suspension/réactivation d'une compétition sans mise à jour mobile ;
- recalcul des clés de rang d'une compétition ;
- compteurs de sessions actives, refus et vérifications en attente ;
- journal d'audit avec administrateur, motif, cible, état précédent et nouvel
  état.

Une compétition suspendue est refusée par
`startOfficialChallengeSession`. Les écritures directes depuis l'application
restent interdites par les règles Firestore.

## Attribution du premier rôle administrateur

Le script `functions/scripts/grant_admin.js` modifie uniquement les custom
claims du compte indiqué. Il nécessite des identifiants Google Application
Default Credentials ou une clé de compte de service conservée hors du projet.

Après attribution, le transport Flutter force le renouvellement des jetons
Firebase avant tout appel d'administration afin de prendre le claim en compte.

## Limites volontaires

- au plus 30 résultats sont affichés dans l'application ;
- la reconstruction d'un joueur examine au plus 500 tentatives ;
- le recalcul d'une compétition traite au plus 5 000 entrées par commande ;
- chaque action sensible exige un motif de 5 à 300 caractères.
