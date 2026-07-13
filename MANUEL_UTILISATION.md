# Manuel d'utilisation

Scriptoria est une plateforme collaborative pour les joueurs et maîtres de jeu
de jeux de rôle : organiser des campagnes (« rooms »), partager des documents,
des cartes et discuter avec son groupe.

## Créer un compte

1. Sur l'écran de connexion, appuyer sur **S'inscrire**.
2. Renseigner un email, un pseudo, un nom affiché et un mot de passe (8
   caractères minimum) avec sa confirmation, puis accepter les conditions
   d'utilisation.
3. Un email de confirmation est envoyé. Il faut cliquer sur le lien reçu avant
   de pouvoir se connecter.

## Se connecter

Renseigner l'email et le mot de passe sur l'écran de connexion. En cas
d'erreur, un message explicite s'affiche (identifiants incorrects, email non
confirmé, etc.) plutôt qu'un message technique.

> Le lien « Mot de passe oublié ? » n'est pas encore fonctionnel dans cette
> version (voir [PLAN_CORRECTION_BOGUES.md](PLAN_CORRECTION_BOGUES.md), bogue B12).

## Écran d'accueil

L'accueil liste les **campagnes en cours** (les rooms auxquelles on
participe) et les **derniers documents modifiés**. Deux boutons permettent de
créer ou rejoindre une room. Un appui sur l'avatar en haut à droite ouvre le
profil.

## Créer une room

1. Depuis l'accueil, appuyer sur **Créer une room**.
2. Renseigner un nom et une description (obligatoires).
3. Choisir une icône : soit l'une des deux icônes de démonstration proposées,
   soit importer une image depuis sa galerie (une icône est obligatoire).
4. Choisir le nombre de joueurs (2 à 10, ou illimité) puis valider.

> Dans cette version, la création n'enregistre pas encore la room de façon
> persistante (voir bogue B13) — l'écran de démonstration est fonctionnel
> mais la donnée n'est pas conservée après validation.

## Rejoindre une room

Depuis l'accueil, **Rejoindre une room** puis saisir le code fourni par le
maître de jeu.

> Dans cette version, n'importe quel code non vide est accepté (voir bogue
> B14) : la vérification du code réel n'est pas encore branchée.

## Naviguer dans une room

Une fois dans une room, la barre de navigation en bas propose 5 sections :

| Onglet | Contenu |
|---|---|
| Accueil | Nom, description et galerie d'images de la room |
| Contenus | Carte de la room |
| Outils | Trois outils : Dé, Frise chronologique, Relations entre personnages |
| Chat | Discussion textuelle de la room |
| Paramètres | Réglages de la room (nom, confidentialité, suppression) |

Dans la galerie (onglet Accueil), le bouton **+** permet d'ajouter une image
depuis sa galerie photo ; appuyer sur une image l'ouvre en plein écran avec
zoom (double-tap) et un bouton de suppression.

## Profil

Le profil affiche le pseudo, l'email et la bio de l'utilisateur connecté (ou,
si ces informations ne sont pas encore enregistrées, les données de
connexion). Le bouton crayon (en haut à droite) permet de passer en mode
édition. Le bouton **Déconnexion** demande une confirmation avant de
raccrocher la session.

## Accessibilité

Voir [ACCESSIBILITE.md](ACCESSIBILITE.md) : l'app respecte la taille de
police définie dans les réglages du téléphone, et tous les boutons à icône
seule (retour, envoyer, supprimer...) sont annoncés par un lecteur d'écran.
