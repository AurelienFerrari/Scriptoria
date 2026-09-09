import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/providers/room_provider.dart';
import 'package:scriptoria/core/utils/friendly_error.dart';
import 'package:scriptoria/features/room/presentation/room_players_section.dart';

/// Paramètres d'une room : renommage et suppression pour le MJ, liste des
/// membres pour tout le monde.
///
/// Les informations viennent du [RoomProvider] monté par `RoomShell` plutôt
/// que de paramètres de constructeur : le titre change ici même, et le
/// provider est le seul endroit où l'état de la room fait autorité.
class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({Key? key}) : super(key: key);

  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  bool _isDeleting = false;
  bool _isLeaving = false;

  Future<void> _renameRoom() async {
    final room = context.read<RoomProvider>();
    final controller = TextEditingController(text: room.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de la room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom'),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == room.title) return;
    if (!mounted) return;

    try {
      await context.read<AuthProvider>().updateCampaign(
            campaignId: room.roomId,
            title: newTitle,
          );
      await room.refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    }
  }

  /// Un joueur quitte la room de lui-même.
  ///
  /// La même policy que l'exclusion par le MJ s'applique
  /// (`campaign_members_delete_self_or_mj`), et elle interdit la ligne d'un
  /// MJ : un meneur ne peut pas abandonner sa propre table, il la supprime.
  Future<void> _confirmAndLeave() async {
    final room = context.read<RoomProvider>();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter cette room ?'),
        content: const Text(
          'Vous perdrez l\'accès à son contenu. Vous pourrez la rejoindre à '
          'nouveau avec le code d\'invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLeaving = true);
    try {
      await context.read<AuthProvider>().removeCampaignMember(
            campaignId: room.roomId,
            userId: userId,
          );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isLeaving = false);
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette room ?'),
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

    setState(() => _isDeleting = true);
    try {
      await context.read<AuthProvider>().deleteCampaign(
            context.read<RoomProvider>().roomId,
          );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de la Room'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Nom de la room'),
            subtitle: Text(room.title),
            // Renommer est réservé au MJ ; la policy `campaigns_update_own`
            // le refuserait de toute façon à un joueur.
            enabled: room.isMj,
            onTap: room.isMj ? _renameRoom : null,
          ),
          const Divider(height: 32),
          const RoomPlayersSection(),
          const Divider(height: 32),
          if (room.isMj)
            ListTile(
              leading: _isDeleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete),
              title: const Text('Supprimer la room'),
              onTap: _isDeleting ? null : _confirmAndDelete,
              textColor: Colors.red,
              iconColor: Colors.red,
            )
          else
            ListTile(
              leading: _isLeaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              title: const Text('Quitter la room'),
              onTap: _isLeaving ? null : _confirmAndLeave,
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
        ],
      ),
    );
  }
}
