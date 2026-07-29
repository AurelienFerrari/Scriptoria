import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/format_last_update.dart';
import '../../../campaigns/presentation/widgets/campaign_card.dart';
import '../../../documents/presentation/widgets/document_list_item.dart';
import '../../../room/presentation/shell/room_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List<Map<String, dynamic>>> _campaignsFuture;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    _campaignsFuture = userId == null
        ? Future.value(<Map<String, dynamic>>[])
        : authProvider.getVisibleCampaigns(userId);
  }

  Widget _buildCampaigns() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _campaignsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final campaigns = snapshot.data ?? [];
        if (campaigns.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Vous n'avez pas encore de room. Créez-en une ou rejoignez-en une avec un code.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            for (final campaign in campaigns) ...[
              CampaignCard(
                title: campaign['title'] as String? ?? 'Sans titre',
                lastUpdate: formatLastUpdate(
                  (campaign['updated_at'] ?? campaign['created_at']) as String?,
                ),
                imageUrl: campaign['icon_url'] as String?,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomShell(roomId: campaign['id'] as String),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 40, excludeFromSemantics: true),
            const SizedBox(width: 12),
            const Text('Accueil'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Semantics(
              button: true,
              label: 'Voir le profil',
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: const Icon(Icons.person_outline),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Campagnes en cours',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildCampaigns(),
            const SizedBox(height: 24),
            const Text(
              'Derniers documents modifiés',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DocumentListItem(
              title: 'Carte du Royaume',
              subtitle: 'Mystères de l\'Ombre',
              lastModified: 'il y a 1 jour',
              onTap: () {},
            ),
            const Divider(),
            DocumentListItem(
              title: 'Personnages Importants',
              subtitle: 'La Quête du Dragon',
              lastModified: 'il y a 4 jours',
              onTap: () {},
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/CreationRoom');
                    },
                    label: const Text(
                      'Créer une room',
                      style: TextStyle(
                        color: Color(0xFFB39DDB),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: Color(0xFFB39DDB), width: 2),
                      backgroundColor: Colors.white.withOpacity(0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      shadowColor: Colors.black.withOpacity(0.12),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/JoinRoom');
                    },
                    label: const Text(
                      'Rejoindre une room',
                      style: TextStyle(
                        color: Color(0xFFB39DDB),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: Color(0xFFB39DDB), width: 2),
                      backgroundColor: Colors.white.withOpacity(0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      shadowColor: Colors.black.withOpacity(0.12),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
