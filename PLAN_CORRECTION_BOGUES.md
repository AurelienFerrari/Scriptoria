# Plan de correction des bogues

Bogues détectés au fil du développement (revue de code, écriture des tests,
CI) et leur statut. Les IDs sont référencés depuis le [cahier de recettes](CAHIER_DE_RECETTES.md).

## Corrigés

| ID | Bogue | Gravité | Détecté par | Correctif |
|---|---|---|---|---|
| B01 | Conflit Git non résolu (marqueurs `<<<<<<<`/`=======`/`>>>>>>>`) resté commité dans `README.md` | Mineure | Revue de code | Résolution manuelle du conflit — commit `6a1b5f4` |
| B02 | Mot de passe stocké en double : Supabase Auth (sécurisé) **+** un second hash SHA-256 non salé dans `users.password_hash`, jamais relu | Critique (sécurité, OWASP A02) | Revue de code lors de la recréation du schéma | Suppression du second hash, dépendance `crypto` retirée — commit `6a1b5f4` |
| B03 | Crash garanti sur le build web : `Platform.environment` (`dart:io`) n'existe pas sur Flutter Web | Critique | Revue de code avant mise en place de la CI web | Appel protégé par `kIsWeb` — commit `e068294` |
| B04 | `createUserProfile()` recevait l'id utilisateur mais ne l'insérait jamais dans la table `users` : avec les RLS actives, chaque inscription échouait silencieusement (erreur avalée par un `catch` sans `rethrow`) | Critique | Conception du schéma Supabase + RLS | Ajout de `'id': userId` dans l'insertion |
| B05 | Crash de navigation dans une room : `RoomNavbar` affichait 5 onglets mais `RoomShell` ne branchait que 3 pages (`RangeError`) | Critique | Revue de code (avant fusion de la branche `register`) | Résolu de fait par la fusion de `register`, qui refaisait `RoomShell` avec 5 pages |
| B06 | `_loadUserProfile()` appelait `Navigator.pushReplacementNamed` de façon synchrone depuis `initState()` (avant tout `await`) : lève `setState() called during build` pour un utilisateur non connecté ouvrant son profil | Majeure | Test automatisé (`profile_page_test.dart`) | Navigation reportée via `WidgetsBinding.instance.addPostFrameCallback` |
| B07 | Version de NDK Android figée en dur (`27.0.12077973`) : le SDK manager la re-téléchargeait à chaque run CI, et le zip arrivait parfois corrompu, faisant échouer le build APK | Majeure (CI) | Échec du job CI "Build APK" | `ndkVersion = flutter.ndkVersion` (version déjà en cache) |
| B08 | Méthode de calcul du taux de couverture de tests erronée (division par le nombre brut de lignes du fichier au lieu des lignes exécutables identifiées par `lcov`), plafonnant artificiellement le pourcentage bien avant 50% | Majeure (fiabilité de la mesure qualité) | Relecture de la méthodologie suite à une remarque | Recalcul en LH/LF cumulé sur `lib/`, seuil CI corrigé |
| B09 | Deux icônes sous le seuil de contraste WCAG de 3:1 (`white30` à 2.70:1, `white38` à 2.60:1) | Mineure (accessibilité) | Calcul systématique des contrastes de la palette | Relevées à `white54` (4.46:1 et 4.66:1) |
| B10 | Mot de passe accepté dès 6 caractères (sous la recommandation OWASP/NIST de 8) | Mineure (sécurité) | Revue de code | Seuil relevé à 8 caractères |
| B11 | Warnings d'analyse statique : imports dupliqués (`room_tools_page.dart`), imports inutilisés (`room_shell.dart`, `main.dart`), champs de formulaire assignés mais jamais lus (`room_create_page.dart`, `room_join_page.dart`), comparaison null devenue impossible (`supabase_service.dart`) | Mineure | `flutter analyze` en CI | Nettoyage du code — commit `9358aa2` |

## Connus, pas encore corrigés

| ID | Bogue | Gravité | Constat |
|---|---|---|---|
| B12 | Le lien « Mot de passe oublié ? » de `LoginPage` pointe vers la route `/forgot-password`, jamais déclarée dans `main.dart` : la navigation échoue (aucun écran de récupération de mot de passe n'existe) | Majeure | Fonctionnalité annoncée à l'utilisateur mais non implémentée |
| B13 | `RoomCreatePage` ne persiste rien : le bouton « Créer » affiche un SnackBar « Room créée ! » puis revient en arrière, sans appeler Supabase ni écrire dans la table `campaigns` | Majeure | Fonctionnalité vitrine, non branchée au backend |
| B14 | `RoomJoinPage` accepte n'importe quel code non vide (« Bon code » systématique) : aucune vérification contre une vraie room existante | Majeure | Même cause que B13 — le flux de jointure n'est pas branché au backend |
| B15 | `SupabaseService.uploadImage()` appelle `_readFile()`, qui lève `UnimplementedError` : toute tentative d'upload d'image plante | Majeure | Fonctionnalité de stockage jamais terminée |
| B16 | `SettingsPage` existe mais n'est référencée dans aucune route de `main.dart` : écran mort, inaccessible depuis l'app | Mineure | Code orphelin |
| B17 | Incohérence de nommage : la campagne « Mystères de l'Ombre » (carte d'accueil) devient « Mystères du Ombre » dans le sous-titre du document associé | Cosmétique | Faute de frappe dans les données de démonstration codées en dur |

## Priorisation proposée

1. **B12, B13, B14, B15** avant toute démonstration devant un public/jury : ce sont des fonctionnalités visibles dans l'interface qui ne font rien ou plantent — le plus gros risque pour la crédibilité du prototype.
2. **B16, B17** : cosmétique/hygiène, à corriger quand le temps le permet, sans urgence.
