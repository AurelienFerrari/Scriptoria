import 'package:flutter/material.dart';

import '../../../../core/utils/format_relative_age.dart';

const Color _cardColor = Color(0xFF1E1F2E);
const Color _accentColor = Color(0xFF6FE3E1);

/// Dernières activités visibles par l'utilisateur, toutes rooms confondues.
///
/// Le contenu s'adapte au rôle sans qu'aucun test de rôle ne soit fait ici :
/// la RLS ne renvoie les notes qu'au MJ, et les images qu'à ceux à qui elles
/// ont été ouvertes. Un joueur y voit donc les illustrations qu'on lui a
/// partagées, un MJ ses notes de préparation.
class RecentActivitySection extends StatelessWidget {
  final List<Map<String, dynamic>> activity;

  /// Appelé avec l'identifiant de la room : chaque ligne mène quelque part,
  /// une liste d'activités qu'on ne peut pas suivre n'ayant guère d'intérêt.
  final void Function(String campaignId) onOpenRoom;

  const RecentActivitySection({
    Key? key,
    required this.activity,
    required this.onOpenRoom,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pas même un titre quand la liste est vide : une section « Activité
    // récente » sans contenu occuperait de la place pour annoncer qu'il ne
    // s'est rien passé.
    if (activity.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activité récente',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...activity.map(_buildTile),
      ],
    );
  }

  Widget _buildTile(Map<String, dynamic> item) {
    final isNote = item['kind'] == 'note';

    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenRoom(item['campaign_id'] as String),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildLeading(item, isNote),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['label'] as String? ?? 'Sans titre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item['campaign_title'] as String? ?? 'Room',
                            style: const TextStyle(
                              color: _accentColor,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' · ${formatRelativeAge(item['at'] as String?)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  /// Une image est représentée par elle-même plutôt que par une icône : c'est
  /// l'information la plus utile qu'on puisse mettre à cet endroit, et ça
  /// distingue les deux types d'entrée d'un coup d'œil.
  Widget _buildLeading(Map<String, dynamic> item, bool isNote) {
    if (!isNote && item['url'] is String) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          item['url'] as String,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) => _buildIconBox(
            Icons.broken_image_outlined,
            Colors.grey[500]!,
          ),
        ),
      );
    }

    return _buildIconBox(
      isNote ? Icons.description_outlined : Icons.image_outlined,
      isNote ? _accentColor : Colors.grey[400]!,
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
