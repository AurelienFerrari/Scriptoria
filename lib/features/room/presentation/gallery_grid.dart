import 'package:flutter/material.dart';
import 'dart:io';

class GalleryGrid extends StatelessWidget {
  final List<GalleryImage> images;
  final VoidCallback onAddImage;
  final void Function(int index) onDeleteImage;

  const GalleryGrid({Key? key, required this.images, required this.onAddImage, required this.onDeleteImage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _buildAddButton(context),
      ...List.generate(images.length, (i) => _buildGalleryImage(context, images[i], i)),
    ];
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
    return GestureDetector(
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
    );
  }

  Widget _buildGalleryImage(BuildContext context, GalleryImage img, int initialIndex) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            PageController controller = PageController(initialPage: initialIndex);
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
                                : Image.file(File(img.path), fit: BoxFit.contain);
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    // Bouton suppression
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 32),
                        onPressed: () {
                          onDeleteImage(controller.page?.round() ?? initialIndex);
                          Navigator.of(context).pop();
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
            ? Image.asset(img.path, fit: BoxFit.cover)
            : img.isNetwork
                ? Image.network(img.path, fit: BoxFit.cover)
                : Image.file(File(img.path), fit: BoxFit.cover),
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
  const _ZoomableImageViewer({required this.imageWidget, required this.onSwipeDown});

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
