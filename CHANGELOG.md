# Changelog

Toutes les modifications notables de ce projet sont documentées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et le projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Carte des relations de la room, dans l'esprit du journal de bord d'Outer
  Wilds : des ronds — personnages, lieux, objets, évènements — reliés par des
  liens de couleur, que le MJ place lui-même et complète par un rond « + ».
  Chaque rond porte des informations, et chacun ne lit que celles qu'il a
  découvertes ; les autres s'affichent en « ??? ». Le tri est fait par la
  base : le texte d'une information non découverte n'arrive jamais jusqu'à
  l'appareil, seul son nombre est connu — de quoi savoir qu'il reste à
  chercher, sans rien dévoiler
- Le MJ crée ses catégories de lien (« famille », « conflit », « dette »...),
  chacune avec sa couleur, et la légende permet de n'en mettre qu'une en avant
- Le MJ peut vider la carte en entier, avec une confirmation qui annonce ce
  qui part : les ronds, leurs liens, leurs informations, les catégories et
  les découvertes des joueurs
- La carte se met à jour en temps réel : une information révélée apparaît chez
  son destinataire sans qu'il ait à rouvrir l'écran. Seul le signal circule,
  jamais le texte découvert
- Mesure de fluidité sur cette carte, le seul écran qui dessine et suive le
  doigt : le nombre d'images affichées, les lentes et les gelées partent sur
  une trace Firebase Performance. Les chiffres ne remontent qu'en mode profil
  ou release, la collecte étant désactivée en débogage

## [0.12.0] - 2026-09-12

### Ajouté
- Chat de la room, enregistré et partagé en temps réel : un message apparaît
  chez tous les membres sans rafraîchir. Il ne vivait jusqu'ici qu'en mémoire,
  sur le téléphone de celui qui l'écrivait
- Chuchotements du MJ : il peut adresser un message à des joueurs choisis. La
  règle est portée par la RLS, que Realtime applique à chaque abonné — un
  joueur non destinataire ne reçoit le message ni par requête, ni en direct
- Modération du chat : chacun supprime ses propres messages, le MJ ceux de
  toute la table
- Le journal des dés se met à jour en temps réel : un jet apparaît chez toute
  la table sans tirer l'écran
- Répondre à un message en le faisant glisser vers la droite : la réponse cite
  le message d'origine. Seul l'identifiant du message cité est enregistré,
  jamais son texte — citer un chuchotement ne le révèle donc jamais à qui
  n'avait pas le droit de le lire. Répondre publiquement à un chuchotement
  affiche un avertissement avant l'envoi
- Sondages dans le chat, lancés par le MJ comme par un joueur : une question,
  de deux à dix réponses, à choix unique ou multiple. Les votes sont anonymes
  — la base ne renvoie que des totaux, et personne, pas même le MJ, ne peut
  savoir qui a voté quoi. Les pourcentages ne s'affichent qu'une fois qu'on a
  voté, ou pour toute la table quand le sondage est clos, et c'est la base
  qui en décide. On peut changer d'avis tant que l'auteur du sondage ou le MJ
  ne l'a pas clos, et les résultats se mettent à jour en temps réel

### Corrigé
- Le chat affichait trois messages codés en dur (« Bienvenue dans le chat ! »,
  « Nouveau message test », « Salut à tous ! ») et ne conservait rien de ce qui
  s'y écrivait — bogue B29

## [0.11.0] - 2026-09-11

### Ajouté
- Frise chronologique de la room : le MJ y écrit l'histoire de la campagne, les
  joueurs la lisent. Chaque évènement porte un repère temporel en **texte
  libre** — « an 1247, au printemps », « trois lunes plus tard » — plutôt
  qu'une date : contraindre une campagne au calendrier grégorien obligerait le
  MJ à inventer des dates réelles pour un monde qui n'en a pas. L'ordre est
  donc porté par une colonne à part, que le MJ règle évènement par évènement
- Un évènement de la frise a ses propres destinataires, comme une image ou une
  publication : toute la table, une sélection de joueurs, ou vous seul tant
  qu'il n'est pas révélé. Le filtrage est appliqué par la RLS, pas par
  l'interface — un joueur qui interrogerait l'API ne verrait pas davantage
- L'application se tient téléphone couché, sur tous ses écrans. Là où la
  hauteur manque, les écrans passent en deux colonnes : le dé garde son
  résultat visible à côté des réglages, l'accueil d'une room range son
  en-tête à gauche du fil, et l'onglet Outils aligne ses trois outils. La
  galerie passe de trois à cinq colonnes, et les formulaires défilent quand le
  clavier mange la moitié de la hauteur

### Corrigé
- Téléphone couché, quatre écrans débordaient, du texte, des champs ou des
  boutons passaient sous l'encoche de la caméra ou sous les boutons de
  navigation — dont l'onglet « Paramètres » de chaque room —, et le résultat
  d'un lancer de dé tombait sous la ligne de flottaison : on appuyait sur
  « Lancer » sans rien voir changer. La zone sûre est désormais posée une fois
  pour toutes autour de l'application, et un audit automatisé de chaque écran
  en paysage fait échouer la CI à la moindre régression — bogue B28

