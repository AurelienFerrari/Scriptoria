# Cahier de recettes

Scénarios fonctionnels couvrant les parcours principaux de l'application, et
résultat de leur exécution. Quand un scénario est couvert par un test
automatisé (exécuté à chaque push via la CI), le nom du test est indiqué —
c'est la preuve reproductible du résultat. Les scénarios non automatisables
(ex : dépendent d'un vrai réseau/compte Supabase) sont vérifiés par lecture de
code et exécution manuelle, et signalés comme tels.

Légende : ✅ conforme · ❌ non conforme (bogue, voir [PLAN_CORRECTION_BOGUES.md](PLAN_CORRECTION_BOGUES.md))

## Authentification

| # | Scénario | Résultat attendu | Résultat | Preuve |
|---|---|---|---|---|
| R01 | Ouvrir l'écran de connexion | Titre « Scriptoria », champ email, champ mot de passe, bouton « Se connecter » affichés | ✅ | `widget_test.dart` : *LoginPage affiche le titre et les champs de connexion* |
| R02 | Se connecter avec les champs vides | Message « Veuillez remplir tous les champs » | ✅ | `widget_test.dart` : *LoginPage refuse la connexion si les champs sont vides* |
| R03 | Se connecter avec un email/mot de passe invalide | Message clair « Email ou mot de passe incorrect » (pas le code d'erreur brut Supabase) | ✅ | `friendly_auth_error_test.dart` : *traduit le code "invalid_credentials"* |
| R04 | Cliquer sur l'œil du champ mot de passe | Affiche/masque le mot de passe, tooltip présent pour un lecteur d'écran | ✅ | `widget_test.dart` : *le champ email a un label persistant et le bouton œil un nom accessible* |
| R05 | Cliquer sur « Mot de passe oublié ? » | Un écran de récupération de mot de passe s'affiche | ✅ | `main_test.dart` : *MyApp résout les routes nommées /settings et /forgot-password* ; `forgot_password_page_test.dart` |
| R06 | Ouvrir l'écran d'inscription | Titre, 5 champs (email, pseudo, nom affiché, mot de passe, confirmation), bouton « S'inscrire » | ✅ | `register_page_test.dart` : *RegisterPage affiche le titre, les champs et le bouton d'inscription* |
| R07 | S'inscrire avec les champs vides | Message « Veuillez remplir tous les champs » | ✅ | `register_page_test.dart` : *RegisterPage refuse l'inscription si les champs sont vides* |
| R08 | S'inscrire avec un nom d'utilisateur déjà pris | Message « Ce nom d'utilisateur est déjà pris » | ⚠️ | Logique présente dans le code (`isUsernameAvailable`), non automatisée (nécessite un vrai appel réseau Supabase) — vérifiée manuellement lors de la recréation du schéma |
| R09 | S'inscrire avec un mot de passe de moins de 8 caractères | Message « Le mot de passe doit contenir au moins 8 caractères » | ✅ | Vérifié par lecture de code (validation avant tout appel réseau) — voir B10 |
| R10 | Se déconnecter depuis le profil | Boîte de dialogue de confirmation, puis retour à l'écran de connexion | ✅ | `profile_page_test.dart` : *ProfilePage se déconnecte et redirige vers /login après confirmation* |

## Accueil

| # | Scénario | Résultat attendu | Résultat | Preuve |
|---|---|---|---|---|
| R11 | Ouvrir l'accueil | Sections « Campagnes en cours » et « Derniers documents modifiés », boutons « Créer une room »/« Rejoindre une room » | ✅ | `home_page_test.dart` : *HomePage affiche les sections, les campagnes et les documents* |
| R12 | Cliquer sur l'avatar de profil | Navigation vers l'écran de profil | ✅ | Route `/profile` déclarée dans `main.dart` ; vérifié manuellement (le mécanisme de navigation nommée est le même que pour `/register` et `/room`, testés dans `main_test.dart`) |

## Profil

| # | Scénario | Résultat attendu | Résultat | Preuve |
|---|---|---|---|---|
| R13 | Ouvrir le profil, connecté, profil existant en base | Pseudo/email/bio affichés depuis la table `users` | ✅ | `profile_page_test.dart` : *ProfilePage affiche un indicateur de chargement puis le profil venant de la table users* |
| R14 | Ouvrir le profil, connecté, mais aucune ligne dans `users` | Repli sur les données Supabase Auth (email, métadonnées) | ✅ | `profile_page_test.dart` : *ProfilePage retombe sur les données Supabase Auth si le profil users est introuvable* |
| R15 | Ouvrir le profil sans être connecté | Redirection vers l'écran de connexion | ✅ | `profile_page_test.dart` : *ProfilePage redirige vers /login si personne n'est connecté* |

## Créer / rejoindre une room

| # | Scénario | Résultat attendu | Résultat | Preuve |
|---|---|---|---|---|
| R16 | Créer une room, formulaire vide | Erreurs « Veuillez entrer un nom »/« ...une description » | ✅ | `room_create_page_test.dart` : *affiche les erreurs de validation si le formulaire est vide* |
| R17 | Créer une room, champs remplis mais sans icône choisie | Message « Sélectionne une icône ! » | ✅ | `room_create_page_test.dart` : *exige une icône même si les champs texte sont remplis* |
| R18 | Créer une room, tous les champs valides | La room est enregistrée et accessible ensuite | ✅ | `room_create_page_test.dart` : *RoomCreatePage crée réellement la room et navigue vers RoomShell* — écrit dans `campaigns` avec un code d'invitation généré. ⚠️ Voir B18 : la room ouverte affiche encore un contenu de démonstration, pas ses vraies données |
| R19 | Rejoindre une room avec un code vide | Message « Veuillez entrer un code » | ✅ | `room_join_page_test.dart` : *RoomJoinPage affiche une erreur si le code est vide* |
| R20 | Rejoindre une room avec un code invalide/inexistant | Message d'erreur explicite | ✅ | `room_join_page_test.dart` : *RoomJoinPage affiche une erreur si le code ne correspond à aucune room* |

## Navigation dans une room

| # | Scénario | Résultat attendu | Résultat | Preuve |
|---|---|---|---|---|
| R21 | Ouvrir une room | Page d'accueil de la room (nom, description, galerie) affichée par défaut | ✅ | `room_shell_test.dart` / `room_home_page_test.dart` |
| R22 | Onglet « Chat » | Passe à l'écran de chat de la room | ✅ | `room_shell_test.dart` : *change de page au tap* |
| R23 | Onglet « Paramètres » | Passe aux paramètres de la room | ✅ | `room_shell_test.dart` |
| R24 | Onglet « Outils » | Liste des 3 outils (Dé, Frise, Relations) | ✅ | `room_tools_page_test.dart` |
| R25 | Écrire et envoyer un message dans le chat | Le message apparaît dans la liste | ✅ | `room_chat_page_test.dart` : *RoomChatPage ajoute un message envoyé à la liste* |
| R26 | Envoyer un message vide | Rien ne s'ajoute à la liste | ✅ | `room_chat_page_test.dart` : *ignore un message vide* |
| R27 | Ajouter une image à la galerie de la room | Image ajoutée à la grille | ✅ | `gallery_grid_test.dart` |

## Paramètres de l'application

| # | Scénario | Résultat attendu | Résultat | Preuve |
|---|---|---|---|---|
| R28 | Accéder aux paramètres de l'application (pas ceux d'une room) | Écran de paramètres accessible depuis un menu | ✅ | `main_test.dart` : *MyApp résout les routes nommées /settings et /forgot-password* |

## Synthèse

- **27 scénarios conformes** sur 28 (dont la majorité couverte par un test automatisé rejoué à chaque push).
- **1 réserve** : R18 fonctionne côté données (la room est bien créée) mais l'écran affiché reste un contenu de démonstration (bogue B18, voir le plan de correction).
- **1 scénario partiellement vérifié** (R08, dépend d'un appel réseau réel non automatisé).
