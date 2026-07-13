# Changelog

Toutes les modifications notables de ce projet sont documentées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et le projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [0.2.0] - 2026-07-13

### Ajouté
- Architecture Provider généralisée : `AuthProvider` centralise l'authentification
  et l'accès au profil, `ProfilePage` ne dépend plus directement de `SupabaseService`
- Couverture de tests étendue à 67,8% du code exécutable de `lib/` (57 tests unitaires
  et widgets), avec un seuil minimal de 50% imposé en CI
- Accessibilité (référentiel RGAA) : noms accessibles sur tous les boutons à icône
  seule, distinction images décoratives/informatives, contrastes vérifiés et corrigés
  — voir `ACCESSIBILITE.md`
- Cahier de recettes (`CAHIER_DE_RECETTES.md`) et plan de correction des bogues
  (`PLAN_CORRECTION_BOGUES.md`)
- Manuels de déploiement, d'utilisation et de mise à jour
- Fichiers de migration SQL versionnés dans `supabase/migrations/` (le schéma
  n'existait auparavant que dans le projet Supabase, jamais dans le dépôt)

### Corrigé
- Méthode de calcul de la couverture de tests (division par le nombre brut de
  lignes au lieu des lignes exécutables identifiées par l'outil de couverture),
  qui plafonnait le pourcentage artificiellement bien avant 50%
- `_loadUserProfile()` appelait le Navigator de façon synchrone pendant
  `initState()`, ce qui plantait pour un utilisateur non connecté ouvrant son profil
- Build APK cassé en CI : version de NDK figée en dur, remplacée par
  `flutter.ndkVersion` (déjà en cache, plus de téléchargement)
- Deux icônes sous le seuil de contraste WCAG de 3:1

## [0.1.0] - 2026-07-04

Première version suivie sous ce schéma de versioning. Le `1.0.0+1` initial
venait du scaffold `flutter create` et ne reflétait aucune version réelle du
produit : on repart sur une base honnête (`0.x`, pré-version).

### Ajouté
- Authentification complète via Supabase Auth (inscription, connexion,
  déconnexion)
- Schéma de base de données Supabase (`users`, `campaigns`, `characters`,
  `images`) avec RLS sur toutes les tables, et 3 buckets de stockage
  (`avatars`, `images`, `maps`)
- Architecture Provider avec `AuthProvider` centralisant l'état de connexion
- CI/CD GitHub Actions : analyse statique + tests à chaque push/PR, build web
  déployé sur GitHub Pages, build APK en artefact téléchargeable
- Tests unitaires (`AuthProvider`, avec mocktail) et tests widgets
  (`LoginPage`, `RegisterPage`)
- Messages d'erreur traduits en français pour les erreurs Supabase Auth
  courantes (identifiants invalides, email non confirmé, compte déjà
  existant, etc.)
- Écran d'erreur explicite si l'initialisation de Supabase échoue, au lieu
  d'un crash silencieux au démarrage

### Corrigé
- Conflit Git non résolu resté commité dans le README
- Hash SHA-256 non salé et redondant du mot de passe, stocké en plus de
  l'authentification Supabase (faille de sécurité, catégorie OWASP A02)
- Crash garanti sur le web : `Platform.environment` (`dart:io`) n'existe pas
  sur Flutter Web
- `createUserProfile` n'enregistrait jamais l'id utilisateur : avec les RLS
  actives, chaque inscription aurait échoué silencieusement
- Plusieurs warnings d'analyse statique (imports dupliqués/inutilisés,
  champs de formulaire jamais lus, comparaison null devenue impossible)
