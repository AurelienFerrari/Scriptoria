import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/format_last_update.dart';
import '../../../../ui/widgets/room_navbar.dart';
import '../room_home_page.dart';
import '../room_contents_page.dart';
import '../room_chat_page.dart';
import '../room_settings_page.dart';
import '../room_tools_page.dart';

/// Coquille d'une room : monte le [RoomProvider] (campagne + rôle de
/// l'utilisateur courant) et le distribue à tous les onglets, qui n'ont donc
/// plus à recalculer chacun de leur côté qui les regarde.
class RoomShell extends StatelessWidget {
  final String roomId;
  const RoomShell({Key? key, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RoomProvider>(
      create: (_) => RoomProvider(
        auth: context.read<AuthProvider>(),
        roomId: roomId,
      )..load(),
      child: const _RoomShellView(),
    );
  }
}

class _RoomShellView extends StatefulWidget {
  const _RoomShellView();

  @override
  State<_RoomShellView> createState() => _RoomShellViewState();
}

class _RoomShellViewState extends State<_RoomShellView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();

    if (room.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF161622),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!room.exists) {
      return Scaffold(
        backgroundColor: const Color(0xFF161622),
        appBar: AppBar(title: const Text('Room introuvable')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Cette room n'existe pas ou plus.",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final iconUrl = room.iconUrl;

    final roomPages = <Widget>[
      RoomHomePage(
        roomName: room.title,
        iconPath: iconUrl,
        // Les icônes de démonstration sont des chemins d'asset ; toute
        // autre valeur est une URL publique Supabase Storage (image
        // importée depuis la galerie, voir RoomCreatePage.uploadImage).
        iconIsAsset: iconUrl == null || iconUrl.startsWith('assets/'),
        description: room.description,
        lastUpdate: formatLastUpdate(room.lastUpdateRaw),
      ),
      const RoomContentsPage(),
      const RoomToolsPage(),
      const RoomChatPage(),
      const RoomSettingsPage(),
    ];

    return Scaffold(
      body: roomPages[_tab],
      bottomNavigationBar: RoomNavbar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}
