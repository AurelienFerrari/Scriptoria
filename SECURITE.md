# Sécurité — mesures prises face à l'OWASP Top 10 (édition 2021)

Ce document mappe explicitement les mesures de sécurité de Scriptoria aux 10
catégories de l'[OWASP Top 10](https://owasp.org/Top10/), en étant honnête sur
ce qui reste à faire plutôt que de prétendre à une couverture parfaite.

## A01:2021 — Broken Access Control

- **Row Level Security (RLS) activée sur les 4 tables** (`users`, `campaigns`,
  `characters`, `images`) — voir [`supabase/migrations/`](supabase/migrations/).
  Chaque table restreint l'écriture au propriétaire de la ligne
  (`auth.uid() = creator_id`/`owner_id`/`id` selon la table).
- La fonction `get_user_accessible_images` est `SECURITY DEFINER` mais
  revérifie `p_user_id = auth.uid()` en interne : impossible pour un
  utilisateur d'interroger les images d'un autre en falsifiant le paramètre.
- **Storage** : les policies restreignent l'écriture aux fichiers du dossier
  `{user_id}/...` de chacun (`(storage.foldername(name))[1] = auth.uid()::text`).
- Un audit automatique (Database > Advisors de Supabase) a détecté et permis
  de corriger deux excès de droits lors de la mise en place initiale : une
  policy de lecture sur le storage trop permissive (autorisait le listing de
  tous les fichiers d'un bucket public) et une fonction RPC exécutable par le
  rôle anonyme sans nécessité — voir [PLAN_CORRECTION_BOGUES.md](PLAN_CORRECTION_BOGUES.md).

## A02:2021 — Cryptographic Failures

- Les mots de passe sont gérés entièrement par Supabase Auth (hachage bcrypt
  côté serveur) — l'app ne les stocke ni ne les manipule jamais en clair au
  repos.
- **Bogue trouvé et corrigé (B02)** : le code stockait initialement un
  *second* hash du mot de passe (SHA-256 non salé) dans `users.password_hash`,
  en plus de Supabase Auth — un hash faible, redondant, jamais relu par le
  reste du code. Supprimé.
- Toutes les communications avec Supabase se font en HTTPS (`https://*.supabase.co`,
  imposé par le SDK, pas d'option pour désactiver TLS).
- Aucune clé/secret n'est commité : `.env` et `lib/config/supabase_credentials.dart`
  sont dans `.gitignore`, seuls des fichiers `.example` avec des valeurs
  factices sont versionnés. Les vraies valeurs transitent uniquement par les
  secrets GitHub Actions en CI.

## A03:2021 — Injection

- Toutes les requêtes passent par le client Supabase (`supabase_flutter`), qui
  construit des requêtes PostgREST paramétrées — aucune concaténation de
  chaînes SQL nulle part dans le code de l'app.
- La seule fonction SQL personnalisée (`get_user_accessible_images`) prend son
  paramètre typé (`uuid`), pas de SQL dynamique construit à partir d'une
  entrée utilisateur.

## A04:2021 — Insecure Design

- Mot de passe minimum 8 caractères à l'inscription (relevé de 6 à 8 — voir
  bogue B10 — conformément aux recommandations OWASP/NIST).
- La réinitialisation de mot de passe (`resetPasswordForEmail`) ne révèle pas
  si un email existe en base ou non (comportement natif de Supabase Auth) :
  pas d'énumération de comptes par ce biais.
- **Limite acceptée** : `isUsernameAvailable()` permet de vérifier si un pseudo
  est pris avant inscription — une forme d'énumération de pseudos (pas
  d'emails) qui reste nécessaire au bon fonctionnement du formulaire ;
  compromis assumé plutôt qu'oubli.

## A05:2021 — Security Misconfiguration

- Aucune valeur de configuration sensible n'a de valeur par défaut
  fonctionnelle dans le code source : les placeholders (`YOUR_PROJECT_ID`,
  `YOUR_ANON_KEY`) font volontairement échouer le démarrage tant qu'ils n'ont
  pas été remplacés (voir `SupabaseService.initialize()`), pour éviter de
  tourner silencieusement contre un mauvais projet.
- **Limite connue** : de nombreux `print()` restent dans le code (signalés en
  *info* par `flutter analyze`, non bloquants), certains affichent des emails
  en clair dans la console de debug. Acceptable en développement, à retirer
  ou conditionner avant toute mise en production réelle.

## A06:2021 — Vulnerable and Outdated Components

- Version de Flutter épinglée en CI (`3.29.3`) pour des builds reproductibles.
- `pubspec.lock` versionné (pratique recommandée pour une application, par
  opposition à une librairie) : les versions résolues sont figées et revues à
  chaque mise à jour volontaire (voir [MANUEL_MISE_A_JOUR.md](MANUEL_MISE_A_JOUR.md)).
- **Limite connue** : pas de scan automatique de vulnérabilités des
  dépendances (type Dependabot/`pub audit`) à ce stade — mise à jour
  manuelle et ponctuelle uniquement.

## A07:2021 — Identification and Authentication Failures

- Authentification déléguée à Supabase Auth (email + mot de passe, jetons de
  session gérés par le SDK, confirmation d'email activée par défaut).
- Messages d'erreur traduits mais non-informatifs sur la cause exacte côté
  attaquant (`friendly_auth_error.dart`) : « Email ou mot de passe incorrect »
  générique plutôt que « email inconnu » vs « mot de passe faux ».
- **Limite connue** : pas d'authentification à deux facteurs, pas de politique
  de verrouillage de compte après N échecs au-delà du rate-limiting déjà
  fourni nativement par Supabase Auth.

## A08:2021 — Software and Data Integrity Failures

- CI (`analyze_and_test`) obligatoire avant tout déploiement : aucun code qui
  ne passe pas les tests n'atteint `main` sans être remarqué.
- Schéma de base de données versionné en migrations SQL append-only
  ([`supabase/migrations/`](supabase/migrations/)), jamais modifiées après
  application — un changement de schéma est toujours un nouveau fichier.

## A09:2021 — Security Logging and Monitoring Failures

- **Limite connue, non traitée** : pas d'outil de monitoring/alerting
  centralisé (type Sentry) branché sur l'app. Les seules traces sont les
  `print()` de debug (console locale uniquement, rien de persistant côté
  client) et les logs internes de Supabase (Database > Logs, Auth > Logs)
  côté backend.

## A10:2021 — Server-Side Request Forgery (SSRF)

- Non applicable : l'app ne fait aucune requête serveur-à-serveur pilotée par
  une URL fournie par l'utilisateur (pas de fonction « importer depuis une
  URL », pas de proxy, pas de webhook sortant).

## Synthèse

| Catégorie | Statut |
|---|---|
| A01 Broken Access Control | ✅ Couverte (RLS + storage policies + audit) |
| A02 Cryptographic Failures | ✅ Couverte (bogue trouvé et corrigé) |
| A03 Injection | ✅ Couverte (requêtes paramétrées par construction) |
| A04 Insecure Design | ✅ Couverte, 1 compromis assumé documenté |
| A05 Security Misconfiguration | ⚠️ Couverte pour l'essentiel, logs de debug à nettoyer |
| A06 Vulnerable Components | ⚠️ Processus manuel, pas d'outil de scan automatique |
| A07 Authentication Failures | ⚠️ Couverte pour l'essentiel, pas de 2FA |
| A08 Software/Data Integrity | ✅ Couverte (CI + migrations versionnées) |
| A09 Logging/Monitoring | ❌ Non traitée (pas d'outil de monitoring) |
| A10 SSRF | N/A (pas de surface d'attaque correspondante) |
