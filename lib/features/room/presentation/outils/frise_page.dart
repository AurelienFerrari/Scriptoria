import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/friendly_error.dart';
import '../expandable_text.dart';
import '../room_route.dart';
import 'timeline_event_editor_page.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Le récit d'un évènement, plus discret que son titre.
const TextStyle _descriptionStyle = TextStyle(
  color: Colors.white70,
  fontSize: 15,
  height: 1.45,
);

/// Diamètre de la pastille, et hauteur de son centre depuis le haut de la
/// carte. Le trait de liaison s'aligne dessus, d'où les deux constantes
/// plutôt que des nombres répétés aux deux endroits.
const double _dotSize = 12;
const double _dotCenter = 22;

/// Frise chronologique de la room.
///
/// Le MJ y écrit l'histoire de la campagne et en règle l'ordre ; le joueur la
/// lit. La différence n'est pas qu'une affaire de boutons : les policies de
/// `room_timeline_events` réservent toute écriture au meneur, et ne renvoient
/// à un joueur que les évènements qui lui sont ouverts.
class FrisePage extends StatefulWidget {
  const FrisePage({Key? key}) : super(key: key);

  @override
  State<FrisePage> createState() => _FrisePageState();
}

class _FrisePageState extends State<FrisePage> {
  /// La liste est tenue en état plutôt que dans un `FutureBuilder` : un
  /// réordonnancement doit se voir immédiatement, avant même que la base ait
  /// confirmé.
  List<Map<String, dynamic>> _events = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final room = context.read<RoomProvider>();
    final events =
        await context.read<AuthProvider>().getTimelineEvents(room.roomId);
    if (!mounted) return;
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  /// Place à prendre au bout de la frise.
  ///
  /// Le maximum des positions existantes plutôt que le nombre d'évènements :
  /// après des suppressions, les deux ne coïncident plus, et repartir du
  /// compte réinsèrerait le nouvel évènement au milieu.
  int get _nextPosition {
    if (_events.isEmpty) return 0;
    final positions = _events.map((e) => e['position'] as int? ?? 0);
    return positions.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _openEditor({Map<String, dynamic>? event}) async {
    final saved = await pushRoomRoute<bool>(
      context,
      TimelineEventEditorPage(event: event, nextPosition: _nextPosition),
    );
    if (saved == true && mounted) await _load();
  }

  /// Déplace un évènement d'un cran, et renumérote la frise.
  ///
  /// Seules les lignes dont la position change partent en base : déplacer deux
  /// voisins ne doit pas réécrire toute la frise.
  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _events.length) return;

    final reordered = [..._events];
    reordered.insert(target, reordered.removeAt(index));

    final changes = <String, int>{};
    for (var i = 0; i < reordered.length; i++) {
      if ((reordered[i]['position'] as int?) != i) {
        changes[reordered[i]['id'] as String] = i;
        reordered[i] = {...reordered[i], 'position': i};
      }
    }

    // Affiché tout de suite : attendre l'aller-retour réseau donnerait
    // l'impression que le bouton n'a pas répondu.
    setState(() => _events = reordered);

