# Point 29.11 — Protection des profils enfants

## Comportement dans l’application

Le mode enfant s’active depuis **Jouer > Mode enfant**. Le responsable choisit
uniquement une tranche d’âge (6–8, 9–11, 12–14 ou 15–17 ans) : aucune date de
naissance n’est enregistrée.

L’activation est volontaire et ne peut pas être retirée depuis l’application.
Elle conserve la progression locale mais applique immédiatement les règles
suivantes :

- variantes enfant des défis ;
- tentatives gratuites et aucune publicité ;
- aucun achat ;
- aucun classement public ni récompense de saison ;
- aucun code ami, demande d’ami ou classement entre amis ;
- pseudonyme et avatar absents des surfaces publiques.

Les profils adultes existants restent adultes : aucune migration automatique
ne modifie leur expérience.

## Protection Firebase

`registerPlayerIdentity` enregistre une politique de sécurité dans
`players/{uid}` :

- `profileType: child` ;
- `isChild: true` ;
- `advertisementsAllowed: false` ;
- `purchasesAllowed: false` ;
- `socialAllowed: false` ;
- `publicRankingAllowed: false`.

Une fois le compte marqué enfant, une demande ultérieure `profileType: adult`
ne le retransforme jamais en adulte. Le serveur invalide le code ami, ferme les
demandes en attente, retire les relations, supprime les entrées de classement
publiques et protège `public_profiles/{uid}`.

Les fonctions de session classée, soumission de score, lecture des classements,
amis et récompenses de saison contrôlent toutes le statut stocké par le
serveur. Les règles ne reposent donc pas uniquement sur l’interface Flutter.

## Limite volontaire de cette étape

Le point 29.11 sécurise le profil actif. Le compte familial avec plusieurs
profils enfants indépendants et l’espace parental complet restent le chantier
transversal prévu aux points 21 à 24.

