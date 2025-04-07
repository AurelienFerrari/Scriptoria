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
          CircleAvatar(
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 16),
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
              imageUrl: 'assets/images/mystery.jpg',
              onTap: () {},
              actionButton: ElevatedButton(
                onPressed: () {},
                child: const Text('Rejoindre la room'),
              ),
            ),
            const SizedBox(height: 12),
            CampaignCard(
              title: 'La Quête du Dragon',
              lastUpdate: 'il y a 2 jours',
              imageUrl: 'assets/images/dragon.jpg',
              onTap: () {},
              actionButton: ElevatedButton(
                onPressed: () {},
                child: const Text('Continuer'),
              ),
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle room'),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.note_add),
                  label: const Text('Nouveau document'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}