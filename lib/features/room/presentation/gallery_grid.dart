import 'package:flutter/material.dart';
import 'dart:io';

/// Galerie d'images d'une room.
///
/// [onAddImage] et [onDeleteImage] valent `null` en lecture seule : c'est le
/// mode des joueurs, qui consultent les images publiées par le MJ sans
/// pouvoir en ajouter ni en retirer. Les boutons correspondants disparaissent
/// alors, plutôt que d'être affichés désactivés — un bouton grisé laisserait
/// croire à un droit qu'on n'a pas.
class GalleryGrid extends StatelessWidget {
  final List<GalleryImage> images;
  final VoidCallback? onAddImage;
  final void Function(int index)? onDeleteImage;

  const GalleryGrid({
    Key? key,
    required this.images,
    this.onAddImage,
    this.onDeleteImage,
  }) : super(key: key);

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
    return GridView.count(
      crossAxisCount: 3,
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
    // Nom accessible : la vignette est cliquable et ouvre l'aperçu plein
    // écran, mais ne portait aucun libellé — un lecteur d'écran n'annonçait
    // qu'une image sans indiquer qu'elle mène quelque part.
    return Semantics(
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
                                  ? Image.network(img.path, fit: BoxFit.contain)
                                  : Image.file(File(img.path),
                                      fit: BoxFit.contain);
                          return _ZoomableImageViewer(
                            imageWidget: imageWidget,
                            onSwipeDown: () => Navigator.of(context).pop(),
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
                      // entière : la vignette signale la panne et le reste de la
                      // galerie continue de s'afficher.
                      errorBuilder: (context, error, stack) => const ColoredBox(
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
    );
  }
}

class GalleryImage {
  final String path;
  final bool isAsset;
  final bool isNetwork;
  const GalleryImage.asset(this.path)
      : isAsset = true,
        isNetwork = false;
  const GalleryImage.network(this.path)
      : isAsset = false,
        isNetwork = true;
  const GalleryImage.file(this.path)
      : isAsset = false,
        isNetwork = false;
}

// Widget zoomable et swipe down pour l'aperçu plein écran
typedef VoidCallback = void Function();

class _ZoomableImageViewer extends StatefulWidget {
  final Widget imageWidget;
  final VoidCallback onSwipeDown;
  const _ZoomableImageViewer(
      {required this.imageWidget, required this.onSwipeDown});

  @override
  State<_ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<_ZoomableImageViewer> {
  final TransformationController _controller = TransformationController();
  double _currentScale = 1.0;

  void _handleDoubleTapDown(TapDownDetails details) {
    final position = details.localPosition;
    setState(() {
      if (_currentScale == 1.0) {
        // Zoom sur le centre du widget (pas sur le coin)
        final matrix = Matrix4.identity()
          ..translate(-position.dx * 2, -position.dy * 2)
          ..scale(3.0);
        _controller.value = matrix;
        _currentScale = 3.0;
      } else {
        _controller.value = Matrix4.identity();
        _currentScale = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: () {}, // doit être présent pour déclencher onDoubleTapDown

      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        panEnabled: true,
        child: widget.imageWidget,
      ),
    );
  }
}
