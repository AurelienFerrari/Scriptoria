import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/friendly_error.dart';
import '../audience_dialog.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Rédaction d'un évènement de la frise, réservée au MJ.
///
/// [event] vaut `null` pour une création ; [nextPosition] est alors la place à
/// prendre au bout de la frise.
class TimelineEventEditorPage extends StatefulWidget {
  final Map<String, dynamic>? event;
  final int nextPosition;

  const TimelineEventEditorPage({
    Key? key,
    this.event,
    this.nextPosition = 0,
  }) : super(key: key);

  @override
  State<TimelineEventEditorPage> createState() =>
      _TimelineEventEditorPageState();
}

class _TimelineEventEditorPageState extends State<TimelineEventEditorPage> {
  late final TextEditingController _dateController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  /// Suit la convention de `room_timeline_events.visible_to` : `null` pour
  /// toute la table, liste vide pour personne.
  ///
  /// Un évènement créé ici est donc visible de tous par défaut : la frise
  /// raconte d'abord ce que les joueurs ont vécu. Le MJ restreint ensuite ce
  /// qu'il prépare à l'avance.
  List<String>? _visibleTo;
  List<Map<String, dynamic>> _players = const [];
  bool _isSaving = false;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _dateController =
        TextEditingController(text: event?['date_label'] as String? ?? '');
    _titleController =
        TextEditingController(text: event?['title'] as String? ?? '');
    _descriptionController =
        TextEditingController(text: event?['description'] as String? ?? '');

    final raw = event?['visible_to'] as List?;
    _visibleTo = raw?.cast<String>().toList();

    _loadPlayers();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final room = context.read<RoomProvider>();
    final members =
        await context.read<AuthProvider>().getCampaignMembers(room.roomId);
    if (!mounted) return;
    setState(() {
      // Le MJ voit toujours toute sa frise : le faire figurer dans la liste
      // laisserait croire qu'il peut s'en exclure.
      _players = members.where((member) => member['role'] != 'mj').toList();
    });
  }

  Future<void> _chooseAudience() async {
    final choice = await showAudienceDialog(
      context: context,
      members: _players,
      current: _visibleTo,
      title: 'Qui peut voir cet évènement ?',
      // « Personne » a du sens ici, contrairement à une annonce : un évènement
      // se prépare souvent plusieurs séances avant d'être révélé.
      allowNobody: true,
    );

    if (choice == null || !mounted) return;
    setState(() => _visibleTo = choice.visibleTo);
  }

  String get _audienceLabel {
    final visibleTo = _visibleTo;
    if (visibleTo == null) return 'Toute la table';
    if (visibleTo.isEmpty) return 'Vous seul, pour l\'instant';
    return '${visibleTo.length} joueur${visibleTo.length > 1 ? 's' : ''}';
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un titre à l\'évènement.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final room = context.read<RoomProvider>();
    final authorId = auth.currentUser?.id;
    if (authorId == null) return;

    setState(() => _isSaving = true);
    try {
      if (_isNew) {
        await auth.createTimelineEvent(
          campaignId: room.roomId,
          authorId: authorId,
          title: title,
          dateLabel: _dateController.text.trim(),
          description: _descriptionController.text.trim(),
          position: widget.nextPosition,
          visibleTo: _visibleTo,
        );
      } else {
        await auth.updateTimelineEvent(
          eventId: widget.event!['id'] as String,
          title: title,
          dateLabel: _dateController.text.trim(),
          description: _descriptionController.text.trim(),
          visibleTo: _visibleTo,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    // `true` signale à la frise appelante qu'elle doit se recharger.
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: Text(_isNew ? 'Nouvel évènement' : 'Modifier l\'évènement'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _dateController,
                label: 'Repère temporel',
                hint: 'Ex. : an 1247, au printemps',
              ),
              const SizedBox(height: 8),
              const Text(
                'Texte libre : votre monde n\'a pas à suivre notre calendrier.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _field(
                controller: _titleController,
                label: 'Titre',
                hint: 'Ex. : la chute de Valmorne',
              ),
              const SizedBox(height: 20),
              _field(
                controller: _descriptionController,
                label: 'Récit',
                hint: 'Ce qui s\'est passé…',
                maxLines: 6,
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_outlined, color: _primaryColor),
                title: const Text(
                  'Qui peut le voir',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _audienceLabel,
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: _chooseAudience,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, height: 1.4),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
