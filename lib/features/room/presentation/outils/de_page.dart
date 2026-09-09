import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../domain/dice.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);
const Color _successColor = Color(0xFF7BE38C);
const Color _failureColor = Color(0xFFE37B7B);

/// Lanceur de dés de la room.
///
/// Volontairement local : un jet ne transite pas par la base. Le partager
/// avec toute la table supposerait le temps réel, qui arrive plus tard ; en
/// attendant, l'outil reste utilisable hors ligne et sans latence.
class DePage extends StatefulWidget {
  /// Injectable pour que les tests vérifient des résultats exacts.
  final DiceRoller? roller;

  const DePage({Key? key, this.roller}) : super(key: key);

  @override
  State<DePage> createState() => _DePageState();
}

class _DePageState extends State<DePage> with SingleTickerProviderStateMixin {
  late final DiceRoller _roller = widget.roller ?? DiceRoller();

  DiceNotation _notation = const DiceNotation(count: 1, sides: 20);
  final List<DiceRoll> _history = [];

  // Créé dès l'initialisation, et non paresseusement : un `late final` ne
  // serait construit qu'au premier accès, c'est-à-dire dans `dispose()` si
  // aucun jet n'a eu lieu — or `vsync: this` y consulte un ancêtre déjà
  // désactivé.
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  DiceRoll? get _lastRoll => _history.isEmpty ? null : _history.first;

  void _roll() {
    setState(() {
      _history.insert(0, _roller.roll(_notation));
      // Le détail complet reste consultable, mais on borne l'historique :
      // au-delà, c'est du bruit, et la liste n'est pas persistée de toute façon.
      if (_history.length > 20) _history.removeLast();
    });
    _animation.forward(from: 0);

    final roll = _lastRoll!;
    // Le résultat change sans qu'aucun focus ne bouge : sans annonce
    // explicite, un lecteur d'écran ne dirait rien du jet.
    SemanticsService.announce(
      'Résultat du jet ${roll.notation.label} : ${roll.total}',
      Directionality.of(context),
    );
  }

  void _clearHistory() => setState(_history.clear);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dé'),
        backgroundColor: _bgColor,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Effacer l\'historique',
              onPressed: _clearHistory,
            ),
        ],
      ),
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSidesSelector(),
            const SizedBox(height: 24),
            _buildCountAndModifier(),
            const SizedBox(height: 24),
            _buildResult(),
            const SizedBox(height: 24),
            _buildRollButton(),
            if (_history.length > 1) ...[
              const SizedBox(height: 32),
              _buildHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de dé',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: DiceNotation.supportedSides.map((sides) {
            final selected = _notation.sides == sides;
            return ChoiceChip(
              label: Text('d$sides'),
              selected: selected,
              onSelected: (_) => setState(() {
                _notation = _notation.copyWith(sides: sides);
              }),
              backgroundColor: _cardColor,
              selectedColor: _primaryColor,
              labelStyle: TextStyle(
                color: selected ? _bgColor : Colors.white,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: selected ? _primaryColor : Colors.white24),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCountAndModifier() {
    return Row(
      children: [
        Expanded(
          child: _buildStepper(
            label: 'Nombre de dés',
            value: _notation.count,
            display: '${_notation.count}',
            onChanged: (delta) {
              final next = _notation.count + delta;
              if (next < 1 || next > DiceNotation.maxCount) return;
              setState(() => _notation = _notation.copyWith(count: next));
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStepper(
            label: 'Modificateur',
            value: _notation.modifier,
            display: _notation.modifier > 0 ? '+${_notation.modifier}' : '${_notation.modifier}',
            onChanged: (delta) {
              final next = _notation.modifier + delta;
              if (next.abs() > DiceNotation.maxModifier) return;
              setState(() => _notation = _notation.copyWith(modifier: next));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required String display,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: _primaryColor),
                tooltip: 'Diminuer : $label',
                onPressed: () => onChanged(-1),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: _primaryColor),
                tooltip: 'Augmenter : $label',
                onPressed: () => onChanged(1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final roll = _lastRoll;

    Color accent = _primaryColor;
    String? mention;
    if (roll != null && roll.isCriticalSuccess) {
      accent = _successColor;
      mention = 'Réussite critique';
    } else if (roll != null && roll.isCriticalFailure) {
      accent = _failureColor;
      mention = 'Échec critique';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(roll == null ? 0.2 : 0.6), width: 2),
      ),
      child: roll == null
          ? Column(
              children: [
                Text(
                  _notation.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aucun jet pour l\'instant',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ],
            )
          : ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(
                CurvedAnimation(parent: _animation, curve: Curves.easeOutBack),
              ),
              child: Column(
                children: [
                  Text(
                    roll.notation.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${roll.total}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    roll.detail,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  if (mention != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      mention,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRollButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.casino),
      label: Text('Lancer ${_notation.label}'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: _primaryColor,
        foregroundColor: _bgColor,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: _roll,
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jets précédents',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // Le premier élément est déjà mis en avant dans le bloc de résultat.
        ..._history.skip(1).map(
              (roll) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.casino_outlined, color: Colors.white38, size: 20),
                title: Text(
                  '${roll.notation.label} → ${roll.total}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Text(
                  roll.detail,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
      ],
    );
  }
}
