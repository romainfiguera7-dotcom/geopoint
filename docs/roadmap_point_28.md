# GeoPoint — Point 28 : défis et GeoPoint Studio

## Objectif général

Créer un système de défis quotidiens, hebdomadaires et mensuels qui donne une
raison de revenir régulièrement, sans rendre les classements inéquitables et
sans exposer les profils enfants à la publicité.

## 28.1 — Socle des données — terminé

- Modèle complet de défi.
- Périodes quotidienne, hebdomadaire et mensuelle.
- Modes, difficulté, zone géographique, durée ou nombre de questions.
- Conditions de réussite, premier essai, recommencements et récompenses.
- Variantes enfant.
- Règles classées identiques et GeoBrain interdit en classement.

## 28.2 — Calendrier et sécurité — terminé

- Heure serveur prioritaire.
- Estimation locale hors ligne.
- Blocage d’un recul anormal de l’heure du téléphone.
- Récompense hors ligne conservée en attente de validation.
- Identifiant permanent empêchant une double récompense.

## 28.3 — Pack de septembre 2026 — terminé

- 30 défis quotidiens.
- Un seul défi actif par semaine, soit quatre missions sur le mois.
- Un seul grand défi mensuel.
- Premier essai gratuit puis recommencements illimités avec publicité
  récompensée pour un profil adulte.
- Variantes enfant sans publicité, avec recommencements gratuits illimités.
- Configuration compacte fondée sur des modèles réutilisables.

## 28.4 — Écrans des défis — terminé

- Accès depuis l’espace Jouer.
- Défi du jour mis en avant.
- Une carte pour le défi du jour, une pour celui de la semaine et une pour
  celui du mois.
- Détail complet des règles avant lancement.
- Règle de recommencement affichée clairement.
- Récompenses et durée restante visibles.
- Historique récent.

## 28.5 — Lancement des parties — terminé

- Transformer chaque défi en configuration de partie GeoPoint.
- Respecter le mode, la difficulté, la sélection géographique et la durée.
- Utiliser GeoBrain uniquement lorsque le défi personnel l’autorise.
- Enregistrer le meilleur score et le nombre de bonnes réponses.
- Vérifier automatiquement les conditions de réussite à la fin.
- Utiliser une sélection et un ordre déterministes dans les défis classés.
- Prendre en charge Pays, Capitales, Drapeaux, Mixte et Silhouettes.

## 28.6 — Résultats et récompenses — terminé

- Écran de réussite ou d’échec.
- Attribution unique de l’XP.
- Porte-monnaie persistant pour les pièces et les diamants.
- Progression mensuelle et hebdomadaire cumulée.
- Déblocage des tampons, emblèmes et objets cosmétiques.
- Récompenses hors ligne en attente jusqu’à la prochaine validation serveur.
- Registre de versement indépendant empêchant toute double attribution.
- Récupération automatique d’un versement confirmé interrompu.
- Affichage des soldes et des récompenses réellement reçues.

## 28.7 — Recommencements — terminé

- Accorder un premier essai gratuit au profil adulte.
- Proposer ensuite une publicité récompensée à chaque recommencement, sans
  plafond de nombre de tentatives.
- Ne pas proposer de relance en diamant dans ce pack simplifié.
- Ne jamais afficher de publicité dans une variante enfant ; ses
  recommencements restent gratuits et illimités.
- Simuler la publicité uniquement dans les versions de développement jusqu’au
  branchement du compte publicitaire réel.

## 28.8 — Prévisualisation et contrôle interne — terminé

- Visualiser les cartes joueur avant publication.
- Simuler une date, une heure et un niveau de joueur de 1 à 100.
- Basculer entre un profil adulte et un profil enfant.
- Vérifier les pays, périodes, récompenses et variantes enfant.
- Signaler visuellement deux défis du même rythme actifs simultanément.
- Désactiver ou réactiver rapidement un défi incorrect.

Studio génère aussi une variante Découverte lorsqu’un défi exige un niveau
supérieur à 1. Un débutant conserve ainsi un contenu adapté, sans accéder aux
règles classées du défi principal.

## 28.9 — GeoPoint Studio local — terminé

Créer une interface de gestion séparée du jeu permettant à Romain de :

