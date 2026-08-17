# Maintenance en condition opérationnelle

Ce document couvre le monitoring, le traitement des anomalies et la
maintenance de Scriptoria une fois le logiciel déployé — Bloc 4 du
référentiel (A4.1 à A4.3).

## A4.1 — Monitorer l'application logicielle

### Mise à jour des dépendances

Processus détaillé dans [MANUEL_MISE_A_JOUR.md](MANUEL_MISE_A_JOUR.md) :
vérification manuelle ponctuelle (`flutter pub outdated`), relecture des
changelogs, `flutter analyze` + `flutter test` avant tout commit,
`pubspec.lock` versionné.

**Exemple réel appliqué pendant ce travail de monitoring** : l'ajout de
`firebase_performance` a révélé deux incompatibilités qu'il a fallu évaluer
et corriger avant de merger :
- Le plugin Gradle de `firebase_performance` utilise le DSL
  `compilerOptions {}`, absent du Kotlin Gradle Plugin 1.8.22 (version par
  défaut du template Flutter à la création du projet) → relevé à **2.1.0**
  dans [`android/settings.gradle.kts`](android/settings.gradle.kts).
- `firebase_performance` exige `minSdk 23` (Android 6.0) ; le projet était à
  21 → relevé dans [`android/app/build.gradle.kts`](android/app/build.gradle.kts).
  Impact évalué : perte du support Android < 6.0 (2015), une version
  aujourd'hui résiduelle dans les parts de marché réelles — compromis
  assumé plutôt que de renoncer au monitoring de performance.

### Système de supervision et d'alerte

