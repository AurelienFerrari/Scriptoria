import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/room_poll_composer_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/room_harness.dart';

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    when(() => service.createRoomPoll(
          campaignId: any(named: 'campaignId'),
          question: any(named: 'question'),
          options: any(named: 'options'),
          multiple: any(named: 'multiple'),
        )).thenAnswer(
      (_) async => {
        'id': 'message-p',
        'campaign_id': kRoomId,
        'author_id': kPlayerId,
        'body': 'Où allons-nous ?',
        'kind': 'poll',
      },
    );
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: kPlayerId,
      role: 'player',
    );
    await tester.pumpWidget(
      wrapRoomScreen(
        auth: auth,
        room: room,
        child: const RoomPollComposerPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> launch(WidgetTester tester) async {
    await tester.tap(find.text('Lancer le sondage'));
    await tester.pumpAndSettle();
  }

  void expectNothingLaunched() {
    verifyNever(() => service.createRoomPoll(
          campaignId: any(named: 'campaignId'),
          question: any(named: 'question'),
          options: any(named: 'options'),
          multiple: any(named: 'multiple'),
        ));
  }

  testWidgets('refuse un sondage sans question', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(field('Réponse 1'), 'La forêt');
    await tester.enterText(field('Réponse 2'), 'La mine');

    await launch(tester);

    expect(find.text('Posez une question.'), findsOneWidget);
    expectNothingLaunched();
  });

  testWidgets('refuse moins de deux réponses', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(field('Question'), 'Où allons-nous ?');
    await tester.enterText(field('Réponse 1'), 'La forêt');

    await launch(tester);

    expect(find.text('Proposez au moins deux réponses.'), findsOneWidget);
    expectNothingLaunched();
  });

  testWidgets('refuse deux réponses identiques', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(field('Question'), 'Où allons-nous ?');
    await tester.enterText(field('Réponse 1'), 'La forêt');
    await tester.enterText(field('Réponse 2'), '  la FORÊT ');

    await launch(tester);

    expect(find.text('Deux réponses sont identiques.'), findsOneWidget);
    expectNothingLaunched();
  });

  testWidgets('ajoute puis retire une réponse', (tester) async {
    await pumpComposer(tester);

    // Deux réponses au minimum : on ne peut pas les retirer.
    expect(find.byTooltip('Retirer la réponse 1'), findsNothing);

    await tester.tap(find.text('Ajouter une réponse'));
    await tester.pumpAndSettle();
    expect(field('Réponse 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer la réponse 3'));
    await tester.pumpAndSettle();
    expect(field('Réponse 3'), findsNothing);
  });

  testWidgets('ne propose pas plus de dix réponses', (tester) async {
    await pumpComposer(tester);

    for (var i = 0; i < 8; i++) {
      await tester.ensureVisible(find.text('Ajouter une réponse'));
      await tester.tap(find.text('Ajouter une réponse'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Ajouter une réponse'), findsNothing);
    // Chaque champ de saisie a son propre défilement : on désigne celui de
    // la liste, le premier de l'arbre.
    await tester.scrollUntilVisible(
      field('Réponse 10'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(field('Réponse 10'), findsOneWidget);
  });

  testWidgets('lance un sondage à choix multiple', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(field('Question'), '  Où allons-nous ?  ');
    await tester.enterText(field('Réponse 1'), 'La forêt');
    await tester.enterText(field('Réponse 2'), 'La mine');
    await tester.tap(find.text('Plusieurs réponses possibles'));
    await tester.pumpAndSettle();

    await launch(tester);

    verify(() => service.createRoomPoll(
          campaignId: kRoomId,
          question: 'Où allons-nous ?',
          options: ['La forêt', 'La mine'],
          multiple: true,
        )).called(1);
  });

  testWidgets('ignore une réponse laissée vide', (tester) async {
    await pumpComposer(tester);
    await tester.tap(find.text('Ajouter une réponse'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Question'), 'Où allons-nous ?');
    await tester.enterText(field('Réponse 1'), 'La forêt');
    await tester.enterText(field('Réponse 3'), 'Le port');

    await launch(tester);

    verify(() => service.createRoomPoll(
          campaignId: kRoomId,
          question: 'Où allons-nous ?',
          options: ['La forêt', 'Le port'],
          multiple: false,
        )).called(1);
  });

  testWidgets('garde la saisie si le lancement échoue', (tester) async {
    when(() => service.createRoomPoll(
          campaignId: any(named: 'campaignId'),
          question: any(named: 'question'),
          options: any(named: 'options'),
          multiple: any(named: 'multiple'),
        )).thenThrow(Exception('réseau indisponible'));

    await pumpComposer(tester);
    await tester.enterText(field('Question'), 'Où allons-nous ?');
    await tester.enterText(field('Réponse 1'), 'La forêt');
    await tester.enterText(field('Réponse 2'), 'La mine');

    await launch(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Où allons-nous ?'), findsOneWidget);
    expect(find.text('La mine'), findsOneWidget);
  });
}
