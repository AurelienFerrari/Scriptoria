# Accessibilité

## Référentiel choisi

**RGAA (Référentiel Général d'Amélioration de l'Accessibilité)**, version 4.1.

Le RGAA est écrit pour le web, mais ses critères s'appuient sur les WCAG 2.1, dont les
principes se transposent directement aux composants Flutter : l'arbre `Semantics` de
Flutter est ce qui alimente ARIA sur le build web et les API d'accessibilité natives
(TalkBack sur Android, VoiceOver sur iOS/macOS). On a donc retenu le RGAA plutôt
qu'OPQUAST parce qu'il est le référentiel officiel français, qu'il est directement
adossé aux WCAG (donc transposable à Flutter via `Semantics`), et qu'il est le plus
reconnu dans un contexte de certification. Seuls les critères qui font sens pour une
application Flutter (pas de balisage HTML/ARIA direct) ont été retenus.

## État des lieux avant ce travail

Aucune considération d'accessibilité : 0 usage de `Semantics`, aucun `tooltip` sur les
12 `IconButton` de l'app, aucune distinction entre images décoratives et informatives,
2 icônes sous le seuil de contraste minimal.

## Critères RGAA appliqués

### Thématique 1 — Images (décoratif vs informatif)

Les images purement décoratives (logo dans l'AppBar, vignette de campagne à côté de
son titre, bannière de room à côté de son nom) sont marquées `excludeFromSemantics: true`
pour ne pas être annoncées par un lecteur d'écran alors que l'information est déjà
portée par le texte adjacent (critère 1.2). À l'inverse, les images qui portent une
information que l'utilisateur doit distinguer (choix d'une icône de room) reçoivent un
`Semantics(label: ...)` explicite (ex. « Icône Dragon », « Icône Mystère »).

### Thématique 3 — Couleurs et contrastes

Tous les contrastes texte/fond utilisés dans l'app ont été calculés (formule WCAG,
`(L1+0.05)/(L2+0.05)`) :

| Paire | Ratio | Seuil |
|---|---|---|
| Texte blanc sur fond `#161622` | 17.9:1 | ✅ (AAA) |
| `white70` sur `#161622` | 9.2:1 | ✅ (AAA) |
| `white60` sur `#161622` | 7.1:1 | ✅ (AAA) |
| `grey[400]` sur `#161622` | 9.5:1 | ✅ (AAA) |
| Accent `#6FE3E1` sur `#161622` | 11.7:1 | ✅ (AAA) |
| Bouton primaire (`#161622` sur `#6FE3E1`) | 11.7:1 | ✅ (AAA) |

Deux icônes étaient sous le seuil minimal de 3:1 pour les composants graphiques
(critère 3.3) : le chevron « voir plus » du profil (`white30` sur `#232336`, 2.70:1)
et l'icône vide du sélecteur de room (`white38` sur fond gris 900, 2.60:1). Les deux
ont été relevées à `white54` (4.46:1 et 4.66:1 respectivement).

### Thématique 7/9 — Nom accessible des composants interactifs

Les 12 `IconButton` de l'app (icônes seules, sans texte visible) n'avaient aucun nom
accessible. Chacun a reçu un `tooltip` (qui sert à la fois d'infobulle visuelle et de
nom accessible exposé aux lecteurs d'écran) : retour arrière, afficher/masquer le mot
de passe, modifier le profil, envoyer un message, fermer/supprimer une image, etc.
Les zones tactiles construites avec `GestureDetector` (avatar de profil, bouton
d'ajout d'image, import depuis la galerie) ont reçu un `Semantics(button: true, label: ...)`
équivalent, car `GestureDetector` seul n'expose aucune sémantique de bouton.

### Thématique 10/11 — Redimensionnement du texte et formulaires

L'app ne surcharge nulle part `textScaleFactor`/`MediaQuery` : la taille de police
choisie par l'utilisateur dans les paramètres système du téléphone est donc respectée
partout, sans action supplémentaire nécessaire. Les champs de connexion utilisent
`labelText` (label persistant, visible même une fois le champ rempli) plutôt que
`hintText` seul, pour que le nom du champ reste disponible à tout moment.

### Cible tactile

Les `IconButton` Material ont une zone tactile minimale de 48×48dp par défaut
(satisfait nativement le critère de taille de cible, sans configuration
supplémentaire).

## Ce qui reste à faire

- Pas de test réel avec un lecteur d'écran physique (TalkBack/VoiceOver) — seule la
  présence des labels dans l'arbre `Semantics` a été vérifiée par des tests
  automatisés.
- L'ordre de focus (navigation clavier, pertinent surtout pour le build web) n'a pas
  été audité spécifiquement.
- Les messages d'erreur de formulaire ne sont pas annoncés en direct (pas de
  `Semantics(liveRegion: true)`) — actuellement ils s'affichent visuellement mais un
  lecteur d'écran ne sera notifié qu'au prochain changement de focus.
