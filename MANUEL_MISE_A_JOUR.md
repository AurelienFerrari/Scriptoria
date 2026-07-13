# Manuel de mise à jour

## Mise à jour des dépendances

| | |
|---|---|
| **Fréquence** | Vérification manuelle ponctuelle (pas d'automatisation type Dependabot à ce stade) |
| **Périmètre** | Les paquets Dart/Flutter listés dans [`pubspec.yaml`](pubspec.yaml) |
| **Type** | Manuel |

```bash
flutter pub outdated   # liste les paquets ayant une version plus récente disponible
flutter pub upgrade     # met à jour dans les bornes de version déjà déclarées dans pubspec.yaml
```

Après une mise à jour de dépendance :
1. Relire le changelog du paquet concerné (breaking changes éventuels).
2. `flutter analyze --no-fatal-infos` et `flutter test` en local.
3. Commit de `pubspec.yaml` **et** `pubspec.lock` (le lock file est versionné pour une app, contrairement à une librairie).
4. Laisser la CI confirmer avant de merger.

## Versioning

Le projet suit le [Semantic Versioning](https://semver.org/lang/fr/)
(`MAJOR.MINOR.PATCH`) depuis la version `0.1.0` — voir
[CHANGELOG.md](CHANGELOG.md) pour l'historique et la justification du départ
en `0.x` plutôt qu'en `1.0.0`.

### Publier une nouvelle version

1. S'assurer que `main` est vert en CI.
2. Bumper le numéro de version dans `pubspec.yaml` (`version: X.Y.Z+B` — `B`
   est le build number, à incrémenter à chaque publication même sans
   changement de `X.Y.Z`).
3. Ajouter une section correspondante en tête de `CHANGELOG.md` (catégories
   *Ajouté* / *Corrigé* / *Changé*, à la Keep a Changelog).
4. Committer, merger dans `main` (voir le workflow de branches ci-dessous).
5. Tagger le commit de merge : `git tag -a vX.Y.Z -m "..."` puis
   `git push origin vX.Y.Z`.
6. Le push sur `main` déclenche automatiquement le build APK et le
   déploiement web (voir [MANUEL_DEPLOIEMENT.md](MANUEL_DEPLOIEMENT.md)) : rien
   d'autre à faire manuellement pour publier.

### Workflow de branches

Le développement se fait sur une branche dédiée (`feature/...`, `fix/...`,
`docs/...`), fusionnée dans `main` avec `git merge --no-ff` (le merge reste
visible dans l'historique, à l'image de la fusion de `register` dans `main`),
puis poussée. `main` doit toujours rester vert en CI.

## Mettre à jour le schéma de base de données

Toute évolution du schéma passe par un nouveau fichier dans
[`supabase/migrations/`](supabase/migrations/), nommé
`YYYYMMDDHHMMSS_description.sql`, appliqué **en plus** des précédents (jamais
en modifiant un fichier déjà appliqué en production). Après application,
vérifier les avertissements de sécurité et de performance dans Database >
Advisors du dashboard Supabase — c'est ce qui a permis de détecter et
corriger deux problèmes de policies trop permissives lors de la mise en place
initiale du schéma (voir [PLAN_CORRECTION_BOGUES.md](PLAN_CORRECTION_BOGUES.md)).

## Revenir en arrière (rollback)

- **Application (web/APK)** : revert du commit fautif sur `main` (ou
  `git reset` vers le tag de la version précédente puis nouveau commit) —
  un nouveau push republie automatiquement via la CI.
- **Base de données** : pas de migration *down* automatisée à ce stade ; une
  restauration s'appuie sur les sauvegardes automatiques de Supabase
  (Database > Backups).
