import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/utils/friendly_error.dart';
import 'gallery_grid.dart';

/// Onglet « Contenus » d'une room : la galerie d'images publiée par le MJ.
///
/// La galerie vivait auparavant sur l'accueil de la room et ne survivait pas
/// à la fermeture de l'écran — les images n'existaient qu'en mémoire. Elle est
/// désormais stockée dans Supabase (bucket `images` et table du même nom) et
/// partagée avec toute la table.
///
/// Les notes du MJ viendront s'ajouter ici.
class RoomContentsPage extends StatefulWidget {
  const RoomContentsPage({Key? key}) : super(key: key);

  @override
  State<RoomContentsPage> createState() => _RoomContentsPageState();
}

class _RoomContentsPageState extends State<RoomContentsPage> {
  final ImagePicker _picker = ImagePicker();

  late Future<List<Map<String, dynamic>>> _imagesFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<Map<String, dynamic>>> _loadImages() {
    final room = context.read<RoomProvider>();
    return context.read<AuthProvider>().getCampaignImages(room.roomId);
  }

  void _reload() {
    // Corps en bloc : `setState(() => x = future)` renverrait le Future, que
    // setState refuse.
    setState(() {
      _imagesFuture = _loadImages();
    });
  }

  Future<void> _addImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final room = context.read<RoomProvider>();
    final ownerId = context.read<AuthProvider>().currentUser?.id;
    if (ownerId == null) return;

    setState(() => _isUploading = true);
    try {
      await context.read<AuthProvider>().addCampaignImage(
            file: file,
            campaignId: room.roomId,
            ownerId: ownerId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      if (mounted) setState(() => _isUploading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isUploading = false);
    _reload();
  }

  Future<void> _removeImage(Map<String, dynamic> image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer cette image ?'),
        content: const Text('Elle ne sera plus visible par les joueurs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthProvider>().removeCampaignImage(
            imageId: image['id'] as String,
            bucket: image['bucket'] as String,
            path: image['path'] as String,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    // Hors du `try` : une erreur de rechargement n'est pas un échec de
    // suppression, et les confondre rendrait le diagnostic trompeur.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contenus'),
        backgroundColor: const Color(0xFF161622),
      ),
      backgroundColor: const Color(0xFF161622),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Galerie',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              room.isMj
                  ? 'Les images que vous publiez ici sont visibles par tous les joueurs.'
                  : 'Les images publiées par le maître du jeu.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _imagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final images = snapshot.data ?? const [];

                return GalleryGrid(
                  images: images
                      .map((image) => GalleryImage.network(image['url'] as String))
                      .toList(),
                  onAddImage: room.isMj && !_isUploading ? _addImage : null,
                  onDeleteImage:
                      room.isMj ? (index) => _removeImage(images[index]) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
