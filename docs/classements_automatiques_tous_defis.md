# GeoPoint — Classements automatiques sur tous les défis

## Règle produit

- chaque défi standard quotidien, hebdomadaire ou mensuel est classé ;
- aucune case « Participer au classement » n'est affichée ;
- tous les défis standards sont accessibles dès le niveau 1 ;
- chaque tentative est validée par Firebase et peut améliorer le record ;
- seule la meilleure partie est conservée dans le classement ;
- les récompenses restent accordées une seule fois ;
- après l'essai gratuit, les nouvelles tentatives adultes utilisent la relance
  publicitaire illimitée prévue par le défi ;
- les variantes enfant restent gratuites, sans publicité et hors classement
  public.

Les anciens packs et brouillons sont normalisés au chargement. Un défi standard
reçoit automatiquement son propre `rankingGroupId`, le niveau minimum 1 et une
configuration compétitive identique pour tous. Le Studio n'affiche plus de
réglage permettant de désactiver cette politique.

## Vérification dans l'app

1. Ouvrir l'écran Défis avec un joueur de niveau 1.
2. Vérifier que les défis quotidien, hebdomadaire et mensuel sont visibles.
3. Ouvrir chacun d'eux : la carte doit afficher « Classement automatique
   activé » sans interrupteur.
4. Terminer une partie puis la rejouer : la meilleure tentative doit rester
   conservée.
5. Vérifier la création des documents de session et de résultat dans Firestore.

## Publicité

Le flux de relance est prêt, mais l'écran publicitaire actuel est une simulation
en mode debug. Aucun chiffre d'affaires réel ne sera généré avant le branchement
d'un réseau publicitaire (par exemple AdMob), le consentement requis et la
configuration des identifiants de production Android/iOS.

## Installation et déploiement

Depuis PowerShell, fermer d'abord une éventuelle session `flutter run` avec
`q`, puis exécuter :

```powershell
cd D:\romai\GEOPOINT\geopoint
.\android\gradlew.bat --stop

Expand-Archive `
  "$env:USERPROFILE\Downloads\geopoint_classements_automatiques_tous_defis_corrige_v2.zip" `
  "D:\romai\GEOPOINT\geopoint" -Force

dart format `
  lib\challenges\challenge_pack_loader.dart `
  lib\challenges\challenge_pack_validator.dart `
  lib\challenges\challenge_studio_draft.dart `
  lib\features\challenges\challenge_detail_screen.dart `
  lib\features\challenges\challenge_result_screen.dart `
  lib\features\challenges\challenge_studio_editor_screen.dart `
  lib\features\challenges\challenges_screen.dart `
  test\challenges\challenge_pack_test.dart `
  test\challenges\challenge_pack_validator_test.dart `
  test\challenges\challenge_studio_draft_test.dart `
  test\challenges\challenge_studio_preview_test.dart

flutter pub get
flutter analyze
flutter test
npm --prefix functions run check
firebase deploy --only "firestore:rules,firestore:indexes,functions"
flutter run
```
