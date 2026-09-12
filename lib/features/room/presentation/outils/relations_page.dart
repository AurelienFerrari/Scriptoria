import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/monitoring/frame_watch.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/services/row_change.dart';
import '../../../../core/utils/friendly_error.dart';
import '../audience_dialog.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);
const Color _unknownColor = Color(0xFFE3C77B);

/// Rayon d'un rond, et espace réservé sous lui pour son nom.
const double _nodeRadius = 34;
const double _nodeLabelHeight = 34;

/// Marge conservée autour des ronds sur la carte.
const double _canvasPadding = 400;

/// Écart entre le dernier rond posé et le rond « + ».
const double _addSpotGap = 180;

/// Palette proposée au MJ pour ses catégories de lien.
const List<int> _categoryPalette = [
  0xFF6FE3E1,
  0xFFE3C77B,
  0xFFE37B7B,
  0xFF7BE38C,
  0xFFB07BE3,
  0xFF7BA7E3,
];

const Map<String, IconData> _kindIcons = {
  'person': Icons.person_outline,
  'place': Icons.place_outlined,
  'thing': Icons.inventory_2_outlined,
  'event': Icons.bolt_outlined,
};

const Map<String, String> _kindLabels = {
  'person': 'Personnage',
  'place': 'Lieu',
  'thing': 'Objet',
  'event': 'Évènement',
};

/// Habillage des champs de saisie des boîtes de dialogue.
///
/// Sans lui, Flutter affiche son champ souligné par défaut : sur une saisie de
/// plusieurs lignes, le trait se retrouve loin sous le texte, et dans une
/// couleur qui n'est pas celle de l'application.
InputDecoration _dialogField(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white54),
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: _bgColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primaryColor, width: 2),
    ),
  );
}

/// Carte des relations de la room, dans l'esprit du journal de bord d'Outer
/// Wilds : des ronds reliés par des liens de couleur, et sur chacun les
/// informations que le MJ dévoile à mesure des découvertes.
///
/// La carte est la même pour tout le monde. Ce qui change d'un joueur à
/// l'autre, c'est ce qu'il a découvert — et le tri est fait par la base : le
/// texte d'une information non découverte n'arrive jamais jusqu'ici, seul son
/// nombre est connu, ce qui suffit à afficher les « ??? ».
class RelationsPage extends StatefulWidget {
  const RelationsPage({Key? key}) : super(key: key);

  @override
  State<RelationsPage> createState() => _RelationsPageState();
}

class _RelationsPageState extends State<RelationsPage> {
  final TransformationController _transform = TransformationController();

  /// Mesure la fluidité de cet écran : c'est le seul qui dessine et qui suit
  /// le doigt, donc le seul où les images peuvent manquer.
  final FrameWatch _frames = FrameWatch('relations_graph');

  Map<String, dynamic>? _graph;
  List<Map<String, dynamic>> _players = const [];
  Object? _error;
  bool _isLoading = true;

  /// Positions affichées, que le MJ déplace au doigt avant qu'elles ne soient
  /// enregistrées.
  final Map<String, Offset> _positions = {};
  String? _dragging;

  /// Place du rond « + ».
  ///
  /// Fixée au chargement, et non recalculée à partir des ronds : déduite du
  /// rond le plus à droite, elle suivait le doigt pendant un déplacement,
  /// comme si les deux étaient attachés.
  Offset _addSpot = const Offset(400, 400);

  /// La vue se cadre sur le contenu au premier affichage : la carte est bien
  /// plus grande que l'écran, et son coin haut-gauche est vide.
  bool _needsCentering = true;

  /// Catégorie de lien mise en avant, ou `null` pour toutes.
  String? _filter;

  final List<StreamSubscription<RowChange>> _changes = [];
  Timer? _reloadSoon;

  bool get _isMj => _graph?['is_mj'] as bool? ?? false;

  List<Map<String, dynamic>> get _nodes => _listOf('nodes');
  List<Map<String, dynamic>> get _links => _listOf('links');
  List<Map<String, dynamic>> get _categories => _listOf('categories');

