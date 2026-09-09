# Changelog

Toutes les modifications notables de ce projet sont documentées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et le projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Onglet « Contenus » d'une room : la galerie d'images y est désormais
  persistée (bucket Supabase `images` et table du même nom) et partagée avec
  toute la table. Le MJ publie et retire, les joueurs consultent — la règle
  est portée par la RLS, pas seulement par l'interface
- Nom accessible sur les vignettes de la galerie, qui ouvraient l'aperçu plein
  écran sans que rien ne l'annonce à un lecteur d'écran

### Modifié
- La galerie quitte l'accueil de la room, où elle ne vivait qu'en mémoire et
  disparaissait à la fermeture de l'écran. L'accueil se recentre sur
  l'identité de la room : icône, nom, description, dernière mise à jour
- `RoomMapPage` (« Carte de la room ») est remplacée par `RoomContentsPage` :
  l'onglet portait déjà le libellé « Contenus » et une icône de dossier

### Corrigé
- Une URL d'image invalide faisait apparaître une erreur de rendu au milieu de
  la galerie ; la vignette concernée signale maintenant la panne et le reste
  de la grille continue de s'afficher
- Dans l'aperçu plein écran, le bouton de suppression refermait la demande de
  confirmation au lieu de l'aperçu, rendant la suppression impossible

## [0.5.0] - 2026-09-09

### Ajouté
- Lanceur de dés dans les outils de la room, en remplacement de l'écran
  « Fonctionnalité Dé à venir » : dés usuels du jeu de rôle (d4 à d100),
  nombre de dés, modificateur (`3d6+2`), réussite et échec critiques sur un
  d20 seul, et historique des jets de la séance. Accessible au MJ comme aux
  joueurs. La logique de tirage est isolée dans `features/room/domain/dice.dart`
  avec une source d'aléa injectable, ce qui permet de tester des résultats
  exacts plutôt qu'un simple encadrement. Le jet reste local : le diffuser à
  toute la table suppose le temps réel, prévu plus tard
- Animation de lancer : chaque dé est affiché séparément, tourne, puis se fige
  avec un décalage sur ses voisins. La face change de moins en moins vite à
  l'approche de l'arrêt, le dé oscille et se pose d'un rebond, et le détail du
  calcul n'apparaît qu'une fois tous les dés immobilisés. Chaque type de dé a
  sa silhouette dessinée — triangle, carré, losange, pentagone, hexagone

### Corrigé
- L'analyse statique échouait en CI sur un import inutilisé :
  `flutter analyze --no-fatal-infos` tolère les infos mais pas les warnings

## [0.4.0] - 2026-09-09

### Ajouté
- Rôles dans une room : le créateur en est le **maître du jeu**, les autres
  membres sont des **joueurs**. Le rôle est stocké en base
  (`campaign_members.role`) et appliqué par la RLS via les fonctions
  `is_campaign_member` / `is_campaign_mj`, pas seulement masqué dans
  l'interface. Un trigger inscrit le créateur comme MJ à la création de la
  room, ce qui rend l'invariant indépendant du client
- Liste des joueurs dans les paramètres de la room : membres, badge MJ,
  code d'invitation copiable (MJ seul) et exclusion d'un joueur (MJ seul).
  La base refuse de supprimer la ligne d'un MJ : une room ne peut pas se
  retrouver sans meneur
- Renommage de la room depuis ses paramètres, réservé au MJ
- Un joueur peut quitter une room de lui-même

### Modifié
- `RoomSettingsPage` lit désormais l'état de la room dans le `RoomProvider`
  au lieu de recevoir `roomId` et `isCreator` en paramètres
- Le commutateur « Room privée » est retiré : toutes les rooms sont privées
  et se rejoignent par code, le réglage n'avait aucun effet
- La galerie d'une room est en lecture seule pour les joueurs : seul le MJ y
  ajoute ou en retire des images
- L'icône de lancement de l'application est le logo Scriptoria, celui déjà
  affiché dans l'en-tête de l'accueil

### Corrigé
- Les messages d'erreur ne prétendent plus connaître une cause qu'ils n'ont
  pas constatée : toute erreur non liée à l'authentification était rapportée
  comme un problème de connexion internet, y compris une erreur de base de
  données. Les erreurs Postgrest et Storage sont désormais traduites, dont le
  refus de la RLS — bogue B23
- L'exclusion d'un joueur affichait une erreur alors que la suppression avait
  abouti : le rafraîchissement de la liste échouait, et son erreur était
  attribuée à la suppression — bogue B24
