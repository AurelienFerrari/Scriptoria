import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/room_poll_card.dart';

/// Sondage tel que le renvoie `get_room_polls`.
///
/// [votes] vaut `null` tant que la base n'a pas révélé les compteurs.
Map<String, dynamic> _poll({
  bool multiple = false,
  bool closed = false,
  bool revealed = false,
  List<String> myVotes = const [],
  int totalVoters = 0,
  List<int>? votes,
}) =>
    {
      'poll_id': 'poll-1',
      'message_id': 'message-p',
      'multiple': multiple,
      'closed': closed,
      'revealed': revealed,
      'total_voters': totalVoters,
      'my_votes': myVotes,
      'options': [
        {'id': 'opt-1', 'label': 'La forêt', 'position': 0, 'votes': votes?[0]},
        {'id': 'opt-2', 'label': 'La mine', 'position': 1, 'votes': votes?[1]},
        {'id': 'opt-3', 'label': 'Le port', 'position': 2, 'votes': votes?[2]},
      ],
    };

void main() {
  late List<List<String>> votesSent;
  late int closeRequests;
  late bool voteSucceeds;

  setUp(() {
    votesSent = [];
    closeRequests = 0;
    voteSucceeds = true;
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Map<String, dynamic>? poll, {
    bool canClose = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoomPollCard(
              question: 'Où allons-nous ?',
              poll: poll,
              canClose: canClose,
              onVote: (optionIds) async {
                votesSent.add(optionIds);
                return voteSucceeds;
              },
              onClose: () => closeRequests++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  FilledButton voteButton(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  testWidgets('annonce le chargement du sondage', (tester) async {
    await pumpCard(tester, null);

    expect(find.text('Où allons-nous ?'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('fait voter avant de montrer le moindre résultat',
      (tester) async {
    await pumpCard(tester, _poll(totalVoters: 4));

    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
    expect(find.text('Une seule réponse · 4 votants'), findsOneWidget);
    // Rien ne laisse deviner les résultats : la base ne les a pas envoyés.
    expect(find.textContaining('%'), findsNothing);
    expect(voteButton(tester, 'Voter').onPressed, isNull);
  });

  testWidgets('vote pour une seule réponse', (tester) async {
    await pumpCard(tester, _poll());

    await tester.tap(find.text('La forêt'));
    await tester.tap(find.text('La mine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Voter'));
    await tester.pump();

    // Le choix unique ne garde que la dernière réponse touchée.
    expect(votesSent, [
      ['opt-2'],
    ]);
  });

  testWidgets('coche plusieurs réponses quand le sondage le permet',
      (tester) async {
    await pumpCard(tester, _poll(multiple: true));

    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.textContaining('Plusieurs réponses possibles'), findsOneWidget);

    await tester.tap(find.text('Le port'));
    await tester.tap(find.text('La forêt'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Voter'));
    await tester.pump();

    // Dans l'ordre d'affichage, pas dans celui des clics.
    expect(votesSent, [
      ['opt-1', 'opt-3'],
    ]);
  });

  testWidgets('montre les pourcentages une fois voté', (tester) async {
    await pumpCard(
      tester,
      _poll(
        revealed: true,
        myVotes: ['opt-1'],
        totalVoters: 3,
        votes: [2, 1, 0],
      ),
    );

    expect(find.text('67 %'), findsOneWidget);
    expect(find.text('33 %'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);
    // Sa propre réponse est signalée.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Modifier mon vote'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Voter'), findsNothing);
  });

  testWidgets('change son vote tant que le sondage est ouvert',
      (tester) async {
    await pumpCard(
      tester,
      _poll(
        revealed: true,
        myVotes: ['opt-1'],
        totalVoters: 3,
        votes: [2, 1, 0],
      ),
    );

    await tester.tap(find.text('Modifier mon vote'));
    await tester.pump();

    // Le vote précédent est présélectionné.
    final previous = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'La forêt'),
    );
    expect(previous.groupValue, 'opt-1');

    await tester.tap(find.text('La mine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Valider mon vote'));
    await tester.pump();

    expect(votesSent, [
      ['opt-2'],
    ]);
  });

  testWidgets('renonce à changer son vote', (tester) async {
    await pumpCard(
      tester,
      _poll(revealed: true, myVotes: ['opt-1'], totalVoters: 1, votes: [1, 0, 0]),
    );

    await tester.tap(find.text('Modifier mon vote'));
    await tester.pump();
    await tester.tap(find.text('Annuler'));
    await tester.pump();

    expect(find.text('100 %'), findsOneWidget);
    expect(votesSent, isEmpty);
  });

  testWidgets('garde la sélection si le vote échoue', (tester) async {
    voteSucceeds = false;
    await pumpCard(
      tester,
      _poll(revealed: true, myVotes: ['opt-1'], totalVoters: 1, votes: [1, 0, 0]),
    );

    await tester.tap(find.text('Modifier mon vote'));
    await tester.pump();
    await tester.tap(find.text('Le port'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Valider mon vote'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Valider mon vote'), findsOneWidget);
  });

  testWidgets('un sondage clos montre ses résultats à tous, sans vote possible',
      (tester) async {
    // Clos, le sondage révèle ses résultats même à qui n'a pas voté.
    await pumpCard(
      tester,
      _poll(closed: true, revealed: true, totalVoters: 2, votes: [1, 1, 0]),
      canClose: true,
    );

    expect(find.text('Sondage clos'), findsOneWidget);
    expect(find.text('50 %'), findsNWidgets(2));
    expect(find.text('Résultats définitifs'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Voter'), findsNothing);
    expect(find.text('Modifier mon vote'), findsNothing);
    expect(find.text('Clore le sondage'), findsNothing);
  });

  testWidgets('seuls l\'auteur et le MJ ont de quoi clore le sondage',
      (tester) async {
    await pumpCard(tester, _poll());
    expect(find.text('Clore le sondage'), findsNothing);

    await pumpCard(tester, _poll(), canClose: true);
    await tester.tap(find.text('Clore le sondage'));
    await tester.pump();

    expect(closeRequests, 1);
  });
}
