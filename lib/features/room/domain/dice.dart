import 'dart:math';

/// Un jet de dés décrit en notation de jeu de rôle : `3d6+2` se lit
/// « trois dés à six faces, plus deux ».
class DiceNotation {
  /// Nombre de dés lancés.
  final int count;

  /// Nombre de faces de chaque dé.
  final int sides;

  /// Modificateur ajouté (ou retranché) au total des dés.
  final int modifier;

  const DiceNotation({
    required this.count,
    required this.sides,
    this.modifier = 0,
  });

  /// Dés usuels en jeu de rôle sur table.
  static const List<int> supportedSides = [4, 6, 8, 10, 12, 20, 100];

  /// Bornes volontairement basses : au-delà, la lecture du détail devient
  /// illisible et le jet n'a plus d'intérêt à la table.
  static const int maxCount = 20;
  static const int maxModifier = 100;

  bool get isValid =>
      count >= 1 &&
      count <= maxCount &&
      supportedSides.contains(sides) &&
      modifier.abs() <= maxModifier;

  /// Notation lisible : `3d6`, `1d20+5`, `2d8-1`.
  String get label {
    final base = '${count}d$sides';
    if (modifier == 0) return base;
    return modifier > 0 ? '$base+$modifier' : '$base$modifier';
  }

  DiceNotation copyWith({int? count, int? sides, int? modifier}) {
    return DiceNotation(
      count: count ?? this.count,
      sides: sides ?? this.sides,
      modifier: modifier ?? this.modifier,
    );
  }

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is DiceNotation &&
      other.count == count &&
      other.sides == sides &&
      other.modifier == modifier;

  @override
  int get hashCode => Object.hash(count, sides, modifier);
}

/// Résultat d'un jet : la notation demandée et la valeur de chaque dé.
class DiceRoll {
  final DiceNotation notation;

  /// Valeur de chaque dé, dans l'ordre du lancer.
  final List<int> results;

  final DateTime rolledAt;

  DiceRoll({
    required this.notation,
    required List<int> results,
    required this.rolledAt,
  }) : results = List.unmodifiable(results);

  /// Somme des dés, avant modificateur.
  int get subtotal => results.fold(0, (sum, value) => sum + value);

  /// Somme des dés, modificateur compris.
  int get total => subtotal + notation.modifier;

  /// Réussite critique : un unique d20 tombé sur 20. La convention ne
  /// s'applique qu'au d20 seul, comme à la table.
  bool get isCriticalSuccess =>
      notation.sides == 20 && results.length == 1 && results.first == 20;

  /// Échec critique : un unique d20 tombé sur 1.
  bool get isCriticalFailure =>
      notation.sides == 20 && results.length == 1 && results.first == 1;

  /// Détail affichable du jet : `4 + 2 + 6 (+2)`.
  String get detail {
    final dice = results.join(' + ');
    if (notation.modifier == 0) return dice;
    final sign = notation.modifier > 0 ? '+' : '−';
    return '$dice ($sign${notation.modifier.abs()})';
  }
}

/// Lance les dés.
///
/// La source d'aléa est injectable pour que les tests puissent vérifier des
/// résultats exacts plutôt que de se contenter d'un encadrement.
class DiceRoller {
  final Random _random;

  DiceRoller({Random? random}) : _random = random ?? Random();

  /// Lance [notation] et renvoie le détail du jet.
  ///
  /// Lève [ArgumentError] si la notation est hors des bornes acceptées :
  /// mieux vaut échouer ici que produire un jet dont personne ne peut
  /// vérifier le sens.
  DiceRoll roll(DiceNotation notation, {DateTime? at}) {
    if (!notation.isValid) {
      throw ArgumentError('Notation de dés invalide : ${notation.label}');
    }

    final results = List<int>.generate(
      notation.count,
      (_) => _random.nextInt(notation.sides) + 1,
    );

    return DiceRoll(
      notation: notation,
      results: results,
      rolledAt: at ?? DateTime.now(),
    );
  }
}