- Les boutons « Créer une room » et « Rejoindre une room » de l'accueil
  passaient sous la barre de navigation du téléphone
- La section « Derniers documents modifiés » de l'accueil affichait deux
  documents codés en dur, cliquables mais sans effet, sur le premier écran vu
  après connexion. Elle est retirée en attendant d'être alimentée par les
  vraies notes de room — bogue B22

## [0.3.0] - 2026-08-09

### Ajouté
- `SECURITE.md` : mapping explicite aux 10 catégories de l'OWASP Top 10 2021,
  avec les limites assumées documentées (pas de 2FA, pas de monitoring
  centralisé, pas de scan automatique de vulnérabilités des dépendances)
- Monitoring applicatif (Firebase Crashlytics + Performance Monitoring) :
  capture automatique des crashs et erreurs non gérées (`FlutterError.onError`,
  `PlatformDispatcher.instance.onError`), suivi des frames lentes/gelées et
  du temps de démarrage. Best-effort (n'empêche jamais l'app de démarrer si
  mal configuré), désactivé en mode debug. Comble la limite précédemment
  documentée dans `SECURITE.md` (A09). Voir `MAINTENANCE.md`.

### Corrigé
- Le lien « Mot de passe oublié ? » de `LoginPage` pointait vers une route
  jamais déclarée : nouvel écran `ForgotPasswordPage` relié à
  `AuthProvider.resetPassword` — bogue B12
- `RoomCreatePage` ne persistait rien : le bouton « Créer » n'écrivait jamais
  dans `campaigns` ; la création est maintenant réellement enregistrée en
  base, avec génération d'un code d'invitation — bogue B13
- `RoomJoinPage` acceptait n'importe quel code non vide ; le code est
  désormais vérifié contre `campaigns` avant de rejoindre la room — bogue B14
- `SettingsPage` existait mais n'était référencée dans aucune route ; route
  `/settings` ajoutée et reliée depuis le profil — bogue B16
- `RoomShell` affichait un contenu de démonstration codé en dur (« Salle du
  Dragon ») quel que soit l'id de room reçu ; il charge désormais la vraie
  campagne depuis Supabase (`SupabaseService.getCampaignById`) et affiche son
  titre, sa description et sa dernière mise à jour réels — bogue B18
- `SupabaseService.uploadImage()` levait `UnimplementedError` : toute
  tentative d'upload d'image plantait. Réécrit pour lire les octets d'un
  `XFile` (image_picker) de façon cross-platform, et branché dans
  `RoomCreatePage` : une icône importée depuis la galerie est désormais
  réellement uploadée vers le bucket `images`, son URL publique devenant
  `icon_url` de la room (affichée via `Image.network` dans `RoomHomePage`) —
  bogue B15
- Incohérence de nommage dans les données de démonstration (« Mystères du
  Ombre » au lieu de « Mystères de l'Ombre » dans le sous-titre d'un
  document de l'accueil) — bogue B17
- `HomePage` affichait toujours deux campagnes de démonstration codées en
  dur dans « Campagnes en cours », même pour un utilisateur n'ayant créé ni
  rejoint aucune room ; elle affiche désormais les vraies rooms créées ou
  rejointes par code (`SupabaseService.getVisibleCampaigns`), et plus aucune
  carte si la liste est vide. Rejoindre une room par code (`RoomJoinPage`)
  persiste maintenant réellement l'adhésion (nouvelle table
  `campaign_members`) au lieu de ne rien enregistrer — bogue B19
- Les liens de confirmation d'inscription et de réinitialisation de mot de
  passe redirigeaient vers `http://localhost:3000` (Site URL web par
  défaut), qui ne répond rien sur mobile ; un schéma d'URL personnalisé
  (`com.example.scriptoria://reset-callback/`) ramène désormais dans l'app,
  qui affiche un nouvel écran `ResetPasswordPage` pour définir le nouveau
  mot de passe (`AuthProvider.updatePassword`, jusque-là jamais branchée) —
  bogue B20
- `HomePage` ne rechargeait jamais sa liste de campagnes en revenant dessus
  (ex : après avoir créé une room) car la requête n'était faite qu'une fois
  dans `initState`. Utilise désormais `RouteObserver`/`RouteAware` pour
  recharger la liste à chaque retour sur l'accueil ; la section « Campagnes
  en cours » a aussi une hauteur fixe et défile sur elle-même. Le bouton
  « Supprimer la room » existait mais n'était jamais branché ; il appelle
  maintenant `SupabaseService.deleteCampaign()` (confirmation préalable,
  visible seulement pour le créateur de la room) — bogue B21

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
