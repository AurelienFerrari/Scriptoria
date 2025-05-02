import 'package:flutter/material.dart';
import '../../../campaigns/presentation/widgets/campaign_card.dart';
import '../../../documents/presentation/widgets/document_list_item.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 40),
            const SizedBox(width: 12),
            const Text('Accueil'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
            CampaignCard(
              title: 'Mystères de l\'Ombre',
              lastUpdate: 'il y a 3 h',
              imageUrl: 'assets/images/mystery.png',
              onTap: () {
                Navigator.pushNamed(context, '/room');
              },
            ),
            const SizedBox(height: 12),
            CampaignCard(
              title: 'La Quête du Dragon',
              lastUpdate: 'il y a 2 jours',
              imageUrl: 'assets/images/dragon.png',
              onTap: () {
                Navigator.pushNamed(context, '/room');
              },
            ),
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
              subtitle: 'Mystères du Ombre',
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