**Outil retenu : Firebase (Crashlytics + Performance Monitoring)**, plutôt
que Sentry — comparé pour leurs plans gratuits respectifs, Firebase a été
préféré car Crashlytics et Performance Monitoring sont **gratuits sans
quota** (contrairement au plan gratuit de Sentry, limité en nombre
d'événements/transactions par mois), et parce que Performance Monitoring
répond directement à un besoin identifié pour une fonctionnalité à venir
(un tableau interactif, riche en animations, où le suivi des frames
lentes/gelées sera utile).

| Élément | Détail |
|---|---|
| **Périmètre de supervision** | Toute l'application (mobile Android + web), tous les écrans |
| **Sondes mises en place** | `FlutterError.onError` → `FirebaseCrashlytics.recordFlutterFatalError` (erreurs de rendu/framework) ; `PlatformDispatcher.instance.onError` → `FirebaseCrashlytics.recordError(fatal: true)` (erreurs Dart asynchrones échappant au framework) ; Performance Monitoring instrumente automatiquement le temps de démarrage de l'app et les frames lentes/gelées par écran, sans code supplémentaire |
| **Finalité de chaque sonde** | Détecter tout crash ou erreur non gérée en conditions réelles (pas seulement en dev/tests), avec sa stack trace complète et le contexte (device, version d'app, utilisateur) ; détecter les écrans qui rament avant qu'un joueur ne s'en plaigne |
| **Seuils d'alerte** | Alertes de vélocité natives de Firebase Crashlytics : email automatique aux membres du projet en cas de pic de plantages sur une version donnée — aucune configuration manuelle de seuil requise, c'est le comportement par défaut de l'outil |
| **Modalité de signalement** | Email (comptes membres du projet Firebase), consultable aussi en continu sur le dashboard [console.firebase.google.com](https://console.firebase.google.com) |
| **Disponibilité** | Web déployé sur GitHub Pages : disponibilité déjà surveillable indirectement via le badge de statut CI (échec de build/déploiement visible immédiatement) ; Performance Monitoring ajoute la disponibilité applicative fine (l'app se charge-t-elle, reste-t-elle réactive) que la CI seule ne peut pas voir |

**Vérification réalisée** — Test contrôlé le 2026-08-09 : l'application a été
compilée en configuration release (`flutter build apk --release`) et
installée sur un appareil physique Android avec la vraie configuration
Firebase du projet. Un plantage volontaire a été déclenché depuis l'app
(`FirebaseCrashlytics.instance.crash()`, méthode officielle du SDK prévue
pour ce test), confirmé dans les logs de l'appareil
(`FirebaseCrashlyticsTestCrash: This is a test crash caused by calling
.crash() in Dart.`) — la chaîne complète (déclenchement → capture par le SDK
→ écriture locale → envoi au relancement de l'app → dashboard) a ainsi été
exercée de bout en bout, et pas seulement mise en place sur le papier.

`[Capture d'écran : le crash test dans le dashboard Crashlytics, avec sa stack trace]`

**Mise en œuvre technique** ([lib/main.dart](lib/main.dart), fonction
`_initializeMonitoring()`) : l'initialisation est *best-effort* et englobée
dans un `try/catch` — si `firebase_options.dart` contient des valeurs
factices (dépôt cloné sans projet Firebase configuré) ou si le réseau est
indisponible, l'application continue de fonctionner normalement sans
monitoring plutôt que de planter au démarrage. Le monitoring ne doit jamais
devenir un point de défaillance pour le reste de l'app. La collecte est
désactivée en mode debug (`!kDebugMode`) pour ne pas polluer le dashboard
avec des erreurs de développement.

**Secrets requis en CI/CD** pour que les artefacts publiés (APK, démo web)
embarquent une vraie configuration Firebase : voir
[MANUEL_DEPLOIEMENT.md](MANUEL_DEPLOIEMENT.md). Sans ces secrets, la CI reste
verte (repli automatique sur une configuration factice, voir `ci.yml`) mais
le monitoring de l'artefact publié reste inactif tant qu'ils ne sont pas
renseignés.

## A4.2 — Traitement des anomalies détectées en production

### Processus de collecte et de consignation

Toute anomalie (détectée manuellement, remontée par un joueur, ou captée
par Crashlytics) est consignée dans
[PLAN_CORRECTION_BOGUES.md](PLAN_CORRECTION_BOGUES.md) avec un identifiant
(`Bxx`), sa gravité, la façon dont elle a été détectée, et son correctif une
fois traitée. Chaque anomalie liée à un scénario utilisateur est également
référencée dans [CAHIER_DE_RECETTES.md](CAHIER_DE_RECETTES.md).

### Fiche de consignation — exemple réel (B18)

| Champ | Détail |
|---|---|
| **ID** | B18 |
| **Titre** | La room affichée après création/jointure montre un contenu de démonstration, pas les vraies données |
| **Détecté par** | Constat manuel lors de la correction de B13/B14 (persistance de la création/jointure de room) |
| **Gravité** | Majeure — visible immédiatement lors de toute démonstration |
| **Environnement** | Toutes plateformes (mobile Android, web), toutes versions à partir de la fusion de B13/B14 |
| **Étapes de reproduction** | 1. Créer une room avec un nom et une description quelconques → 2. Observer l'écran qui s'ouvre ensuite → 3. Constater que le nom affiché est « Salle du Dragon », pas celui saisi |
| **Comportement attendu** | L'écran de room affiche le titre, la description et la dernière mise à jour réels de la campagne créée |
| **Comportement observé** | Contenu figé, codé en dur dans `RoomShell`, identique quel que soit l'id de room reçu |
| **Analyse** | `RoomShell` recevait `roomId` en paramètre mais ne l'utilisait jamais dans son état — aucun appel réseau, aucune donnée chargée |
| **Préconisation** | Faire de `RoomShell` un `FutureBuilder` chargeant la campagne réelle via `SupabaseService.getCampaignById(roomId)` |

### Traitement et déploiement du correctif (B18)

Le correctif tire directement profit du pipeline d'intégration/déploiement
continu (voir §2 du dossier Bloc 2, [`ci.yml`](.github/workflows/ci.yml)) :

1. Développement sur une branche dédiée `fix/room-shell-real-data`, avec
   ajout de `SupabaseService.getCampaignById()` /
   `AuthProvider.getCampaignById()`, et deux nouveaux tests
   (`room_shell_test.dart`) couvrant le cas nominal et le cas « room
   introuvable ».
2. `flutter analyze` et `flutter test` obligatoires avant fusion (job
   `analyze_and_test` de la CI).
3. Fusion `--no-ff` dans `main` (commit `40bd364`), qui déclenche
   automatiquement le rebuild de l'APK et le redéploiement de la démo web.
4. Documentation mise à jour dans le même mouvement : entrée `Corrigé` dans
   [CHANGELOG.md](CHANGELOG.md), ligne déplacée de « connus » à « corrigés »
   dans [PLAN_CORRECTION_BOGUES.md](PLAN_CORRECTION_BOGUES.md).

Ce même circuit (branche → tests → merge → déploiement auto) est celui
qu'emprunterait toute anomalie remontée demain par Crashlytics.

## A4.3 — Assurer la maintenance du logiciel

### Axes d'amélioration proposés

| Axe | Argumentation | Gain estimé | Effort |
|---|---|---|---|
| **Implémenter les outils de room** (dé, frise chronologique, relations) | Actuellement de purs placeholders (« Fonctionnalité à venir ») ; ce sont des fonctionnalités cœur de l'expérience JDR annoncée | Fort (attractivité, différenciation) | Élevé (3 fonctionnalités distinctes, avec état et éventuellement persistance Supabase) |
| **Authentification à deux facteurs** | Limite assumée dans [SECURITE.md](SECURITE.md) (A07) ; Supabase Auth le supporte nativement | Moyen (sécurité, confiance utilisateur) | Faible (fonctionnalité déjà fournie par le SDK, essentiellement de l'UI) |
| **Scan automatique de vulnérabilités des dépendances** (Dependabot) | Limite assumée dans SECURITE.md (A06) ; réduit le risque de dépendance obsolète non détectée entre deux revues manuelles | Moyen (sécurité, sans effort récurrent une fois activé) | Très faible (fonctionnalité native GitHub, quelques minutes de configuration) |
| ~~Table de membres de campagne (`campaign_members`)~~ | ~~Nécessaire pour lier réellement un joueur à la campagne qu'il rejoint~~ | — | **Fait** — implémentée depuis la rédaction de cet axe (bogue B19, commit `e0f8854`) : table `campaign_members` + RLS, alimentée par `AuthProvider.joinCampaign()`, consommée par `SupabaseService.getVisibleCampaigns()` |
| **Afficher la vraie liste des joueurs d'une room** (`RoomPlayersPage`) | La table `campaign_members` existe désormais (voir ci-dessus) mais `RoomPlayersPage` reste un placeholder statique — la donnée est en base, il ne manque que l'écran | Moyen (complète une fonctionnalité déjà à moitié faite) | Faible (une requête + une liste, pas de nouveau schéma) |

### Journal des versions

Tenu à jour dans [CHANGELOG.md](CHANGELOG.md) (format Keep a Changelog),
avec un tag Git par version publiée (`v0.1.0`, `v0.2.0`). Chaque entrée
distingue *Ajouté* et *Corrigé*, et référence les identifiants de bogues du
plan de correction. La section *Non publié* accumule les changements en
attente d'un prochain tag — dont l'intégration du monitoring Firebase
documentée ici.

### Exemple de collaboration avec le support client

*(Mise en situation fictive, ancrée sur un bogue réel du projet — le
référentiel autorise une situation « réelle ou fictive ».)*

**Contexte du retour client** : un joueur (« Léa », utilisatrice fictive)
contacte le support :

> « J'essaie de rejoindre la room de mon MJ mais rien ne se passe comme
> prévu — en fait j'ai tapé un code au hasard pour tester et ça m'a quand
> même laissée entrer dans une room qui ne correspond à rien. C'est normal
> ? »

**Diagnostic** : le retour pointe précisément le bogue B14 —
`RoomJoinPage` acceptait n'importe quel code non vide sans jamais le
vérifier contre la table `campaigns`. Reproduit immédiatement en suivant le
pas-à-pas de Léa.

**Résolution apportée** : `SupabaseService.getCampaignByJoinCode()` est
branché dans `RoomJoinPage` pour vérifier réellement le code saisi ; un
message d'erreur explicite (« Aucune room ne correspond à ce code. »)
s'affiche désormais si le code ne correspond à aucune campagne. Correctif
couvert par un test automatisé (`room_join_page_test.dart`) et déployé via
le même circuit CI/CD que l'exemple B18 ci-dessus.

**Contribution des parties prenantes** :
- **Léa (joueuse)** : a fourni les étapes de reproduction exactes, ce qui a
  rendu le diagnostic immédiat.
- **Développeur (support + corrections)** : diagnostic, correctif, test de
  non-régression, déploiement.
- **Cahier de recettes** : le scénario R20 (« Rejoindre une room avec un
  code invalide/inexistant ») documente le comportement attendu et sert de
  garde-fou contre toute régression future de ce même bogue.