## [0.10.0] - 2026-09-10

### Ajouté
- Actions de compte sur la page de profil : changement de mot de passe et
  déconnexion. Elles vivaient dans un écran « Paramètres » qui n'affichait que
  le texte « Page Paramètres » ; cet écran et sa route sont supprimés, le
  compte tient sur un seul écran — bogue B27

### Corrigé
- La page Profil affichait trois compteurs restés à zéro et trois onglets de
  contenu entièrement inventé — campagnes, personnages et historique de
  sessions qui n'ont jamais existé en base. Elle se limite désormais à
  l'identité réelle et au nombre de rooms, et son bouton « Modifier le
  profil », qui ne faisait que changer une icône, enregistre réellement —
  bogue B26

## [0.9.0] - 2026-09-10

### Ajouté
- Fil de la room, sur son accueil : le MJ y publie des textes et des images à
  destination de sa table. Chaque publication a ses propres destinataires —
  tous les joueurs, ou une sélection nominative — choisis **avant** publication,
  pour qu'une révélation adressée à un seul joueur ne passe pas par une seconde
  où toute la table la voit. Le filtrage est appliqué par la RLS
- L'accueil d'une room devient son écran principal : un en-tête compact porte
  son identité, le fil occupe le reste. Il se limitait auparavant au nom et à
  la description
- Un texte long y est replié à une ligne, dépliable par « Voir plus » : sans
  cela, une publication de trente lignes ferait une carte haute de trois écrans
- L'image d'une publication s'ouvre en plein écran, zoomable

## [0.8.0] - 2026-09-10

### Ajouté
- Notes du maître du jeu, dans l'onglet « Contenus » : rédaction en Markdown,
  avec bascule entre saisie et aperçu rendu. Elles lui sont **strictement
  privées** — aucune policy n'ouvre leur lecture aux joueurs, qui ne voient
  même pas la section
- Import d'un fichier `.md` : son contenu devient une note ordinaire, éditable
  comme les autres, plutôt qu'un fichier déposé dans Storage
- Export d'une note en `.md` : le format d'export est celui du stockage, une
  note exportée puis réimportée revient identique
- Suppression d'une note, avec confirmation
- Section « Activité récente » sur l'accueil, adaptée au rôle sans qu'aucun
  test de rôle ne soit fait : le MJ y retrouve ses notes, un joueur les
  images qu'on lui a ouvertes. Chaque ligne ouvre la room concernée
- Cartes de room enrichies : description, et compteurs de membres, d'images et
  de notes. Les compteurs viennent d'une vue en `security_invoker`, ils
  reflètent donc ce que chacun a le droit de voir

### Corrigé
- La carte d'une room annonçait « MJ : » suivi d'une date de mise à jour,
  vestige d'un ancien contenu de démonstration

## [0.7.0] - 2026-09-10

### Ajouté
- Journal des jets de dés : les lancers ne restent plus sur le téléphone de
  celui qui les fait, ils sont enregistrés et partagés avec toute la table.
  Le dé gagne un onglet « Journal » qui liste les jets récents avec leur
  auteur, leur détail et leur ancienneté
- Jets secrets, réservés au MJ : un jet marqué secret n'est lisible que de
  lui. La règle est appliquée par la RLS — un joueur ne peut pas masquer un
  résultat, ni découvrir un jet secret en interrogeant l'API
- Le MJ peut vider le journal de sa room entre deux séances

### Modifié
- L'historique local du lanceur de dés, qui disparaissait à la fermeture de
  l'écran et n'était visible que de son auteur, est remplacé par ce journal
  partagé

### Corrigé
- Ouvrir un outil de room (Dé, Frise, Relations) faisait planter l'écran :
  une route poussée sort du `RoomProvider`, fourni sous le Navigator par
  `RoomShell` — bogue B25

## [0.6.0] - 2026-09-09

### Ajouté
- Onglet « Contenus » d'une room : la galerie d'images y est désormais
  persistée (bucket Supabase `images` et table du même nom) et partagée avec
  toute la table. Le MJ publie et retire, les joueurs consultent — la règle
  est portée par la RLS, pas seulement par l'interface
- Visibilité image par image : le MJ choisit qui voit chaque image — tous les
  joueurs, personne, ou une sélection nominative. Une image importée arrive
  **masquée**, pour qu'une révélation ne puisse pas fuiter le temps de la
  restreindre. Un badge sur chaque vignette rappelle l'état au MJ, et le
  filtrage est appliqué par la RLS : un joueur non destinataire ne peut pas
  découvrir l'image, même en interrogeant l'API directement
- Menu d'actions directement sur les vignettes (visibilité, suppression) :
  il fallait auparavant ouvrir l'aperçu plein écran pour gérer une image
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
