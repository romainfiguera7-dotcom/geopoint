# Point 29 — Ajouter les classements

## État d'avancement

- Étape 29.1 terminée : toutes les tentatives classées possèdent un identifiant
  distinct et le meilleur résultat est conservé selon score, précision, puis
  temps.
- Étape 29.2 terminée : chaque installation possède une identité locale stable,
  les anciens profils `local_player` sont rattachés sans perte de progression et
  les classements officiels attendent la liaison réelle d'un compte.
- Étape 29.3 connectée : Android et iOS utilisent le projet `geopoint-dev`,
  l'authentification anonyme, App Check et les fonctions callable sont branchés.
  Le jeu reste entièrement utilisable en local si Firebase est indisponible.
  Les règles Firestore et les cinq premières fonctions sont déployées.
- Étape 29.4 terminée dans le code : chaque tentative standard ouvre
  une session officielle Firebase avant le jeu. Elle est liée au joueur, au
  défi actif, au groupe de classement et à la signature compétitive, puis
  expire au plus tard après 45 minutes. Son déploiement ajoute la fonction
  `startOfficialChallengeSession`.
- Étape 29.5 terminée dans le code : chaque réponse fournit une preuve minimale
  au serveur, qui recalcule le score, les bonnes réponses, la distance moyenne
  et le temps. Chaque tentative est archivée, mais `ranking_records` ne garde
  que la meilleure partie selon le départage officiel. Depuis 29.7, une
  migration de progression en attente ne bloque plus un score vérifié.
- Étape 29.6 terminée dans le code : une politique anti-triche prudente analyse
  les séries complètes et l'âge réel de la session. Une tentative suspecte est
  conservée en quarantaine, exclue du meilleur score et inscrite dans une file
  de vérification privée. Une réponse rapide isolée n'est jamais sanctionnée.
- Étape 29.7 terminée dans le code : les meilleurs scores validés alimentent un
  classement du jour, un classement de la semaine et une saison mensuelle. Le
  top 25 et la position personnelle sont consultables depuis le hub Défis sur
  Android et iOS. La base de l'écran prévue au point 29.9 est ainsi anticipée.
- Étape 29.8 terminée dans le code : la saison se clôture après un délai de
  sécurité d'une heure, Firebase calcule le rang final et verse une récompense
  unique. Tous les participants gagnent quelque chose et les paliers sont
  visibles dans l'onglet Saison.
- Correction de synchronisation terminée : une tentative est maintenant
  transmise à Firebase immédiatement à la fin de la partie. Son statut réel
  est visible sur l'écran de résultat et la file locale reste le mécanisme de
  secours hors connexion.
- Étape 29.9 terminée dans le code : le top 3 possède désormais un podium
  visuel, chaque ligne ouvre une fiche publique limitée aux statistiques du
  classement et le joueur connecté retrouve ses 20 dernières tentatives avec
  leur état de validation. Cet historique reste strictement personnel.
- Étape 29.10 terminée dans le code : chaque joueur adulte reçoit un code ami
  aléatoire, peut envoyer, accepter, refuser ou annuler une demande, gérer sa
  liste et ses blocages, puis comparer les meilleurs scores du jour, de la
  semaine et de la saison uniquement avec ses amis. Aucun e-mail ni UID n'est
  affiché dans l'application.
- Étape 29.11 terminée dans le code : un responsable peut protéger le profil
  actif avec une tranche d’âge à partir de 6 ans. Le profil utilise les défis
  enfant gratuits et perd toute exposition aux publicités, achats, amis,
  classements publics et récompenses de saison. Firebase rend cette protection
  irréversible depuis l’application et efface les anciennes données publiques.
- Étape 29.12 terminée : le contrôle interne recherche les joueurs et les
  tentatives, traite les quarantaines, annule ou rétablit un score, suspend une
  compétition, reconstruit les classements et conserve une trace d’audit.
- Étape 29.13 démarrée : Android possède désormais une vraie configuration de
  signature `release`, refuse explicitement une publication signée en mode
  débogage et fournit deux outils PowerShell pour créer la clé d’envoi puis
  vérifier automatiquement les tests et l’App Bundle de bêta.

## Règles validées

- Toutes les tentatives autorisées peuvent améliorer le classement.
- Le meilleur résultat est conservé ; une partie moins bonne ne fait jamais
  baisser le record.
- Un défi classé peut être rejoué après sa réussite.
- Les récompenses restent uniques, même lorsque le défi est rejoué.
- Une tentative échouée reste classable selon son score.
- Chaque tentative est envoyée séparément au futur serveur.
- Le départage est : score le plus élevé, distance moyenne la plus faible, puis
  temps total le plus court.
- Tous les défis standards sont automatiquement classés et accessibles dès le
  niveau 1, sans option à activer.
- Les variantes enfant restent sans publicité et hors classement public.
- L'XP, les pièces, les diamants et les cosmétiques ne sont pas des critères de
  classement.

## Prochaines étapes

1. Valider 29.10 sur `geopoint-dev` avec deux comptes distincts dès qu’un second
   appareil ou émulateur est disponible.
2. Déployer et valider 29.11 sur un profil de test dédié.
3. 29.12 — Outils internes et traitement manuel des quarantaines. **Livré :**
   recherche sécurisée, validation/refus, annulation/rétablissement,
   suspension de compétition, recalcul et journal d'audit.
4. 29.13 — Tests et bêta progressive. **Bloc Android prêt dans le code :**
   générer et sauvegarder la clé d’envoi, construire le premier App Bundle,
   l’installer via le test interne Google Play, puis ouvrir le test fermé.
