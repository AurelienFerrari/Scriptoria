import 'package:flutter/material.dart';

const Color _primaryColor = Color(0xFF6FE3E1);
const Color _closedColor = Color(0xFFE3C77B);
const Color _bgColor = Color(0xFF161622);

/// Sondage affiché dans le chat.
///
/// Cette carte n'affiche que ce que la base renvoie. Les compteurs n'arrivent
/// que si la fonction `get_room_polls` accepte de les révéler — après un vote,
/// ou une fois le sondage clos. Tant qu'ils valent `null`, la carte n'a rien à
/// montrer, et ne peut donc rien laisser deviner.
class RoomPollCard extends StatefulWidget {
  final String question;

  /// Le sondage tel que renvoyé par `get_room_polls`, ou `null` tant qu'il se
  /// charge.
  final Map<String, dynamic>? poll;

  /// L'auteur du sondage et le MJ peuvent le clore.
  final bool canClose;

  /// Enregistre un vote ; renvoie `false` s'il a échoué, pour que la carte
  /// garde la sélection en cours.
  final Future<bool> Function(List<String> optionIds) onVote;

  final VoidCallback onClose;

  const RoomPollCard({
    super.key,
    required this.question,
    required this.poll,
    required this.canClose,
    required this.onVote,
    required this.onClose,
  });

  @override
  State<RoomPollCard> createState() => _RoomPollCardState();
}

class _RoomPollCardState extends State<RoomPollCard> {
  Set<String> _selected = {};

  /// Vrai quand l'utilisateur revient sur un vote déjà donné.
  bool _editing = false;
  bool _sending = false;

  Map<String, dynamic>? get _poll => widget.poll;
  bool get _multiple => _poll?['multiple'] as bool? ?? false;
  bool get _closed => _poll?['closed'] as bool? ?? false;
  bool get _revealed => _poll?['revealed'] as bool? ?? false;
  int get _totalVoters => (_poll?['total_voters'] as num?)?.toInt() ?? 0;

  List<String> get _myVotes => [
        for (final id in (_poll?['my_votes'] as List?) ?? const []) '$id',
      ];

  List<Map<String, dynamic>> get _options => [
        for (final option in (_poll?['options'] as List?) ?? const [])
          Map<String, dynamic>.from(option as Map),
      ];

  @override
  void didUpdateWidget(covariant RoomPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un sondage clos pendant qu'on modifiait son vote n'accepte plus rien.
    if (_closed && _editing) _editing = false;
  }

  void _toggle(String optionId) {
    setState(() {
      if (!_multiple) {
        _selected = {optionId};
      } else if (!_selected.remove(optionId)) {
        _selected.add(optionId);
      }
    });
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _selected = _myVotes.toSet();
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _sending) return;
    // Dans l'ordre d'affichage des réponses, pas dans l'ordre des clics.
    final optionIds = [
      for (final option in _options)
        if (_selected.contains('${option['id']}')) '${option['id']}',
    ];

    setState(() => _sending = true);
    final succeeded = await widget.onVote(optionIds);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (succeeded) _editing = false;
    });
  }

  String get _votersLabel =>
      _totalVoters > 1 ? '$_totalVoters votants' : '$_totalVoters votant';

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    final accent = _closed ? _closedColor : _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.poll_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              _closed ? 'Sondage clos' : 'Sondage',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (poll == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else
          ..._buildBody(),
      ],
    );
  }

  List<Widget> _buildBody() {
    final showResults = _revealed && !_editing;
    final canVote = !_closed && (!_revealed || _editing);

    return [
      const SizedBox(height: 2),
      Text(
        '${_multiple ? 'Plusieurs réponses possibles' : 'Une seule réponse'}'
        ' · $_votersLabel',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (showResults)
        for (final option in _options) _buildResult(option)
      else
        for (final option in _options) _buildChoice(option, canVote),
      const SizedBox(height: 4),
      _buildActions(showResults: showResults, canVote: canVote),
    ];
  }

  Widget _buildChoice(Map<String, dynamic> option, bool enabled) {
    final id = '${option['id']}';
    final label = Text(
      option['label'] as String? ?? '',
      style: const TextStyle(color: Colors.white),
    );
    final onChanged = enabled && !_sending ? (_) => _toggle(id) : null;

    if (_multiple) {
      return CheckboxListTile(
        value: _selected.contains(id),
        onChanged: onChanged,
        title: label,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _primaryColor,
        checkColor: _bgColor,
      );
    }

    return RadioListTile<String>(
      value: id,
      groupValue: _selected.isEmpty ? null : _selected.first,
      onChanged: onChanged,
      title: label,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: _primaryColor,
    );
  }

  Widget _buildResult(Map<String, dynamic> option) {
    final id = '${option['id']}';
    final votes = (option['votes'] as num?)?.toInt() ?? 0;
    final share = _totalVoters == 0 ? 0.0 : votes / _totalVoters;
    final mine = _myVotes.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (mine) ...[
                const Icon(Icons.check_circle, size: 14, color: _primaryColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  option['label'] as String? ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: mine ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(share * 100).round()} %',
                style: TextStyle(
                  color: mine ? _primaryColor : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: mine ? _primaryColor : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions({required bool showResults, required bool canVote}) {
    if (_closed) {
      return const Text(
        'Résultats définitifs',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (canVote)
          FilledButton(
            onPressed: _selected.isEmpty || _sending ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: _bgColor,
            ),
            child: Text(_editing ? 'Valider mon vote' : 'Voter'),
          ),
        if (_editing)
          TextButton(
            onPressed: () => setState(() => _editing = false),
            child: const Text('Annuler'),
          ),
        if (showResults)
          TextButton(
            onPressed: _startEditing,
            child: const Text('Modifier mon vote'),
          ),
        if (widget.canClose && !_editing)
          TextButton(
            onPressed: widget.onClose,
            style: TextButton.styleFrom(foregroundColor: _closedColor),
            child: const Text('Clore le sondage'),
          ),
      ],
    );
  }
}
