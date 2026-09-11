import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/utils/format_relative_age.dart';
import '../../../core/utils/friendly_error.dart';
import 'audience_dialog.dart';
import 'expandable_text.dart';
import 'feed/room_post_composer_page.dart';
import 'room_route.dart';
import 'zoomable_image_viewer.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Accueil d'une room : son identité, puis le fil publié par le MJ.
///
/// L'écran se limitait auparavant à afficher le nom et la description, ce qui
/// n'en faisait pas grand-chose. Il porte désormais ce que le MJ adresse à sa
/// table — textes et images — chaque publication ayant ses propres
/// destinataires.
class RoomHomePage extends StatefulWidget {
  final String roomName;
  final String? iconPath;
  final bool iconIsAsset;
  final String description;
  final String lastUpdate;
  final String lastUpdateText;

  const RoomHomePage({
    Key? key,
    required this.roomName,
    this.iconPath,
    this.iconIsAsset = true,
    required this.description,
    required this.lastUpdate,
    this.lastUpdateText = 'Dernière mise à jour',
  }) : super(key: key);

  @override
  State<RoomHomePage> createState() => _RoomHomePageState();
}

class _RoomHomePageState extends State<RoomHomePage> {
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<Map<String, dynamic>>> _loadPosts() {
    final room = context.read<RoomProvider>();
    return context.read<AuthProvider>().getRoomPosts(room.roomId);
  }

  void _reload() {
    // Corps en bloc : `setState(() => x = future)` renverrait le Future, que
    // setState refuse.
    setState(() {
      _postsFuture = _loadPosts();
    });
  }

  Future<void> _compose() async {
    final published =
        await pushRoomRoute<bool>(context, const RoomPostComposerPage());
    if (published == true && mounted) _reload();
  }

  List<String>? _audienceOf(Map<String, dynamic> post) {
    final visibleTo = post['visible_to'] as List<dynamic>?;
    return visibleTo?.cast<String>().toList();
  }

  Future<void> _editAudience(Map<String, dynamic> post) async {
    final room = context.read<RoomProvider>();
    final members =
        await context.read<AuthProvider>().getCampaignMembers(room.roomId);
    if (!mounted) return;

    final choice = await showAudienceDialog(
      context: context,
      members: members.where((member) => member['role'] != 'mj').toList(),
      current: _audienceOf(post),
      title: 'Qui reçoit cette publication ?',
      allowNobody: false,
    );

    if (choice == null || !mounted) return;

    try {
      await context.read<AuthProvider>().updateRoomPostAudience(
            postId: post['id'] as String,
            visibleTo: choice.visibleTo,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    if (mounted) _reload();
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette publication ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthProvider>().deleteRoomPost(post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.roomName),
        backgroundColor: _bgColor,
      ),
      backgroundColor: _bgColor,
      floatingActionButton: room.isMj
          ? FloatingActionButton.extended(
              backgroundColor: _primaryColor,
              foregroundColor: _bgColor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Publier'),
              onPressed: _compose,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            const Text(
              'Le fil de la table',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final posts = snapshot.data ?? const [];
                if (posts.isEmpty) return _buildEmptyFeed(room.isMj);

                return Column(
                  children:
                      posts.map((post) => _buildPost(post, room.isMj)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Bandeau d'identité : icône, nom, description, dernière mise à jour.
  ///
  /// Compact, parce qu'il n'est plus le contenu de l'écran mais son en-tête.
  Widget _buildHeader() {
    final iconPath = widget.iconPath;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  // Décorative : le nom est affiché juste à côté.
                  child: widget.iconIsAsset
                      ? Image.asset(
                          iconPath,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        )
                      : Image.network(
                          iconPath,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (context, error, stack) => Container(
                            width: 64,
                            height: 64,
                            color: Colors.white10,
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.white38),
                          ),
                        ),
                ),
              if (iconPath != null) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roomName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.update,
                            color: Colors.white38, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${widget.lastUpdateText} : ${widget.lastUpdate}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.description,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyFeed(bool isMj) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 40, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            isMj
                ? 'Rien de publié pour l\'instant.\nUtilisez « Publier » pour parler à votre table.'
                : 'Le maître du jeu n\'a rien publié pour l\'instant.',
            style: const TextStyle(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPost(Map<String, dynamic> post, bool isMj) {
    final body = post['body'] as String?;
    final imageUrl = post['image_url'] as String?;
    final audience = _audienceOf(post);
    final isRestricted = audience != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Semantics(
              button: true,
              // `container: true` : sans lui, l'annotation se fond dans le
              // nœud de la carte au lieu de former sa propre cible, et un
              // lecteur d'écran n'annonce pas que l'image s'ouvre.
              container: true,
              label: 'Voir l\'image en grand',
              child: GestureDetector(
                onTap: () => showSingleImageViewer(context, imageUrl),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (body != null && body.trim().isNotEmpty) ...[
                  ExpandableText(text: body),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Text(
                      formatRelativeAge(post['created_at'] as String?),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    // Le badge de destinataires n'a de sens que pour le MJ :
                    // un joueur ne reçoit que ce qui lui est adressé, lui
                    // indiquer qu'une publication est restreinte ne lui
                    // apprendrait rien.
                    if (isMj && isRestricted) ...[
                      const SizedBox(width: 10),
                      _buildAudienceBadge(audience.length),
                    ],
                    const Spacer(),
                    if (isMj) _buildPostMenu(post),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceBadge(int count) {
    final label = '$count joueur${count > 1 ? 's' : ''}';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Adressée à $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE3C77B).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline,
                size: 13, color: Color(0xFFE3C77B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFE3C77B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMenu(Map<String, dynamic> post) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 20),
      tooltip: 'Actions sur la publication',
      color: _cardColor,
      onSelected: (value) {
        if (value == 'audience') _editAudience(post);
        if (value == 'delete') _confirmAndDelete(post);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'audience',
          child: Text('Destinataires', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
