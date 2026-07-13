# Manuel de déploiement

## Prérequis

- Flutter 3.29.3 (canal stable) — c'est la version épinglée dans la CI (`.github/workflows/ci.yml`), à utiliser en local pour éviter toute divergence.
- Un compte [Supabase](https://supabase.com) (le projet utilise Auth, la base Postgres, le Storage).
- Pour builder l'APK Android en local : le SDK Android (`flutter doctor` doit être vert sur la ligne Android toolchain).

## 1. Configurer le projet Supabase

### 1.1 Créer le projet

Créer un projet sur [app.supabase.com](https://app.supabase.com), noter son URL
(`https://<id>.supabase.co`) et sa clé anonyme publique (Settings > API).

### 1.2 Appliquer le schéma

Les migrations SQL sont dans [`supabase/migrations/`](supabase/migrations/), à
exécuter dans l'ordre (via l'éditeur SQL du dashboard Supabase, ou la CLI
`supabase db push` si vous utilisez le développement local Supabase) :

1. `20260703184500_create_core_tables.sql` — tables `users`, `campaigns`, `characters`, `images`
2. `20260703184600_enable_rls_and_policies.sql` — active le Row Level Security sur les 4 tables
3. `20260703184700_create_accessible_images_rpc.sql` — fonction `get_user_accessible_images`
4. `20260703184800_create_storage_buckets.sql` — buckets `avatars`/`images`/`maps` + policies

Après application, vérifier qu'il n'y a pas d'avertissement de sécurité inattendu
dans Database > Advisors du dashboard Supabase.

### 1.3 Authentification

Aucune configuration supplémentaire n'est nécessaire pour Email/Password (activé
par défaut). Si vous voulez désactiver la confirmation par email en
développement : Authentication > Providers > Email > décocher *Confirm email*.

## 2. Configurer les credentials côté app

Le code cherche les credentials dans cet ordre (voir
[`lib/core/services/supabase_service.dart`](lib/core/services/supabase_service.dart)) :

1. Variables d'environnement système `SUPABASE_URL` / `SUPABASE_ANON_KEY` (ignorées sur le web, `dart:io` n'y existe pas)
2. Fichier `.env` à la racine du projet
3. `lib/config/supabase_credentials.dart`

Le plus simple en local : copier [`.env.example`](.env.example) en `.env` et
renseigner les deux valeurs. `.env` est dans `.gitignore`, il ne sera jamais
commité. Alternative équivalente : copier
[`lib/config/supabase_credentials.dart.example`](lib/config/supabase_credentials.dart.example)
en `lib/config/supabase_credentials.dart` (même dossier), également ignoré par Git.

## 3. Lancer en local

```bash
flutter pub get
flutter run                 # mobile/desktop
flutter run -d chrome        # web
```

## 4. CI/CD (déploiement automatique)

Le pipeline [`.github/workflows/ci.yml`](.github/workflows/ci.yml) tourne à
chaque push/PR sur `main` :

| Job | Déclencheur | Rôle |
|---|---|---|
| `analyze_and_test` | push et PR | `flutter analyze` + `flutter test --coverage`, échoue si le seuil de couverture (50%) n'est pas atteint |
| `build_apk` | push sur `main` | build un APK release, publié comme artefact GitHub Actions téléchargeable |
| `deploy_web` | push sur `main` | build web et déploie sur GitHub Pages |

### Secrets requis (Settings > Secrets and variables > Actions du dépôt GitHub)

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Sans ces secrets, l'APK et le déploiement web compilent quand même (un fichier
`.env` factice est généré pour la compilation) mais l'app affichera l'écran
d'erreur "Impossible d'initialiser Supabase" au lancement.

### Activer GitHub Pages (à faire une seule fois)

Settings > Pages > Build and deployment > Source : sélectionner **GitHub Actions**.

La démo est ensuite servie sur `https://<owner>.github.io/<repo>/` — l'URL
exacte dépend du `--base-href` passé à `flutter build web` dans le job
`deploy_web`, à adapter si le dépôt est renommé (voir le commit
`9d4d549` qui a dû corriger exactement ce cas après un renommage).

## 5. Build manuel (hors CI)

```bash
flutter build web --release --base-href /Scriptoria/
flutter build apk --release
```

L'APK produit est signé avec la clé de debug (`signingConfig =
signingConfigs.getByName("debug")` dans `android/app/build.gradle.kts`) — à
remplacer par une vraie clé de release avant toute publication sur un store.
