import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/services/row_change.dart';
import '../../../core/utils/format_relative_age.dart';
import '../../../core/utils/friendly_error.dart';
import 'audience_dialog.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);
const Color _mineColor = Color(0xFF1E3A40);
const Color _whisperColor = Color(0xFFE3C77B);

/// Longueur maximale d'un message, alignée sur la contrainte
/// `room_messages_body_length` de la base.
const int _maxLength = 2000;

/// Chat de la room : enregistré, partagé avec la table, reçu en temps réel.
///
/// Il ne vivait auparavant qu'en mémoire, avec trois messages codés en dur :
/// rien n'était enregistré, ni partagé.
///
/// Ce que chacun y lit est décidé par la base. Un chuchotement du MJ ne
/// remonte, par requête comme par le temps réel, qu'à ses destinataires : cet
/// écran ne filtre rien lui-même.
class RoomChatPage extends StatefulWidget {
  const RoomChatPage({Key? key}) : super(key: key);

  @override
  State<RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends State<RoomChatPage> {
  final TextEditingController _controller = TextEditingController();

  /// Du plus ancien au plus récent.
  List<Map<String, dynamic>> _messages = const [];

  /// Annuaire de la room, pour nommer auteurs et destinataires.
  Map<String, Map<String, dynamic>> _membersById = const {};

  /// Destinataires du prochain message : `null` pour toute la table.
  ///
  /// Le choix reste en place d'un message à l'autre : un échange secret tient
  /// rarement en une ligne. Le bandeau au-dessus de la saisie le rappelle.
  List<String>? _whisperTo;

  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription<RowChange>? _changes;

  @override
  void initState() {
    super.initState();
    _load();
    final room = context.read<RoomProvider>();
    _changes = context
        .read<AuthProvider>()
        .watchRoomTable('room_messages', room.roomId)
        .listen(_onChange);
  }

  @override
  void dispose() {
    _changes?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final roomId = context.read<RoomProvider>().roomId;
    final results = await Future.wait([
      auth.getRoomMessages(roomId),
      auth.getCampaignMembers(roomId),
    ]);
    if (!mounted) return;
    setState(() {
      _messages = results[0];
      _membersById = {
        for (final member in results[1]) member['user_id'] as String: member,
      };
      _isLoading = false;
    });
  }

  void _onChange(RowChange change) {
    switch (change.kind) {
      case RowChangeKind.inserted:
        _append(change.record);
      case RowChangeKind.deleted:
        _remove(change.record['id']);
      case RowChangeKind.resubscribed:
        // Realtime ne rejoue pas ce qui s'est dit pendant une coupure.
        _load();
    }
  }

  void _append(Map<String, dynamic> message) {
    // Un message envoyé depuis cet appareil arrive deux fois : par la réponse
    // à l'insertion, puis par le temps réel.
    if (_messages.any((m) => m['id'] == message['id'])) return;
    setState(() {
      _messages = [..._messages, message];
    });

    // Un joueur arrivé depuis l'ouverture du chat n'est pas dans l'annuaire.
    final authorId = message['author_id'];
    if (authorId is String && !_membersById.containsKey(authorId)) _load();
  }

  void _remove(Object? id) {
    // Les suppressions ne sont pas filtrées par room : un id inconnu vient
    // d'une autre room, et n'a rien à faire ici.
    if (!_messages.any((m) => m['id'] == id)) return;
    setState(() {
      _messages = _messages.where((m) => m['id'] != id).toList();
    });
  }

  String _nameOf(String? userId) {
    final member = _membersById[userId];
    if (member == null) return 'Ancien membre';

    final displayName = member['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName;

    final username = member['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username;

    return 'Utilisateur sans profil';
  }

  String _namesOf(List<String> ids) => ids.map(_nameOf).join(', ');

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _isSending) return;

    final auth = context.read<AuthProvider>();
    final room = context.read<RoomProvider>();
    final authorId = auth.currentUser?.id;
    if (authorId == null) return;

    setState(() => _isSending = true);
    try {
      final message = await auth.createRoomMessage(
        campaignId: room.roomId,
        authorId: authorId,
        body: body,
        visibleTo: _whisperTo,
      );
      if (!mounted) return;
      _controller.clear();
      _append(message);
    } catch (e) {
      // Le texte reste dans la saisie : un échec ne doit rien faire perdre.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _chooseWhisper() async {
    // Le MJ reçoit toujours ce qu'il écrit : l'inscrire dans la liste
    // laisserait croire qu'il peut s'en exclure.
    final players =
        _membersById.values.where((member) => member['role'] != 'mj').toList();

    final choice = await showAudienceDialog(
      context: context,
      members: players,
      current: _whisperTo,
      title: 'À qui chuchoter ?',
      // « Personne » n'a pas de sens pour un message : on chuchote à
      // quelqu'un, ou on parle à toute la table.
      allowNobody: false,
    );
    if (choice == null || !mounted) return;

    final visibleTo = choice.visibleTo;
    if (visibleTo != null && visibleTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez au moins un joueur.')),
      );
      return;
    }
    setState(() => _whisperTo = visibleTo);
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text('Il disparaîtra pour toute la table.'),
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
          .deleteRoomMessage(message['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }
    if (mounted) _remove(message['id']);
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('Chat de la room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(room.isMj, currentUserId)),
          if (_whisperTo != null) _buildWhisperBanner(),
          _buildComposer(room.isMj),
        ],
      ),
    );
  }

  Widget _buildMessages(bool isMj, String? currentUserId) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun message pour l\'instant.\nLancez la conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.builder(
      // Inversée : la liste reste calée sur le dernier message quand un
      // nouveau arrive, comme dans toute messagerie.
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessage(
        _messages[_messages.length - 1 - index],
        isMj,
        currentUserId,
      ),
    );
  }

  Widget _buildMessage(
    Map<String, dynamic> message,
    bool isMj,
    String? currentUserId,
  ) {
    final authorId = message['author_id'] as String?;
    final isMine = authorId == currentUserId;
    final visibleTo = (message['visible_to'] as List?)?.cast<String>();
    final body = message['body'] as String? ?? '';

    String? whisperLabel;
    if (visibleTo != null) {
      whisperLabel = !isMine && visibleTo.contains(currentUserId)
          ? 'Chuchoté pour vous'
          : 'Chuchoté à ${_namesOf(visibleTo)}';
    }

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? _mineColor : _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: visibleTo != null
            ? Border.all(color: _whisperColor.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Text(
              _nameOf(authorId),
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (whisperLabel != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: _whisperColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    whisperLabel,
                    style: const TextStyle(color: _whisperColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          Text(body, style: const TextStyle(color: Colors.white, height: 1.35)),
          const SizedBox(height: 2),
          Text(
            formatRelativeAge(message['created_at'] as String?),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );

    // L'auteur retire ses messages, le MJ ceux de tout le monde — la même
    // règle que la policy `room_messages_delete_author_or_mj`.
    final canDelete = isMine || isMj;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: canDelete
          ? Semantics(
              onLongPressHint: 'supprimer le message',
              child: GestureDetector(
                onLongPress: () => _confirmAndDelete(message),
                child: bubble,
              ),
            )
          : bubble,
    );
  }

  Widget _buildWhisperBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      alignment: Alignment.centerLeft,
      child: InputChip(
        avatar: const Icon(Icons.lock_outline, size: 16, color: _whisperColor),
        label: Text(
          'Chuchotement à ${_namesOf(_whisperTo!)}',
          overflow: TextOverflow.ellipsis,
        ),
        labelStyle: const TextStyle(color: _whisperColor),
        backgroundColor: _cardColor,
        deleteIconColor: _whisperColor,
        deleteButtonTooltipMessage: 'Parler à toute la table',
        onDeleted: () => setState(() => _whisperTo = null),
      ),
    );
  }

  Widget _buildComposer(bool isMj) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          if (isMj)
            IconButton(
              icon: Icon(
                _whisperTo == null
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
                color: _whisperTo == null ? Colors.white54 : _whisperColor,
              ),
              tooltip: 'Chuchoter à des joueurs',
              onPressed: _chooseWhisper,
            ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              inputFormatters: [LengthLimitingTextInputFormatter(_maxLength)],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    _whisperTo == null ? 'Écrire à la table…' : 'Chuchoter…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: _cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: _primaryColor),
            tooltip: 'Envoyer le message',
            onPressed: _isSending ? null : _send,
          ),
        ],
      ),
    );
  }
}
