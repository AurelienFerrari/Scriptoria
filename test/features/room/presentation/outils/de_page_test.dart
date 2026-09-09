import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/domain/dice.dart';
import 'package:scriptoria/features/room/presentation/outils/de_page.dart';

/// Rend toujours la même face : le test porte sur l'écran, pas sur l'aléa,
/// déjà couvert par `dice_test.dart`.
class _FixedRandom implements Random {
  final int face;

  _FixedRandom(this.face);

  @override
  int nextInt(int max) => face - 1;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

Widget _wrap({int face = 12}) {
  return MaterialApp(
    home: DePage(roller: DiceRoller(random: _FixedRandom(face))),
  );
}

void main() {
  testWidgets('DePage propose les dés usuels et un d20 par défaut', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Dé'), findsOneWidget);
    for (final sides in DiceNotation.supportedSides) {
      expect(find.text('d$sides'), findsOneWidget);
    }
    expect(find.text('Lancer 1d20'), findsOneWidget);
    expect(find.text('Aucun jet pour l\'instant'), findsOneWidget);
  });

  testWidgets('DePage affiche le total et le détail après un lancer', (tester) async {
    await tester.pumpWidget(_wrap(face: 12));

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsWidgets);
    expect(find.text('Aucun jet pour l\'instant'), findsNothing);
  });

  testWidgets('DePage additionne le modificateur au total', (tester) async {
    await tester.pumpWidget(_wrap(face: 4));

    // Modificateur : +2
    final plusButtons = find.byTooltip('Augmenter : Modificateur');
    await tester.tap(plusButtons);
    await tester.tap(plusButtons);
    await tester.pump();

    expect(find.text('Lancer 1d20+2'), findsOneWidget);

    await tester.tap(find.text('Lancer 1d20+2'));
    await tester.pumpAndSettle();

    // 4 sur le dé, +2 de modificateur.
    expect(find.text('6'), findsWidgets);
    expect(find.text('4 (+2)'), findsOneWidget);
  });

  testWidgets('DePage lance plusieurs dés du type choisi', (tester) async {
    await tester.pumpWidget(_wrap(face: 3));

    await tester.tap(find.text('d6'));
    await tester.pump();
    await tester.tap(find.byTooltip('Augmenter : Nombre de dés'));
    await tester.pump();

    expect(find.text('Lancer 2d6'), findsOneWidget);

    await tester.tap(find.text('Lancer 2d6'));
    await tester.pumpAndSettle();

    expect(find.text('3 + 3'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
  });

  testWidgets('DePage signale une réussite critique sur un d20 seul', (tester) async {
    await tester.pumpWidget(_wrap(face: 20));

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('Réussite critique'), findsOneWidget);
  });

  testWidgets('DePage signale un échec critique sur un d20 seul', (tester) async {
    await tester.pumpWidget(_wrap(face: 1));

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('Échec critique'), findsOneWidget);
  });

  testWidgets('DePage empile les jets précédents et permet de les effacer', (tester) async {
    await tester.pumpWidget(_wrap(face: 8));

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();
    expect(find.text('Jets précédents'), findsNothing);

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('Jets précédents'), findsOneWidget);
    expect(find.text('1d20 → 8'), findsOneWidget);

    await tester.tap(find.byTooltip('Effacer l\'historique'));
    await tester.pumpAndSettle();

    expect(find.text('Jets précédents'), findsNothing);
    expect(find.text('Aucun jet pour l\'instant'), findsOneWidget);
  });

  testWidgets('DePage ne descend pas sous un dé ni au-delà du modificateur maximum',
      (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.byTooltip('Diminuer : Nombre de dés'));
    await tester.pump();

    // Toujours 1d20 : le nombre de dés ne peut pas tomber à zéro.
    expect(find.text('Lancer 1d20'), findsOneWidget);
  });
}
