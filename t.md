Voici une documentation claire de l’architecture générée, avec l’explication de chaque fichier et son utilité.

📚 Documentation Scriptoria — Architecture scalable avec Shells
🌳 Structure des dossiers
CopyInsert
lib/
├── main.dart
├── app/
│   └── app_shell.dart         # Layout global avec MainNavbar
├── features/
│   ├── home/
│   │   └── presentation/pages/home_page.dart
│   ├── profile/
│   │   └── presentation/pages/profile_page.dart
│   ├── settings/
│   │   └── presentation/pages/settings_page.dart
│   └── room/
│       └── presentation/
│           ├── room_shell.dart
│           ├── room_chat_page.dart
│           ├── room_map_page.dart
│           └── room_players_page.dart
└── ui/
    └── widgets/
        ├── main_navbar.dart
        └── room_navbar.dart

🗂️ Explication de chaque fichier
1. main.dart
Rôle : Point d’entrée de l’application. Définit le routing global.
Utilité :
Lance l’application sur le AppShell (layout principal).
Permet d’accéder à un RoomShell via la route /room.

2. app/app_shell.dart
Rôle : Shell principal de l’app (layout général).
Utilité :
Gère la navigation par index (Home, Profil, Paramètres).
Affiche la MainNavbar en bas.
Affiche la page correspondante selon l’onglet sélectionné.

3. ui/widgets/main_navbar.dart
Rôle : Widget pour la barre de navigation principale.
Utilité :
Réutilisable.
Affiche les onglets principaux (Accueil, Profil, Paramètres).
Remonte l’index sélectionné au parent via onTap.

4. features/home/presentation/pages/home_page.dart
Rôle : Page d’accueil de l’application.
Utilité :
Contenu principal affiché dans l’onglet Accueil.
Peut contenir tes widgets métiers (liste de campagnes, etc.).

5. features/profile/presentation/pages/profile_page.dart
Rôle : Page de profil utilisateur.
Utilité :
Affiche les infos du profil ou les paramètres liés à l’utilisateur.

6. features/settings/presentation/pages/settings_page.dart
Rôle : Page de paramètres.
Utilité :
Permet à l’utilisateur de modifier les paramètres de l’app.

7. features/room/presentation/room_shell.dart
Rôle : Shell spécifique pour la navigation dans une « room ».
Utilité :
Gère la navigation par tab (chat, carte, joueurs) dans le contexte d’une room.
Affiche la RoomNavbar en bas.
Affiche la page correspondante selon le tab sélectionné.

8. ui/widgets/room_navbar.dart
Rôle : Widget pour la barre de navigation spécifique à une room.
Utilité :
Réutilisable pour tous les contextes de room.
Onglets : Chat, Carte, Joueurs.

9. features/room/presentation/room_chat_page.dart
Rôle : Page de chat d’une room.
Utilité :
Affiche la discussion de la room.

10. features/room/presentation/room_map_page.dart
Rôle : Page carte d’une room.
Utilité :
Affiche la carte ou le plan de la room.

11. features/room/presentation/room_players_page.dart
Rôle : Page joueurs d’une room.
Utilité :
Affiche la liste des joueurs de la room.
🚦 Fonctionnement global
AppShell centralise la navigation principale (Accueil, Profil, Paramètres).
RoomShell centralise la navigation contextuelle d’une room (Chat, Carte, Joueurs).
Les pages ne connaissent pas la barre de navigation : elles sont injectées dans leur Shell respectif.
Tu peux ajouter d’autres Shells (admin, settings avancés, etc.) sans toucher aux pages existantes.
🚀 Ajouter une nouvelle page ou un nouveau Shell
Créer la page dans le bon dossier.
Ajouter l’onglet dans le widget de navbar concerné.
Ajouter la page dans la liste _pages ou _roomPages du Shell visé.
(Optionnel) Ajouter la route dans main.dart si besoin d’un accès direct.
