import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/providers/room_provider.dart';
import 'package:scriptoria/core/utils/friendly_auth_error.dart';
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
          SnackBar(content: Text(friendlyAuthErrorMessage(e))),
        );
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
          SnackBar(content: Text(friendlyAuthErrorMessage(e))),
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
          if (room.isMj) ...[
            const Divider(height: 32),
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
            ),
          ],
        ],
      ),
    );
  }
}
