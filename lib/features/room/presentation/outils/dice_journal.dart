import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/format_relative_age.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../domain/dice.dart';

/// Journal des jets de la room.
///
/// Ce que chacun y voit est décidé par la base : les jets ordinaires sont
/// visibles de tous les membres, ceux marqués secrets ne remontent qu'au MJ.
/// Cet écran ne filtre rien lui-même, il affiche ce que la requête renvoie.
class DiceJournal extends StatefulWidget {
  /// Change de valeur à chaque jet enregistré, ce qui déclenche un
  /// rechargement sans que le lanceur ait à connaître l'état de ce widget.
  final ValueNotifier<int> revision;

  const DiceJournal({Key? key, required this.revision}) : super(key: key);

  @override
  State<DiceJournal> createState() => _DiceJournalState();
}

class _DiceJournalState extends State<DiceJournal> {
  late Future<List<Map<String, dynamic>>> _rollsFuture;

  @override
  void initState() {
    super.initState();
    _rollsFuture = _loadRolls();
    widget.revision.addListener(_reload);
  }

  @override
  void dispose() {
    widget.revision.removeListener(_reload);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadRolls() {
    final room = context.read<RoomProvider>();
    return context.read<AuthProvider>().getDiceRolls(room.roomId);
  }

  void _reload() {
    if (!mounted) return;
    // Corps en bloc : `setState(() => x = future)` renverrait le Future, que
    // setState refuse.
    setState(() {
      _rollsFuture = _loadRolls();
    });
  }

  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le journal ?'),
        content: const Text(
          'Tous les jets de cette room seront effacés, y compris ceux des '
          'joueurs. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final room = context.read<RoomProvider>();
    try {
      await context.read<AuthProvider>().clearDiceRolls(room.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    if (mounted) _reload();
  }

  /// Reconstruit le jet à partir des colonnes brutes.
  ///
  /// Le total et la notation ne sont pas stockés : les recalculer ici garantit
  /// que le détail affiché et la somme annoncée viennent du même code, celui
  /// du domaine, déjà couvert par ses propres tests.
  DiceRoll _rollFrom(Map<String, dynamic> row) {
    return DiceRoll(
      notation: DiceNotation(
        count: row['dice_count'] as int,
        sides: row['sides'] as int,
        modifier: row['modifier'] as int? ?? 0,
      ),
      results: (row['results'] as List<dynamic>).cast<int>(),
      rolledAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String _authorOf(Map<String, dynamic> row, String? currentUserId) {
    if (row['user_id'] == currentUserId) return 'Vous';

    final displayName = row['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName;

    final username = row['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username;

    return 'Utilisateur sans profil';
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _rollsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final rolls = snapshot.data ?? const [];

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (room.isMj && rolls.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    label: const Text('Vider le journal'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: _confirmAndClear,
                  ),
                ),
              if (rolls.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'Aucun jet pour l\'instant.\nTirez vers le bas pour rafraîchir.',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...rolls.map((row) => _buildRollTile(row, currentUserId)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRollTile(Map<String, dynamic> row, String? currentUserId) {
    final roll = _rollFrom(row);
    final isSecret = row['is_secret'] as bool? ?? false;

    Color accent = Colors.white;
    if (roll.isCriticalSuccess) {
      accent = const Color(0xFF7BE38C);
    } else if (roll.isCriticalFailure) {
      accent = const Color(0xFFE37B7B);
    }

    return Card(
      color: const Color(0xFF232336),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF161622),
          child: Text(
            '${roll.total}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: roll.total.abs() >= 100 ? 13 : 16,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                '${_authorOf(row, currentUserId)} · ${roll.notation.label}',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSecret) ...[
              const SizedBox(width: 8),
              const Icon(Icons.lock_outline, size: 16, color: Color(0xFFE3C77B)),
            ],
          ],
        ),
        subtitle: Text(
          '${roll.detail} · ${formatRelativeAge(row['created_at'] as String?)}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ),
    );
  }
}
