import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/friendly_error.dart';
import '../audience_dialog.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Rédaction d'une publication du fil, réservée au MJ.
///
/// Texte, image, ou les deux — et surtout le choix des destinataires, fait
/// avant publication plutôt qu'après : une révélation adressée à un seul
/// joueur ne doit pas passer par une seconde où toute la table la voit.
class RoomPostComposerPage extends StatefulWidget {
  const RoomPostComposerPage({Key? key}) : super(key: key);

  @override
  State<RoomPostComposerPage> createState() => _RoomPostComposerPageState();
}

class _RoomPostComposerPageState extends State<RoomPostComposerPage> {
  final TextEditingController _bodyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _image;
  bool _isPublishing = false;

  /// `null` par défaut : une annonce s'adresse à toute la table sauf mention
  /// contraire.
  List<String>? _visibleTo;
  List<Map<String, dynamic>> _players = const [];

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final room = context.read<RoomProvider>();
    final members =
        await context.read<AuthProvider>().getCampaignMembers(room.roomId);
    if (!mounted) return;
    setState(() {
      // Le MJ reçoit toujours ce qu'il publie : l'inscrire dans la liste
      // laisserait croire qu'il peut s'en exclure.
      _players = members.where((member) => member['role'] != 'mj').toList();
    });
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _image = file);
  }

  Future<void> _chooseAudience() async {
    final choice = await showAudienceDialog(
      context: context,
      members: _players,
      current: _visibleTo,
      title: 'Qui reçoit cette publication ?',
      // On ne publie pas une annonce à destination de personne.
      allowNobody: false,
    );

    if (choice == null || !mounted) return;
    setState(() => _visibleTo = choice.visibleTo);
  }

  String get _audienceLabel {
    final visibleTo = _visibleTo;
    if (visibleTo == null) return 'Tous les joueurs';
    if (visibleTo.isEmpty) return 'Aucun destinataire choisi';
    return '${visibleTo.length} joueur${visibleTo.length > 1 ? 's' : ''}';
  }

  Future<void> _publish() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écrivez un texte ou ajoutez une image.')),
      );
      return;
    }

    final visibleTo = _visibleTo;
    if (visibleTo != null && visibleTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez au moins un destinataire.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final room = context.read<RoomProvider>();
    final authorId = auth.currentUser?.id;
    if (authorId == null) return;

    setState(() => _isPublishing = true);
    try {
      await auth.createRoomPost(
        campaignId: room.roomId,
        authorId: authorId,
        body: body.isEmpty ? null : body,
        image: _image,
        visibleTo: visibleTo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isPublishing = false);
      }
      return;
    }

    // `true` signale au fil appelant qu'il doit se recharger.
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('Publier sur le fil'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _bodyController,
                      maxLines: 6,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Ce que vous voulez dire à la table…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: _cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_image != null) _buildImagePreview(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined, size: 20),
                      label: Text(
                        _image == null ? 'Ajouter une image' : 'Changer l\'image',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group_outlined, color: _primaryColor),
                      title: const Text(
                        'Destinataires',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _audienceLabel,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: _chooseAudience,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                icon: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Publier'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: _primaryColor,
                  foregroundColor: _bgColor,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isPublishing ? null : _publish,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final image = _image!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // `dart:io` n'existe pas sur le web : l'aperçu y passe par les
            // octets du fichier, que `XFile` sait fournir partout.
            child: kIsWeb
                ? FutureBuilder(
                    future: image.readAsBytes(),
                    builder: (context, snapshot) => snapshot.hasData
                        ? Image.memory(
                            snapshot.data!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          )
                        : const SizedBox(height: 180),
                  )
                : Image.file(
                    File(image.path),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Retirer l\'image',
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: () => setState(() => _image = null),
          ),
        ],
      ),
    );
  }
}