    try {
      await context.read<AuthProvider>().updateTimelinePositions(changes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
      // L'ordre affiché ne correspond plus à la base : on la redemande plutôt
      // que de laisser une frise fausse à l'écran.
      await _load();
    }
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> event) async {
    final title = event['title'] as String? ?? 'cet évènement';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « $title » ?'),
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

    try {
      await context
          .read<AuthProvider>()
          .deleteTimelineEvent(event['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isMj = context.watch<RoomProvider>().isMj;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Frise'),
        backgroundColor: _bgColor,
      ),
      floatingActionButton: isMj
          ? FloatingActionButton.extended(
              backgroundColor: _primaryColor,
              foregroundColor: _bgColor,
              icon: const Icon(Icons.add),
              label: const Text('Évènement'),
              onPressed: () => _openEditor(),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _buildList(isMj),
              ),
      ),
    );
  }

  Widget _buildList(bool isMj) {
    return ListView(
      // Sans quoi la frise vide ne se laisserait pas tirer pour se recharger.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, isMj ? 96 : 24),
      children: [
        Text(
          isMj
              ? 'Vous écrivez l\'histoire de la campagne. Un évènement préparé peut rester caché jusqu\'à sa révélation.'
              : 'L\'histoire de la campagne, telle que votre maître du jeu la raconte.',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (_events.isEmpty) _buildEmpty(isMj) else ..._buildEvents(isMj),
      ],
    );
  }

  Widget _buildEmpty(bool isMj) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.timeline, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text(
            isMj
                ? 'La frise est vide. Ajoutez le premier évènement.'
                : 'Le maître du jeu n\'a pas encore écrit la frise.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEvents(bool isMj) {
    return [
      for (var i = 0; i < _events.length; i++)
        _buildEvent(
          event: _events[i],
          index: i,
          isMj: isMj,
          isFirst: i == 0,
          isLast: i == _events.length - 1,
        ),
    ];
  }

  Widget _buildEvent({
    required Map<String, dynamic> event,
    required int index,
    required bool isMj,
    required bool isFirst,
    required bool isLast,
  }) {
    final dateLabel = (event['date_label'] as String? ?? '').trim();
    final title = event['title'] as String? ?? 'Sans titre';
    final description = (event['description'] as String? ?? '').trim();

    // Le trait de liaison est posé derrière la ligne plutôt qu'à l'intérieur
    // d'un `IntrinsicHeight` : le récit est un `ExpandableText`, qui mesure sa
    // largeur avec un `LayoutBuilder`, et un `LayoutBuilder` refuse qu'on lui
    // demande sa hauteur intrinsèque. Le `Stack` prend la hauteur de la carte
    // et le trait s'y étire sans que rien n'ait à être mesuré.
    return Stack(
      children: [
        if (!(isFirst && isLast))
          Positioned(
            left: _dotSize / 2 - 1,
            // Le premier évènement part de sa pastille, le dernier s'y arrête :
            // la frise ne commence ni ne finit sur un trait en l'air.
            top: isFirst ? _dotCenter : 0,
            bottom: isLast ? null : 0,
            height: isLast ? _dotCenter : null,
            width: 2,
            child: const ColoredBox(color: Colors.white12),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDot(event: event, isMj: isMj),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateLabel.isNotEmpty) ...[
                      Text(
                        dateLabel.toUpperCase(),
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isMj) _buildMenu(event: event, index: index),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // Replié à une ligne, comme sur le fil : un récit de
                      // séance tient rarement en trois mots, et une frise dont
                      // chaque évènement fait un écran de haut ne se lit plus
                      // comme une frise.
                      ExpandableText(
                        text: description,
                        style: _descriptionStyle,
                      ),
                    ],
                    if (isMj) ...[
                      const SizedBox(height: 10),
                      _buildVisibilityBadge(event),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pastille de l'évènement, à gauche de sa carte.
  Widget _buildDot({
    required Map<String, dynamic> event,
    required bool isMj,
  }) {
    // Côté joueur, tout ce qui s'affiche lui est ouvert : la couleur n'a rien
    // à distinguer. Côté MJ, une pastille creuse rappelle d'un coup d'œil ce
    // qui reste caché.
    final restricted = isMj && event['visible_to'] != null;

    return SizedBox(
      width: _dotSize,
      child: Column(
        children: [
          SizedBox(height: _dotCenter - _dotSize / 2),
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: restricted ? _cardColor : _primaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: restricted ? _primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityBadge(Map<String, dynamic> event) {
    final raw = event['visible_to'] as List?;

    final String label;
    final IconData icon;
    if (raw == null) {
      label = 'Toute la table';
      icon = Icons.groups_outlined;
    } else if (raw.isEmpty) {
      label = 'Vous seul';
      icon = Icons.visibility_off_outlined;
    } else {
      label = '${raw.length} joueur${raw.length > 1 ? 's' : ''}';
      icon = Icons.person_outline;
    }

    // `container: true` : sans lui l'annotation fusionnerait avec le nœud
    // parent, et l'étiquette deviendrait introuvable pour un lecteur d'écran
    // comme pour les tests.
    return Semantics(
      container: true,
      label: 'Visibilité : $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu({
    required Map<String, dynamic> event,
    required int index,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.white54),
      tooltip: 'Actions sur « ${event['title']} »',
      color: _cardColor,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openEditor(event: event);
          case 'up':
            _move(index, -1);
          case 'down':
            _move(index, 1);
          case 'delete':
            _confirmAndDelete(event);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Text('Modifier', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 'up',
          enabled: index > 0,
          child: Text(
            'Monter',
            style: TextStyle(
              color: index > 0 ? Colors.white : Colors.white24,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'down',
          enabled: index < _events.length - 1,
          child: Text(
            'Descendre',
            style: TextStyle(
              color: index < _events.length - 1 ? Colors.white : Colors.white24,
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
