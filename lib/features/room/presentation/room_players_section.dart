import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/utils/friendly_error.dart';

/// Liste des membres d'une room, affichée dans ses paramètres.
///
/// Le MJ y voit le code d'invitation et peut exclure un joueur ; un joueur y
/// voit seulement qui est autour de la table. La distinction est aussi
/// appliquée côté base par la policy `campaign_members_delete_self_or_mj` :
/// l'absence de bouton n'est qu'un confort d'interface.
class RoomPlayersSection extends StatefulWidget {
  const RoomPlayersSection({Key? key}) : super(key: key);

  @override
  State<RoomPlayersSection> createState() => _RoomPlayersSectionState();
}

class _RoomPlayersSectionState extends State<RoomPlayersSection> {
  late Future<List<Map<String, dynamic>>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<Map<String, dynamic>>> _loadMembers() {
    final room = context.read<RoomProvider>();
    return context.read<AuthProvider>().getCampaignMembers(room.roomId);
  }

  void _reload() {
    // Corps en bloc, et non en flèche : `setState(() => x = future)` renvoie
    // la valeur affectée, donc un Future, ce que setState rejette.
    setState(() {
      _membersFuture = _loadMembers();
    });
  }

  /// Nom à afficher, avec repli : un profil peut manquer si son insertion a
  /// échoué à l'inscription, et une ligne sans nom serait incompréhensible.
  String _displayName(Map<String, dynamic> member) {
    final displayName = member['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName;

    final username = member['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username;

    return 'Utilisateur sans profil';
  }

  Future<void> _confirmAndRemove(Map<String, dynamic> member) async {
    final name = _displayName(member);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Exclure $name ?'),
        content: const Text(
          'Ce joueur perdra l\'accès à la room. Il pourra la rejoindre à '
          'nouveau avec le code d\'invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exclure', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final room = context.read<RoomProvider>();
    try {
      await context.read<AuthProvider>().removeCampaignMember(
            campaignId: room.roomId,
            userId: member['user_id'] as String,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    // Le rechargement est volontairement hors du `try` : une erreur de
    // rafraîchissement n'est pas un échec d'exclusion, et les confondre a
    // déjà fait rapporter comme « exclusion impossible » une suppression qui
    // avait parfaitement abouti.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Joueurs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        if (room.isMj && room.joinCode != null) _buildJoinCode(room.joinCode!),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final members = snapshot.data ?? const [];
            if (members.isEmpty) {
              return const ListTile(
                title: Text('Aucun joueur pour l\'instant'),
              );
            }

            return Column(
              children: members.map((member) => _buildMember(member, room)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildJoinCode(String joinCode) {
    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: const Text('Code d\'invitation'),
      subtitle: Text(
        joinCode,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        tooltip: 'Copier le code d\'invitation',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: joinCode));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code d\'invitation copié')),
          );
        },
      ),
    );
  }

  Widget _buildMember(Map<String, dynamic> member, RoomProvider room) {
    final isMjMember = member['role'] == 'mj';
    final avatarUrl = member['avatar_url'] as String?;
    final name = _displayName(member);
    final isSelf = member['user_id'] == context.read<AuthProvider>().currentUser?.id;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? NetworkImage(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Text(name.characters.first.toUpperCase())
            : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (isMjMember) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6FE3E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'MJ',
                style: TextStyle(
                  color: Color(0xFF161622),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: isSelf ? const Text('Vous') : null,
      // Le MJ ne peut exclure ni lui-même ni un autre MJ : la base refuse de
      // toute façon de supprimer une ligne de rôle `mj`.
      trailing: (room.isMj && !isMjMember)
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Exclure $name',
              color: Colors.red,
              onPressed: () => _confirmAndRemove(member),
            )
          : null,
    );
  }
}
