import 'package:flutter/material.dart';

/// Carte d'une room sur l'accueil.
///
/// Les compteurs viennent de la vue `campaign_overview`, qui s'exécute avec
/// les droits de celui qui la lit : ils reflètent donc ce que l'utilisateur
/// peut réellement voir. Un joueur ne compte que les images qu'on lui a
/// ouvertes, et [noteCount] vaut zéro pour lui — la ligne des notes disparaît
/// alors d'elle-même, sans avoir à tester le rôle ici.
class CampaignCard extends StatelessWidget {
  final String title;
  final String lastUpdate;
  final String? imageUrl;
  final String description;
  final int? memberCount;
  final int? imageCount;
  final int? noteCount;
  final VoidCallback onTap;
  final Widget? actionButton;

  const CampaignCard({
    Key? key,
    required this.title,
    required this.lastUpdate,
    required this.imageUrl,
    required this.onTap,
    this.description = '',
    this.memberCount,
    this.imageCount,
    this.noteCount,
    this.actionButton,
  }) : super(key: key);

  Widget _buildImage() {
    final url = imageUrl;
    if (url == null) {
      return Container(
        width: 72,
        height: 72,
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
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      );
    }
    return Image.network(
      url,
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 72,
        height: 72,
        color: Colors.grey[800],
        child: const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }

  /// Un compteur n'apparaît qu'avec quelque chose à compter : afficher
  /// « 0 image » sur une room qui démarre n'apprend rien et alourdit la carte.
  Widget _buildCounters() {
    final counters = <Widget>[
      if ((memberCount ?? 0) > 0)
        _Counter(
          icon: Icons.group_outlined,
          value: memberCount!,
          semanticLabel: '$memberCount membre${memberCount! > 1 ? 's' : ''}',
        ),
      if ((imageCount ?? 0) > 0)
        _Counter(
          icon: Icons.image_outlined,
          value: imageCount!,
          semanticLabel: '$imageCount image${imageCount! > 1 ? 's' : ''}',
        ),
      if ((noteCount ?? 0) > 0)
        _Counter(
          icon: Icons.description_outlined,
          value: noteCount!,
          semanticLabel: '$noteCount note${noteCount! > 1 ? 's' : ''}',
        ),
    ];

    if (counters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 16, runSpacing: 4, children: counters),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // Décorative : le titre affiché juste à côté porte déjà
                // l'information.
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    _buildCounters(),
                    const SizedBox(height: 6),
                    Text(
                      // Le libellé disait « MJ : » suivi d'une date de mise à
                      // jour, vestige d'un ancien contenu de démonstration.
                      'Mise à jour : $lastUpdate',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (actionButton != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(
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

class _Counter extends StatelessWidget {
  final IconData icon;
  final int value;
  final String semanticLabel;

  const _Counter({
    required this.icon,
    required this.value,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      // `excludeSemantics` : sans lui, le chiffre forme son propre nœud et un
      // lecteur d'écran annonce « 3 » sans dire de quoi. Le compteur est une
      // information visuelle composée, il doit être lu d'un bloc.
      excludeSemantics: true,
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