- créer, modifier, dupliquer et supprimer un brouillon de défi ;
- choisir les dates dans son fuseau horaire ;
- sélectionner le mode, la difficulté, le continent ou les pays ;
- régler les conditions, la période et les récompenses ;
- appliquer automatiquement la règle adulte « premier essai gratuit puis
  publicité illimitée » et la règle enfant sans publicité ;
- générer une variante enfant ;
- prévisualiser le résultat ;
- détecter les erreurs ;
- exporter un pack JSON sans modifier le code de GeoPoint.

L’accès est volontairement limité aux versions de développement grâce à
`kDebugMode`. Studio enregistre les brouillons sur l’appareil et copie le pack
JSON validé dans le presse-papiers. Il génère automatiquement une variante
enfant sans publicité pour chaque défi adulte.

## 28.10 — GeoPoint Studio connecté — socle terminé

- Site d’administration privé séparé de l’application joueur.
- Connexion administrateur sécurisée.
- Brouillon, validation, programmation, publication et désactivation.
- Historique des versions et retour à une version précédente.
- Publication directe sans nouvelle version sur les stores.
- Application GeoPoint en lecture seule sur les packs publiés.

Le jeu possède maintenant un dépôt de packs indépendant de l’hébergeur :

- réception d’un pack distant avec numéro de révision et heure serveur ;
- validation complète avant acceptation ;
- cache du dernier pack distant valide ;
- refus d’une révision plus ancienne ;
- révision identique rendue immuable ;
- retour au cache, puis au pack inclus, en cas de panne ou de pack incorrect ;
- affichage de la source réellement utilisée dans le centre des défis.

Le branchement concret du compte administrateur et de la base distante reste à
faire après le choix de l’hébergeur.

## 28.11 — Serveur et synchronisation — en cours

- Heure de référence serveur.
- Téléchargement du pack actif avec cache hors ligne.
- Validation des récompenses en attente.
- Protection contre la modification de l’heure ou de la sauvegarde locale.
- Préparation des classements équitables.

Le cache hors ligne, la récupération de l’heure serveur et le protocole de
validation des récompenses sont prêts. La synchronisation :

- envoie chaque demande avec son identifiant permanent et les preuves de
  partie disponibles ;
- exige une réponse pour chaque récompense en attente ;
- utilise uniquement la récompense autoritaire renvoyée par le serveur ;
- clôt une demande refusée sans distribuer de gain ;
- conserve intégralement les demandes lorsque le serveur est indisponible ou
  répond de façon incohérente ;
- verse chaque récompense confirmée une seule fois, y compris après un
  redémarrage ;
- met à jour l’heure de confiance avec l’heure renvoyée par le serveur.

Un point de branchement commun permet maintenant de connecter les packs et les
récompenses à Firebase, Supabase ou un serveur personnel sans modifier les
écrans.

La préparation des résultats classés est également terminée :

- tous les défis standards participent automatiquement au classement et sont
  accessibles dès le niveau 1 ;
- les variantes enfant restent sans publicité et hors classement public ;
- seuls le score, les bonnes réponses, la précision et le temps sont envoyés ;
- les XP, pièces, diamants, achats et cosmétiques n’influencent jamais le
  classement ;
- la signature des règles accompagne chaque résultat afin que le serveur
  puisse vérifier que les joueurs ont reçu une épreuve comparable ;
- chaque résultat possède un identifiant permanent empêchant les doubles
  envois ;
- un résultat suspect peut être mis en quarantaine sans recevoir de position ;
- une position validée contient le rang, le nombre de participants et
  l’évolution depuis le rang précédent ;
- le départage prévu est score, puis précision, puis temps ;
- les variantes débutant et enfant restent hors du classement adulte.

Il reste à choisir l’hébergeur, connecter l’authentification réelle et créer
les écrans complets de classement du point 29.

## 28.12 — Validation finale

- Un défi incomplet ou expiré ne distribue rien.
- Une récompense n’est jamais distribuée deux fois.
- Chaque règle est comprise avant le lancement.
- Les contenus restent variés pendant plusieurs semaines.
- Les profils enfants n’affichent aucune publicité.
- Un défi incorrect peut être désactivé rapidement.
- Romain peut préparer un nouveau mois depuis GeoPoint Studio sans toucher au
  code du jeu.