  List<Map<String, dynamic>> _listOf(String key) => [
        for (final item in (_graph?[key] as List?) ?? const [])
          Map<String, dynamic>.from(item as Map),
      ];

  @override
  void initState() {
    super.initState();
    _frames.start();
    _load();

    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;
    // Une information révélée touche son rond : c'est ce signal qui circule,
    // jamais le texte découvert.
    for (final table in const [
      'room_relation_nodes',
      'room_relation_links',
      'room_relation_categories',
    ]) {
      _changes.add(
        auth.watchRoomTable(table, roomId).listen((_) => _scheduleReload()),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _changes) {
      subscription.cancel();
    }
    _reloadSoon?.cancel();
    _transform.dispose();
    _frames.stop();
    super.dispose();
  }

  /// Recharge peu après un changement : poser un lien touche plusieurs tables
  /// d'affilée, et une seule relecture suffit.
  void _scheduleReload() {
    _reloadSoon?.cancel();
    _reloadSoon = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;

    Map<String, dynamic>? graph;
    Object? error;
    try {
      graph = await auth.getRelationGraph(roomId);
    } catch (e) {
      error = e;
    }
    final members = await auth.getCampaignMembers(roomId);
    if (!mounted) return;

    setState(() {
      _graph = graph ?? _graph;
      _error = error;
      _isLoading = false;
      _players = members.where((m) => m['role'] != 'mj').toList();
      if (graph != null) {
        // Les positions suivent la base, sauf celle qu'on est en train de
        // déplacer : elle appartient au doigt tant qu'il est posé.
        for (final node in _listOf('nodes')) {
          final id = node['id'] as String;
          if (id == _dragging) continue;
          _positions[id] = Offset(
            (node['x'] as num).toDouble(),
            (node['y'] as num).toDouble(),
          );
        }
        _addSpot = _freeSpot();
      }
    });
  }

  /// Place libre pour le prochain rond : à droite du dernier posé.
  Offset _freeSpot() {
    if (_nodes.isEmpty) return const Offset(400, 400);
    var rightmost = _positionOf(_nodes.first);
    for (final node in _nodes) {
      final position = _positionOf(node);
      if (position.dx > rightmost.dx) rightmost = position;
    }
    return rightmost + const Offset(_addSpotGap, 0);
  }

  Map<String, dynamic>? _nodeById(String id) {
    for (final node in _nodes) {
      if (node['id'] == id) return node;
    }
    return null;
  }

  Offset _positionOf(Map<String, dynamic> node) =>
      _positions[node['id']] ??
      Offset((node['x'] as num).toDouble(), (node['y'] as num).toDouble());

  /// Taille de la carte : de quoi contenir tous les ronds et le rond « + »,
  /// plus une marge pour pouvoir en poser d'autres au large.
  Size get _canvasSize {
    var maxX = math.max(800.0, _addSpot.dx);
    var maxY = math.max(800.0, _addSpot.dy);
    for (final node in _nodes) {
      final position = _positionOf(node);
      maxX = math.max(maxX, position.dx);
      maxY = math.max(maxY, position.dy);
    }
    return Size(maxX + _canvasPadding, maxY + _canvasPadding);
  }

  /// Ce que la carte contient réellement, pour savoir sur quoi se cadrer.
  Rect get _contentBounds {
    final points = <Offset>[
      for (final node in _nodes) _positionOf(node),
      if (_isMj) _addSpot,
    ];
    if (points.isEmpty) {
      return Rect.fromCircle(center: _addSpot, radius: _nodeRadius * 2);
    }

    var left = points.first.dx;
    var right = points.first.dx;
    var top = points.first.dy;
    var bottom = points.first.dy;
    for (final point in points) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom)
        .inflate(_nodeRadius + _nodeLabelHeight);
  }

  /// Amène le contenu au milieu de l'écran.
  void _centerOn(Size viewport) {
    if (!mounted) return;
    final center = _contentBounds.center;
    _transform.value = Matrix4.identity()
      ..translate(
        viewport.width / 2 - center.dx,
        viewport.height / 2 - center.dy,
      );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) => _showMessage(friendlyErrorMessage(error));

