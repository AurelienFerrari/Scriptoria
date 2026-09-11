import 'package:flutter/material.dart';
import 'dart:io';

import 'zoomable_image_viewer.dart';

/// Galerie d'images d'une room.
///
/// [onAddImage], [onDeleteImage] et [onEditVisibility] valent `null` en lecture
/// seule : c'est le mode des joueurs, qui consultent les images publiées par
/// le MJ sans pouvoir y toucher. Les commandes correspondantes disparaissent
/// alors, plutôt que d'être affichées désactivées — un bouton grisé laisserait
/// croire à un droit qu'on n'a pas.
class GalleryGrid extends StatelessWidget {
  final List<GalleryImage> images;
  final VoidCallback? onAddImage;
  final void Function(int index)? onDeleteImage;
  final void Function(int index)? onEditVisibility;

  const GalleryGrid({
    Key? key,
    required this.images,
    this.onAddImage,
    this.onDeleteImage,
    this.onEditVisibility,
  }) : super(key: key);

  bool get _canManage => onDeleteImage != null || onEditVisibility != null;

  /// Ouvre les actions disponibles sur une image.
  ///
  /// Elles vivaient uniquement dans l'aperçu plein écran, ce qui obligeait à
  /// ouvrir chaque image pour la gérer.
  void _showImageActions(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF232336),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEditVisibility != null)
              ListTile(
                leading:
                    const Icon(Icons.visibility_outlined, color: Colors.white),
                title: const Text('Visibilité',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  images[index].visibility?.label ?? '',
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onEditVisibility!(index);
                },
              ),
            if (onDeleteImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDeleteImage!(index);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (onAddImage != null) _buildAddButton(context),
      ...List.generate(
          images.length, (i) => _buildGalleryImage(context, images[i], i)),
    ];

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          "Le maître du jeu n'a pas encore publié d'image.",
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.extent(
      // Une largeur de tuile plutôt qu'un nombre de colonnes : trois colonnes
      // figées donnaient des tuiles d'environ 240 dp téléphone couché, soit une
      // seule rangée par écran. Le téléphone de test garde ses trois colonnes
      // en portrait, et en affiche cinq une fois couché.
      maxCrossAxisExtent: 160,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: items,
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ajouter une image',
      child: GestureDetector(
        onTap: onAddImage,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: const Center(
            child: Icon(Icons.add, color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryImage(
      BuildContext context, GalleryImage img, int initialIndex) {
    // La vignette et son bouton de menu sont deux cibles distinctes, posées
    // côte à côte dans la pile. Imbriquer le bouton dans le nœud sémantique de
    // l'image transformait celui-ci en simple conteneur : son nom accessible
    // n'était plus annoncé, et l'image devenait introuvable pour un lecteur
    // d'écran comme pour un test.
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          button: true,
          label: 'Ouvrir l\'image ${initialIndex + 1}',
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  PageController controller =
                      PageController(initialPage: initialIndex);
                  return StatefulBuilder(
                    builder: (context, setState) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(8),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          PageView.builder(
                            controller: controller,
                            itemCount: images.length,
                            itemBuilder: (context, i) {
                              final img = images[i];
                              Widget imageWidget = img.isAsset
                                  ? Image.asset(img.path, fit: BoxFit.contain)
                                  : img.isNetwork
                                      ? Image.network(img.path,
                                          fit: BoxFit.contain)
                                      : Image.file(File(img.path),
                                          fit: BoxFit.contain);
                              return ZoomableImageViewer(
                                imageWidget: imageWidget,
                              );
                            },
                          ),
                          // Bouton retour (close)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 32),
                              tooltip: 'Fermer',
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          // Bouton suppression, absent en lecture seule.
                          if (onDeleteImage != null)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 32),
                                tooltip: 'Supprimer l\'image',
                                // L'aperçu est refermé **avant** de déclencher la
                                // suppression : celle-ci ouvre une confirmation de
                                // façon synchrone, et un `pop` placé après aurait
                                // refermé cette confirmation au lieu de l'aperçu.
                                onPressed: () {
                                  final index =
                                      controller.page?.round() ?? initialIndex;
                                  Navigator.of(context).pop();
                                  onDeleteImage!(index);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: img.isAsset
                  ? Image.asset(img.path,
                      fit: BoxFit.cover, excludeFromSemantics: true)
                  : img.isNetwork
                      ? Image.network(
                          img.path,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          // Une URL devenue invalide ne doit pas casser la grille
                          // entière : la vignette signale la panne et le reste de
                          // la galerie continue de s'afficher.
                          errorBuilder: (context, error, stack) =>
                              const ColoredBox(
                            color: Colors.white10,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white38),
                            ),
                          ),
                        )
                      : Image.file(File(img.path),
                          fit: BoxFit.cover, excludeFromSemantics: true),
            ),
          ),
        ),
        if (img.visibility != null)
          Positioned(
            left: 4,
            bottom: 4,
            child: _VisibilityBadge(visibility: img.visibility!),
          ),
        if (_canManage)
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              tooltip: 'Actions sur l\'image ${initialIndex + 1}',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _showImageActions(context, initialIndex),
            ),
          ),
      ],
    );
  }
}

/// Qui voit une image de la galerie.
///
/// Rendu visible sur la vignette : sans repère, le MJ ne sait plus ce qu'il a
/// déjà révélé, et c'est précisément l'information dont il a besoin d'un coup
/// d'œil en pleine partie.
enum GalleryVisibility {
  everyone(Icons.groups_outlined, 'Tous les joueurs'),
  nobody(Icons.lock_outline, 'Masquée'),
  restricted(Icons.person_outline, 'Joueurs choisis');

  const GalleryVisibility(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _VisibilityBadge extends StatelessWidget {
  final GalleryVisibility visibility;

  const _VisibilityBadge({required this.visibility});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // `container: true` : sans lui, l'annotation se fond dans le nœud
      // parent au lieu de former son propre élément, et l'information de
      // visibilité n'est jamais annoncée.
      container: true,
      label: 'Visibilité : ${visibility.label}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Icon(
          visibility.icon,
          size: 16,
          color: visibility == GalleryVisibility.everyone
              ? const Color(0xFF7BE38C)
              : const Color(0xFFE3C77B),
        ),
      ),
    );
  }
}

class GalleryImage {
  final String path;
  final bool isAsset;
  final bool isNetwork;

  /// Laissé à `null` côté joueur : un joueur ne voit que ce à quoi il a droit,
  /// lui afficher un badge de visibilité n'aurait aucun sens.
  final GalleryVisibility? visibility;

  const GalleryImage.asset(this.path, {this.visibility})
      : isAsset = true,
        isNetwork = false;
  const GalleryImage.network(this.path, {this.visibility})
      : isAsset = false,
        isNetwork = true;
  const GalleryImage.file(this.path, {this.visibility})
      : isAsset = false,
        isNetwork = false;
}

