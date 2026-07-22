import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../ui/widgets/room_navbar.dart';
import '../room_home_page.dart';
import '../room_map_page.dart';
import '../room_chat_page.dart';
import '../room_settings_page.dart';
import '../room_tools_page.dart';

class RoomShell extends StatefulWidget {
  final String roomId;
  const RoomShell({Key? key, required this.roomId}) : super(key: key);

  @override
  State<RoomShell> createState() => _RoomShellState();
}

class _RoomShellState extends State<RoomShell> {
  int _tab = 0;
  late final Future<Map<String, dynamic>?> _campaignFuture;

  @override
  void initState() {
    super.initState();
    _campaignFuture = context.read<AuthProvider>().getCampaignById(widget.roomId);
  }

  String _formatLastUpdate(String? iso) {
    if (iso == null) return 'Inconnue';
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return 'Inconnue';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} à ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _campaignFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF161622),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final campaign = snapshot.data;
        if (campaign == null) {
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

        final iconUrl = campaign['icon_url'] as String?;

        final roomPages = <Widget>[
          RoomHomePage(
            roomName: campaign['title'] as String? ?? 'Room',
            iconPath: iconUrl,
            // Les icônes de démonstration sont des chemins d'asset ; toute
            // autre valeur est une URL publique Supabase Storage (image
            // importée depuis la galerie, voir RoomCreatePage.uploadImage).
            iconIsAsset: iconUrl == null || iconUrl.startsWith('assets/'),
            description: campaign['description'] as String? ?? '',
            lastUpdate: _formatLastUpdate(
              (campaign['updated_at'] ?? campaign['created_at']) as String?,
            ),
          ),
          const RoomMapPage(),
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
      },
    );
  }
}
