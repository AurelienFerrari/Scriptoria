import 'package:flutter/material.dart';

import '../../../../core/utils/format_last_update.dart';

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
    if (activity.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activité récente',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...activity.map(_buildTile),
      ],
    );
  }

  Widget _buildTile(Map<String, dynamic> item) {
    final isNote = item['kind'] == 'note';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        isNote ? Icons.description_outlined : Icons.image_outlined,
        color: isNote ? const Color(0xFF6FE3E1) : Colors.grey[400],
      ),
      title: Text(
        item['label'] as String? ?? 'Sans titre',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${item['campaign_title']} · ${formatLastUpdate(item['at'] as String?)}',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      onTap: () => onOpenRoom(item['campaign_id'] as String),
    );
  }
}
