import 'package:flutter/material.dart';

class CampaignCard extends StatelessWidget {
  final String title;
  final String lastUpdate;
  final String? imageUrl;
  final VoidCallback onTap;
  final Widget? actionButton;

  const CampaignCard({
    Key? key,
    required this.title,
    required this.lastUpdate,
    required this.imageUrl,
    required this.onTap,
    this.actionButton,
  }) : super(key: key);

  Widget _buildImage() {
    final url = imageUrl;
    if (url == null) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[800],
        child: const Icon(Icons.auto_stories, color: Colors.white54),
      );
    }
    // Les icônes de démonstration choisies à la création sont des chemins
    // d'asset ; toute autre valeur est une URL publique Supabase Storage
    // (image importée depuis la galerie, voir RoomCreatePage.uploadImage).
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      );
    }
    return Image.network(
      url,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 80,
        height: 80,
        color: Colors.grey[800],
        child: const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1F2E),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // Décorative : le titre affiché juste à côté porte déjà l'information.
                child: _buildImage(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MJ: $lastUpdate',
                      style: TextStyle(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              if (actionButton != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 0,
                    maxWidth: 120,
                    minHeight: 36,
                    maxHeight: 36,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: actionButton!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}