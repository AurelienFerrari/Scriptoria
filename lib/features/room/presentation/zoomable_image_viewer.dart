import 'package:flutter/material.dart';

/// Image plein écran, zoomable au pincement et au double-tap.
///
/// Extraite de la galerie, où elle était privée : le fil de la room en a
/// désormais besoin aussi, et la dupliquer aurait fait diverger deux
/// comportements de zoom.
class ZoomableImageViewer extends StatefulWidget {
  final Widget imageWidget;

  const ZoomableImageViewer({Key? key, required this.imageWidget})
      : super(key: key);

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer> {
  final TransformationController _controller = TransformationController();
  double _currentScale = 1.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    final position = details.localPosition;
    setState(() {
      if (_currentScale == 1.0) {
        // Zoom centré sur le point touché, et non sur le coin de l'image.
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
      // Présent mais vide : sans lui, `onDoubleTapDown` n'est jamais appelé.
      onDoubleTap: () {},
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

/// Ouvre une image seule en plein écran.
///
/// La galerie a sa propre visionneuse, qui permet de feuilleter les images
/// voisines. Celle-ci sert là où il n'y en a qu'une — l'image d'une
/// publication du fil.
Future<void> showSingleImageViewer(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          ZoomableImageViewer(
            imageWidget: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white38, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