  /// Exécute une écriture du MJ, puis relit la carte.
  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _showError(e);
      return false;
    }
    await _load();
    return true;
  }

  // ---------- Déplacement des ronds ----------

  void _onNodeDrag(String id, Offset delta) {
    final scale = _transform.value.getMaxScaleOnAxis();
    setState(() {
      _dragging = id;
      _positions[id] = (_positions[id] ?? Offset.zero) + delta / scale;
    });
  }

  Future<void> _onNodeDropped(String id) async {
    final position = _positions[id];
    setState(() => _dragging = null);
    if (position == null) return;

    final auth = context.read<AuthProvider>();
    try {
      await auth.updateRelationNode(
        nodeId: id,
        x: position.dx,
        y: position.dy,
      );
    } catch (e) {
      if (mounted) _showError(e);
      await _load();
    }
  }

  // ---------- Création et édition, réservées au MJ ----------

  Future<void> _createNode(Offset at) async {
    final created = await _askNode();
    if (created == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;
    await _mutate(() => auth.createRelationNode(
          campaignId: roomId,
          label: created.label,
          kind: created.kind,
          x: at.dx,
          y: at.dy,
        ));
  }

  /// La boîte possède son champ de saisie et le libère elle-même.
  ///
  /// Le libérer ici, à la fermeture, le retirerait pendant que la boîte
  /// s'efface encore : le champ se reconstruirait avec un contrôleur mort.
  Future<_NodeDraft?> _askNode({Map<String, dynamic>? existing}) {
    return showDialog<_NodeDraft>(
      context: context,
      builder: (ctx) => _NodeDialog(existing: existing),
    );
  }

  Future<void> _addFact(String nodeId) async {
    final content = await _askText(
      title: 'Nouvelle information',
      label: 'Information',
      hint: 'Ce que l\'on peut apprendre ici…',
      maxLines: 4,
    );
    if (content == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;
    final node = _nodeById(nodeId);
    final position = (node?['facts'] as List?)?.length ?? 0;

    await _mutate(() => auth.createRelationFact(
          campaignId: roomId,
          nodeId: nodeId,
          content: content,
          position: position,
        ));
  }

  Future<String?> _askText({
    required String title,
    required String label,
    String? initial,
    String? hint,
    int maxLines = 1,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(
        title: title,
        label: label,
        initial: initial,
        hint: hint,
        maxLines: maxLines,
      ),
    );
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String action = 'Supprimer',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Efface toute la carte, après confirmation.
  ///
  /// Les informations et les découvertes partent avec leur rond, par cascade
  /// en base : rien ne survit à un rond supprimé. La confirmation le dit
  /// clairement, parce que les découvertes des joueurs sont la seule chose
  /// qu'on ne peut pas reconstituer de mémoire.
  Future<void> _clearGraph() async {
    final sure = await _confirm(
      'Vider la carte ?',
      'Tous les ronds, leurs liens, leurs informations et les découvertes des '
          'joueurs seront effacés, ainsi que les catégories. Cette action est '
          'irréversible.',
      action: 'Vider',
    );
    if (!sure || !mounted) return;

    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;
    final done = await _mutate(() => auth.clearRelationGraph(roomId));
    // La carte est vide : la vue se recadre sur le rond « + ».
    if (done && mounted) setState(() => _needsCentering = true);
  }

  /// Ouvre la liste des joueurs pour dire qui a découvert cette information.
  ///
  /// Réutilise la boîte des destinataires : « tous les joueurs » y vaut
  /// `null`, ce qui correspond ici à une information connue de toute la table.
  Future<void> _editDiscoverers(Map<String, dynamic> fact) async {
    final discovered = [
      for (final id in (fact['discovered_by'] as List?) ?? const []) '$id',
    ];
    final everyone = _players.isNotEmpty &&
        _players.every((p) => discovered.contains(p['user_id']));

    final choice = await showAudienceDialog(
      context: context,
      members: _players,
      current: everyone ? null : discovered,
      title: 'Qui a découvert cette information ?',
      allowNobody: true,
    );
    if (choice == null || !mounted) return;

    final userIds = choice.visibleTo ??
        [for (final player in _players) player['user_id'] as String];

    final auth = context.read<AuthProvider>();
    await _mutate(() => auth.setFactDiscoverers(
          factId: fact['id'] as String,
          userIds: userIds,
        ));
  }

  Future<void> _linkFrom(String nodeId) async {
    final others = _nodes.where((n) => n['id'] != nodeId).toList();
    if (others.isEmpty) {
      // Ce n'est pas une erreur, seulement une carte encore trop petite.
      _showMessage('Ajoutez un deuxième rond pour pouvoir les relier.');
      return;
    }

    var target = others.first['id'] as String;
    String? category =
        _categories.isEmpty ? null : _categories.first['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Relier à',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                dropdownColor: _cardColor,
                value: target,
                items: [
                  for (final node in others)
                    DropdownMenuItem(
                      value: node['id'] as String,
                      child: Text(
                        node['label'] as String? ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
                onChanged: (value) => setDialog(() => target = value!),
              ),
              if (_categories.isNotEmpty)
                DropdownButton<String?>(
                  isExpanded: true,
                  dropdownColor: _cardColor,
                  value: category,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Sans catégorie',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    for (final item in _categories)
                      DropdownMenuItem(
                        value: item['id'] as String,
                        child: Text(
                          item['name'] as String? ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                  onChanged: (value) => setDialog(() => category = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Relier'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;
    await _mutate(() => auth.createRelationLink(
          campaignId: roomId,
          fromNodeId: nodeId,
          toNodeId: target,
          categoryId: category,
        ));
  }

  /// Change la catégorie d'un lien déjà posé : c'est par là que les couleurs
  /// créées par le MJ arrivent réellement sur la carte.
  Future<void> _changeLinkCategory(Map<String, dynamic> link) async {
    if (_categories.isEmpty) {
      _showMessage('Créez d\'abord une catégorie, avec l\'icône palette.');
      return;
    }

    final chosen = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'Catégorie du lien',
          style: TextStyle(color: Colors.white),
        ),
        children: [
          for (final category in _categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, category['id'] as String),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: Color((category['color'] as num).toInt()),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    category['name'] as String? ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text(
              'Sans catégorie',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    await _mutate(() => auth.updateRelationLink(
          linkId: link['id'] as String,
          categoryId: chosen.isEmpty ? null : chosen,
        ));
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Catégories de lien',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Une couleur par sorte de relation. Elle se pose ensuite sur '
                'un lien, depuis la fiche d\'un rond.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final category in _categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor: Color((category['color'] as num).toInt()),
                  ),
                  title: Text(
                    category['name'] as String? ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Supprimer la catégorie',
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      final done = await _mutate(() => auth
                          .deleteRelationCategory(category['id'] as String));
                      if (done && mounted) setSheet(() {});
                    },
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une catégorie'),
                onPressed: () async {
                  final name = await _askText(
                    title: 'Nouvelle catégorie',
                    label: 'Nom',
                    hint: 'Famille, conflit, dette…',
                  );
                  if (name == null || !mounted) return;

                  final auth = context.read<AuthProvider>();
                  final roomId = context.read<RoomProvider>().roomId;
                  final position = _categories.length;
                  final done = await _mutate(() => auth.createRelationCategory(
                        campaignId: roomId,
                        name: name,
                        color: _categoryPalette[
                            position % _categoryPalette.length],
                        position: position,
                      ));
                  if (done && mounted) setSheet(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Fiche d'un rond ----------

  Future<void> _openNode(String nodeId) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final node = _nodeById(nodeId);
          if (node == null) return const SizedBox.shrink();

          Future<void> refresh() async {
            await _load();
            if (mounted) setSheet(() {});
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: _buildNodeSheet(node, refresh),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNodeSheet(
    Map<String, dynamic> node,
    Future<void> Function() refresh,
  ) {
    final nodeId = node['id'] as String;
    final facts = [
      for (final fact in (node['facts'] as List?) ?? const [])
        Map<String, dynamic>.from(fact as Map),
    ];
    final connected = _links.where(
      (link) => link['from_node_id'] == nodeId || link['to_node_id'] == nodeId,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(_kindIcons[node['kind']] ?? Icons.circle_outlined,
                color: _primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node['label'] as String? ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isMj) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                tooltip: 'Renommer le rond',
                onPressed: () async {
                  final draft = await _askNode(existing: node);
                  if (draft == null || !mounted) return;
                  final auth = context.read<AuthProvider>();
                  await _mutate(() => auth.updateRelationNode(
                        nodeId: nodeId,
                        label: draft.label,
                        kind: draft.kind,
                      ));
                  await refresh();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Supprimer le rond',
                onPressed: () async {
                  final sure = await _confirm(
                    'Supprimer ce rond ?',
                    'Ses informations et ses liens partiront avec lui.',
                  );
                  if (!sure || !mounted) return;
                  final auth = context.read<AuthProvider>();
                  final done = await _mutate(
                    () => auth.deleteRelationNode(nodeId),
                  );
                  if (done && mounted) Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
        Text(
          _kindLabels[node['kind']] ?? '',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        // Les actions du MJ sont en tête : enfouies sous les informations,
        // elles restaient introuvables.
        if (_isMj) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Information'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: const BorderSide(color: _primaryColor),
                ),
                onPressed: () async {
                  await _addFact(nodeId);
                  await refresh();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.timeline, size: 18),
                label: const Text('Relier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () async {
                  await _linkFrom(nodeId);
                  await refresh();
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Informations (${node['discovered_count']}/${node['fact_count']})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (facts.isEmpty)
          const Text(
            'Rien à apprendre ici pour l\'instant.',
            style: TextStyle(color: Colors.white38),
          ),
        for (final fact in facts) _buildFact(fact, refresh),
        if (connected.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Liens',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          for (final link in connected) _buildLinkTile(link, nodeId, refresh),
        ],
      ],
    );
  }

  Widget _buildFact(
    Map<String, dynamic> fact,
    Future<void> Function() refresh,
  ) {
    final content = fact['content'] as String?;
    final discoveredBy = [
      for (final id in (fact['discovered_by'] as List?) ?? const []) '$id',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            content == null ? Icons.help_outline : Icons.check_circle_outline,
            size: 16,
            color: content == null ? _unknownColor : _primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // La base n'a pas envoyé le texte : il reste à découvrir.
                  content ?? '???',
                  style: TextStyle(
                    color: content == null ? _unknownColor : Colors.white,
                    height: 1.35,
                    letterSpacing: content == null ? 2 : null,
                  ),
                ),
                if (_isMj)
                  Text(
                    discoveredBy.isEmpty
                        ? 'Personne ne l\'a découverte'
                        : 'Découverte par ${discoveredBy.length} joueur'
                            '${discoveredBy.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_isMj) ...[
            IconButton(
              icon: const Icon(Icons.visibility_outlined,
                  color: Colors.white54, size: 20),
              tooltip: 'Qui a découvert cette information',
              onPressed: () async {
                await _editDiscoverers(fact);
                await refresh();
              },
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Supprimer cette information',
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                await _mutate(
                  () => auth.deleteRelationFact(fact['id'] as String),
                );
                await refresh();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkTile(
    Map<String, dynamic> link,
    String nodeId,
    Future<void> Function() refresh,
  ) {
    final otherId = link['from_node_id'] == nodeId
        ? link['to_node_id'] as String
        : link['from_node_id'] as String;
    final other = _nodeById(otherId);
    final category = _categoryById(link['category_id'] as String?);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: category == null
            ? Colors.white38
            : Color((category['color'] as num).toInt()),
      ),
      title: Text(
        other?['label'] as String? ?? 'Rond inconnu',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        category?['name'] as String? ?? 'Sans catégorie',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      trailing: _isMj
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.palette_outlined,
                      color: Colors.white54, size: 20),
                  tooltip: 'Changer la catégorie du lien',
                  onPressed: () async {
                    await _changeLinkCategory(link);
                    await refresh();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.link_off, color: Colors.red, size: 20),
                  tooltip: 'Retirer ce lien',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    await _mutate(
                      () => auth.deleteRelationLink(link['id'] as String),
                    );
                    await refresh();
                  },
                ),
              ],
            )
          : null,
    );
  }

  Map<String, dynamic>? _categoryById(String? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category['id'] == id) return category;
    }
    return null;
  }

  // ---------- Carte ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Relations'),
        backgroundColor: _bgColor,
        actions: [
          if (_isMj)
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Catégories de lien',
              onPressed: _manageCategories,
            ),
          if (_graph != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong_outlined),
              tooltip: 'Recentrer la carte',
              onPressed: () => setState(() => _needsCentering = true),
            ),
          if (_isMj)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: 'Vider la carte',
              onPressed: _clearGraph,
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_graph == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error == null
                ? 'Carte indisponible.'
                : friendlyErrorMessage(_error!),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _buildCanvas(),
              // Posé sur l'écran et non sur la carte : sur la carte, il se
              // retrouvait de travers, loin du regard.
              if (_nodes.isEmpty) _buildEmptyHint(),
            ],
          ),
        ),
        if (_categories.isNotEmpty) _buildLegend(),
      ],
    );
  }

  Widget _buildCanvas() {
    final size = _canvasSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_needsCentering) {
          _needsCentering = false;
          // Après la mise en page : la vue n'existe pas encore pendant la
          // construction.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _centerOn(constraints.biggest),
          );
        }

        return InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          minScale: 0.4,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(400),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                // Isolé dans sa propre couche : déplacer un rond ne fait
                // repeindre que les liens, pas toute la carte.
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: _LinksPainter(
                      links: _links,
                      positionOf: (id) {
                        final node = _nodeById(id);
                        return node == null ? null : _positionOf(node);
                      },
                      colorOf: (categoryId) {
                        final category = _categoryById(categoryId);
                        if (category == null) return Colors.white24;
                        return Color((category['color'] as num).toInt());
                      },
                      highlight: _filter,
                    ),
                  ),
                ),
                for (final node in _nodes) _buildNode(node),
                if (_isMj) _buildAddNode(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode(Map<String, dynamic> node) {
    final id = node['id'] as String;
    final position = _positionOf(node);
    final total = (node['fact_count'] as num?)?.toInt() ?? 0;
    final discovered = (node['discovered_count'] as num?)?.toInt() ?? 0;
    final remaining = total - discovered;

    final circle = Container(
      width: _nodeRadius * 2,
      height: _nodeRadius * 2,
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: remaining > 0 ? _unknownColor : _primaryColor,
          width: 2,
        ),
      ),
      child: Icon(
        _kindIcons[node['kind']] ?? Icons.circle_outlined,
        color: remaining > 0 ? _unknownColor : _primaryColor,
      ),
    );

    return Positioned(
      left: position.dx - _nodeRadius,
      top: position.dy - _nodeRadius,
      child: GestureDetector(
        onTap: () => _openNode(id),
        onPanUpdate: _isMj ? (details) => _onNodeDrag(id, details.delta) : null,
        onPanEnd: _isMj ? (_) => _onNodeDropped(id) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              button: true,
              label: '${node['label']}, $discovered information'
                  '${discovered > 1 ? 's' : ''} sur $total',
              excludeSemantics: true,
              child: Badge(
                isLabelVisible: total > 0,
                label: Text('$discovered/$total'),
                backgroundColor: remaining > 0 ? _unknownColor : _primaryColor,
                textColor: _bgColor,
                child: circle,
              ),
            ),
            SizedBox(
              width: _nodeRadius * 3,
              height: _nodeLabelHeight,
              child: Text(
                node['label'] as String? ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Le rond « + » : c'est par lui que le MJ agrandit sa carte.
  ///
  /// Sa place est celle fixée au dernier chargement, et ne bouge pas tant
  /// qu'on déplace un rond.
  Widget _buildAddNode() {
    return Positioned(
      left: _addSpot.dx - _nodeRadius,
      top: _addSpot.dy - _nodeRadius,
      child: Tooltip(
        message: 'Ajouter un rond',
        child: GestureDetector(
          onTap: () => _createNode(_addSpot),
          child: Container(
            width: _nodeRadius * 2,
            height: _nodeRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.add, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  /// Le texte d'accueil, posé en bas de l'écran et transparent aux touchers.
  ///
  /// Au milieu, il recouvrait le rond « + » et en avalait les touchers : un
  /// texte capte le doigt comme n'importe quel autre widget.
  Widget _buildEmptyHint() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: Text(
            _isMj
                ? 'Carte vide. Touchez le rond « + » pour poser votre premier personnage ou lieu.'
                : 'Le maître du jeu n\'a pas encore dessiné la carte des relations.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in _categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category['name'] as String? ?? ''),
                  avatar: CircleAvatar(
                    radius: 8,
                    backgroundColor: Color((category['color'] as num).toInt()),
                  ),
                  selected: _filter == category['id'],
                  onSelected: (selected) => setState(
                    () => _filter = selected ? category['id'] as String : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un rond en cours de création ou de renommage.
class _NodeDraft {
  final String label;
  final String kind;

  const _NodeDraft(this.label, this.kind);
}

/// Boîte de création ou de renommage d'un rond.
///
/// Elle possède son champ de saisie, et le libère quand elle disparaît. Le
/// libérer depuis l'appelant, à la fermeture, le retirerait pendant que la
/// boîte s'efface encore.
class _NodeDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _NodeDialog({this.existing});

  @override
  State<_NodeDialog> createState() => _NodeDialogState();
}

class _NodeDialogState extends State<_NodeDialog> {
  late final TextEditingController _controller;
  late String _kind;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.existing?['label'] as String? ?? '',
    );
    _kind = widget.existing?['kind'] as String? ?? 'person';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _cardColor,
      title: Text(
        widget.existing == null ? 'Nouveau rond' : 'Renommer le rond',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: _dialogField('Nom'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _kindLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    avatar: Icon(_kindIcons[entry.key], size: 16),
                    selected: _kind == entry.key,
                    onSelected: (_) => setState(() => _kind = entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final label = _controller.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(context, _NodeDraft(label, _kind));
          },
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

/// Boîte de saisie d'un texte, qui possède elle aussi son champ.
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String? initial;
  final String? hint;
  final int maxLines;

  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.hint,
    required this.maxLines,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _cardColor,
      title: Text(
        widget.title,
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: widget.maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: _dialogField(widget.label, hint: widget.hint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

/// Les liens entre les ronds.
///
/// Un simple trait par lien : le dessin reste léger même quand le MJ déplace
/// un rond, puisque cette couche est la seule à repeindre.
class _LinksPainter extends CustomPainter {
  final List<Map<String, dynamic>> links;
  final Offset? Function(String nodeId) positionOf;
  final Color Function(String? categoryId) colorOf;

  /// Catégorie mise en avant : les autres liens s'effacent.
  final String? highlight;

  _LinksPainter({
    required this.links,
    required this.positionOf,
    required this.colorOf,
    required this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final from = positionOf(link['from_node_id'] as String);
      final to = positionOf(link['to_node_id'] as String);
      if (from == null || to == null) continue;

      final categoryId = link['category_id'] as String?;
      final dimmed = highlight != null && highlight != categoryId;

      final paint = Paint()
        ..color = colorOf(categoryId).withValues(alpha: dimmed ? 0.15 : 0.9)
        ..strokeWidth = dimmed ? 1.5 : 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinksPainter old) =>
      old.links != links || old.highlight != highlight;
}
