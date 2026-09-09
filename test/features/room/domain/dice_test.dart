import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/domain/dice.dart';

/// Source d'aléa qui rend les valeurs demandées, dans l'ordre : permet de
/// vérifier des résultats exacts au lieu de se contenter d'un encadrement.
class _ScriptedRandom implements Random {
  final List<int> _values;
  int _index = 0;

  _ScriptedRandom(this._values);

  @override
  int nextInt(int max) {
    // Les valeurs sont fournies telles qu'elles apparaîtront sur le dé ;
    // DiceRoller ajoute 1 au tirage, on retranche donc ici.
    final value = _values[_index % _values.length] - 1;
    _index++;
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  group('DiceNotation', () {
    test('formate la notation avec et sans modificateur', () {
      expect(const DiceNotation(count: 3, sides: 6).label, '3d6');
      expect(const DiceNotation(count: 1, sides: 20, modifier: 5).label, '1d20+5');
      expect(const DiceNotation(count: 2, sides: 8, modifier: -1).label, '2d8-1');
    });

    test('accepte les dés usuels de jeu de rôle', () {
      for (final sides in DiceNotation.supportedSides) {
        expect(DiceNotation(count: 1, sides: sides).isValid, isTrue,
            reason: 'd$sides devrait être accepté');
      }
    });

    test('refuse un nombre de dés, un dé ou un modificateur hors bornes', () {
      expect(const DiceNotation(count: 0, sides: 6).isValid, isFalse);
      expect(const DiceNotation(count: 21, sides: 6).isValid, isFalse);
      expect(const DiceNotation(count: 1, sides: 7).isValid, isFalse);
      expect(const DiceNotation(count: 1, sides: 6, modifier: 101).isValid, isFalse);
      expect(const DiceNotation(count: 1, sides: 6, modifier: -101).isValid, isFalse);
    });

    test('copyWith ne modifie que le champ demandé', () {
      const base = DiceNotation(count: 2, sides: 6, modifier: 1);
      expect(base.copyWith(sides: 20), const DiceNotation(count: 2, sides: 20, modifier: 1));
      expect(base.copyWith(count: 5), const DiceNotation(count: 5, sides: 6, modifier: 1));
    });
  });

  group('DiceRoller', () {
    test('lance autant de dés que demandé et additionne le modificateur', () {
      final roller = DiceRoller(random: _ScriptedRandom([4, 2, 6]));

      final roll = roller.roll(const DiceNotation(count: 3, sides: 6, modifier: 2));

      expect(roll.results, [4, 2, 6]);
      expect(roll.subtotal, 12);
      expect(roll.total, 14);
      expect(roll.detail, '4 + 2 + 6 (+2)');
    });

    test('un modificateur négatif est retranché', () {
      final roller = DiceRoller(random: _ScriptedRandom([5]));

      final roll = roller.roll(const DiceNotation(count: 1, sides: 8, modifier: -3));

      expect(roll.total, 2);
      expect(roll.detail, '5 (−3)');
    });

    test('reste dans les faces du dé', () {
      final roller = DiceRoller();

      for (var i = 0; i < 200; i++) {
        final roll = roller.roll(const DiceNotation(count: 4, sides: 10));
        for (final value in roll.results) {
          expect(value, inInclusiveRange(1, 10));
        }
      }
    });

    test('refuse une notation invalide plutôt que de produire un jet ininterprétable', () {
      final roller = DiceRoller();

      expect(
        () => roller.roll(const DiceNotation(count: 0, sides: 6)),
        throwsArgumentError,
      );
    });

    test('un d20 seul tombé sur 20 est une réussite critique', () {
      final roll = DiceRoller(random: _ScriptedRandom([20]))
          .roll(const DiceNotation(count: 1, sides: 20));

      expect(roll.isCriticalSuccess, isTrue);
      expect(roll.isCriticalFailure, isFalse);
    });

    test('un d20 seul tombé sur 1 est un échec critique', () {
      final roll = DiceRoller(random: _ScriptedRandom([1]))
          .roll(const DiceNotation(count: 1, sides: 20));

      expect(roll.isCriticalFailure, isTrue);
      expect(roll.isCriticalSuccess, isFalse);
    });

    test('la convention de critique ne s\'applique ni aux autres dés ni aux jets multiples', () {
      final d6 = DiceRoller(random: _ScriptedRandom([6]))
          .roll(const DiceNotation(count: 1, sides: 6));
      expect(d6.isCriticalSuccess, isFalse);

      final deuxD20 = DiceRoller(random: _ScriptedRandom([20, 20]))
          .roll(const DiceNotation(count: 2, sides: 20));
      expect(deuxD20.isCriticalSuccess, isFalse);
    });

    test('le résultat est immuable une fois le jet effectué', () {
      final roll = DiceRoller(random: _ScriptedRandom([3]))
          .roll(const DiceNotation(count: 1, sides: 6));

      expect(() => roll.results.add(6), throwsUnsupportedError);
    });
  });
}
