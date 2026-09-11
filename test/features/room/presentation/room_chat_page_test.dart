import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/services/row_change.dart';
import 'package:scriptoria/features/room/presentation/room_chat_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/room_harness.dart';

Map<String, dynamic> _message({
  String id = 'message-1',
  String authorId = kPlayerId,
  String body = 'On passe par les égouts.',
  List<String>? visibleTo,
}) =>
    {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': authorId,
      'body': body,
      'visible_to': visibleTo,
      'created_at': '2026-09-11T10:00:00Z',
    };

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;
  late StreamController<RowChange> changes;
  late bool subscriptionCancelled;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    subscriptionCancelled = false;
    changes = StreamController<RowChange>(
      onCancel: () => subscriptionCancelled = true,
    );

    when(() => service.getRoomMessages(kRoomId)).thenAnswer((_) async => []);
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
      (_) async => [
        testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
        testMember(userId: kPlayerId, displayName: 'Camille'),
      ],
    );
    when(() => service.watchRoomTable('room_messages', kRoomId))
        .thenAnswer((_) => changes.stream);
    when(() => service.deleteRoomMessage(any())).thenAnswer((_) async {});
  });

  tearDown(() => changes.close());

  Future<void> pumpAs(WidgetTester tester, String userId, String role) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: userId,
      role: role,
    );
    await tester.pumpWidget(
      wrapRoomScreen(auth: auth, room: room, child: const RoomChatPage()),
    );
    await tester.pumpAndSettle();
  }

  void stubSend(Map<String, dynamic> returned) {
    when(() => service.createRoomMessage(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          body: any(named: 'body'),
          visibleTo: any(named: 'visibleTo'),
        )).thenAnswer((_) async => returned);
  }

  testWidgets('affiche l\'historique de la room, sans message inventé',
      (tester) async {
    when(() => service.getRoomMessages(kRoomId)).thenAnswer(
      (_) async => [
        _message(),
        _message(
          id: 'message-2',
          authorId: kMjId,
          body: 'La grille est rouillée.',
        ),
      ],
    );

    await pumpAs(tester, kPlayerId, 'player');

    expect(find.text('Chat de la room'), findsOneWidget);
    expect(find.text('On passe par les égouts.'), findsOneWidget);
    expect(find.text('La grille est rouillée.'), findsOneWidget);
    // L'auteur des messages des autres est nommé ; les siens, non.
    expect(find.text('Aurélien'), findsOneWidget);
    expect(find.text('Camille'), findsNothing);
    // Les trois messages codés en dur de l'ancienne version ont disparu.
    expect(find.text('Bienvenue dans le chat !'), findsNothing);
    expect(find.text('Nouveau message test'), findsNothing);
  });

  testWidgets('annonce un chat vide', (tester) async {
    await pumpAs(tester, kPlayerId, 'player');

    expect(
      find.text('Aucun message pour l\'instant.\nLancez la conversation.'),
      findsOneWidget,
    );
  });

  testWidgets('envoie un message à toute la table', (tester) async {
    stubSend(_message(id: 'message-9', body: 'Salut la table'));

    await pumpAs(tester, kPlayerId, 'player');
    await tester.enterText(find.byType(TextField), '  Salut la table  ');
    await tester.tap(find.byTooltip('Envoyer le message'));
    await tester.pumpAndSettle();

    verify(() => service.createRoomMessage(
          campaignId: kRoomId,
          authorId: kPlayerId,
          body: 'Salut la table',
          visibleTo: null,
        )).called(1);
    expect(find.text('Salut la table'), findsOneWidget);
    // La saisie est vidée une fois le message parti.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('n\'envoie pas un message vide', (tester) async {
    await pumpAs(tester, kPlayerId, 'player');

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Envoyer le message'));
    await tester.pumpAndSettle();

    verifyNever(() => service.createRoomMessage(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          body: any(named: 'body'),
          visibleTo: any(named: 'visibleTo'),
        ));
  });

  testWidgets('garde le texte saisi si l\'envoi échoue', (tester) async {
    when(() => service.createRoomMessage(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          body: any(named: 'body'),
          visibleTo: any(named: 'visibleTo'),
        )).thenThrow(Exception('réseau indisponible'));

    await pumpAs(tester, kPlayerId, 'player');
    await tester.enterText(find.byType(TextField), 'Message important');
    await tester.tap(find.byTooltip('Envoyer le message'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Message important',
    );
  });

  group('temps réel', () {
    testWidgets('affiche un message reçu d\'un autre membre', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      changes.add(RowChange(
        RowChangeKind.inserted,
        _message(
          id: 'message-5',
          authorId: kMjId,
          body: 'Quelqu\'un approche.',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Quelqu\'un approche.'), findsOneWidget);
    });

    testWidgets('n\'affiche qu\'une fois son propre message, reçu deux fois',
        (tester) async {
      final sent = _message(id: 'message-9', body: 'Une seule fois');
      stubSend(sent);

      await pumpAs(tester, kPlayerId, 'player');
      await tester.enterText(find.byType(TextField), 'Une seule fois');
      await tester.tap(find.byTooltip('Envoyer le message'));
      await tester.pumpAndSettle();

      // Le même message revient par le temps réel.
      changes.add(RowChange(RowChangeKind.inserted, sent));
      await tester.pumpAndSettle();

      expect(find.text('Une seule fois'), findsOneWidget);
    });

    testWidgets('retire un message supprimé depuis un autre appareil',
        (tester) async {
      when(() => service.getRoomMessages(kRoomId))
          .thenAnswer((_) async => [_message()]);

      await pumpAs(tester, kPlayerId, 'player');
      expect(find.text('On passe par les égouts.'), findsOneWidget);

      // Une suppression ne porte que l'id de la ligne.
      changes.add(const RowChange(RowChangeKind.deleted, {'id': 'message-1'}));
      await tester.pumpAndSettle();

      expect(find.text('On passe par les égouts.'), findsNothing);
    });

    testWidgets('ignore la suppression d\'un message d\'une autre room',
        (tester) async {
      when(() => service.getRoomMessages(kRoomId))
          .thenAnswer((_) async => [_message()]);

      await pumpAs(tester, kPlayerId, 'player');
      changes.add(const RowChange(RowChangeKind.deleted, {'id': 'ailleurs'}));
      await tester.pumpAndSettle();

      expect(find.text('On passe par les égouts.'), findsOneWidget);
    });

    testWidgets('se recharge après une reconnexion', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      // Realtime ne rejoue pas ce qui s'est dit pendant la coupure.
      changes.add(const RowChange(RowChangeKind.resubscribed));
      await tester.pumpAndSettle();

      verify(() => service.getRoomMessages(kRoomId)).called(2);
    });

    testWidgets('referme l\'abonnement en quittant le chat', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');
      expect(subscriptionCancelled, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(subscriptionCancelled, isTrue);
    });
  });

  group('chuchotements', () {
    testWidgets('le MJ chuchote à un joueur choisi', (tester) async {
      stubSend(_message(
        id: 'message-9',
        authorId: kMjId,
        body: 'Le garde ment.',
        visibleTo: [kPlayerId],
      ));

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Chuchoter à des joueurs'));
      await tester.pumpAndSettle();
      expect(find.text('À qui chuchoter ?'), findsOneWidget);
      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();
      // Le MJ ne figure pas parmi les destinataires possibles.
      expect(find.widgetWithText(CheckboxListTile, 'Aurélien'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Camille'));
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Chuchotement à Camille'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Le garde ment.');
      await tester.tap(find.byTooltip('Envoyer le message'));
      await tester.pumpAndSettle();

      verify(() => service.createRoomMessage(
            campaignId: kRoomId,
            authorId: kMjId,
            body: 'Le garde ment.',
            visibleTo: [kPlayerId],
          )).called(1);
      expect(find.text('Chuchoté à Camille'), findsOneWidget);
    });

    testWidgets('le MJ revient à toute la table en retirant le bandeau',
        (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Chuchoter à des joueurs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Camille'));
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Parler à toute la table'));
      await tester.pumpAndSettle();

      expect(find.text('Chuchotement à Camille'), findsNothing);
    });

    testWidgets('un joueur ne peut pas chuchoter', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      expect(find.byTooltip('Chuchoter à des joueurs'), findsNothing);
    });

    testWidgets('le destinataire sait qu\'un message lui est chuchoté',
        (tester) async {
      when(() => service.getRoomMessages(kRoomId)).thenAnswer(
        (_) async => [
          _message(
            authorId: kMjId,
            body: 'Le garde ment.',
            visibleTo: [kPlayerId],
          ),
        ],
      );

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Chuchoté pour vous'), findsOneWidget);
    });
  });

  group('modération', () {
    testWidgets('un joueur supprime son propre message', (tester) async {
      when(() => service.getRoomMessages(kRoomId))
          .thenAnswer((_) async => [_message()]);

      await pumpAs(tester, kPlayerId, 'player');
      await tester.longPress(find.text('On passe par les égouts.'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce message ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      verify(() => service.deleteRoomMessage('message-1')).called(1);
      expect(find.text('On passe par les égouts.'), findsNothing);
    });

    testWidgets('un joueur ne peut pas supprimer le message d\'un autre',
        (tester) async {
      when(() => service.getRoomMessages(kRoomId)).thenAnswer(
        (_) async => [_message(authorId: kMjId, body: 'Message du MJ')],
      );

      await pumpAs(tester, kPlayerId, 'player');
      await tester.longPress(find.text('Message du MJ'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce message ?'), findsNothing);
    });

    testWidgets('le MJ supprime le message d\'un joueur', (tester) async {
      when(() => service.getRoomMessages(kRoomId))
          .thenAnswer((_) async => [_message()]);

      await pumpAs(tester, kMjId, 'mj');
      await tester.longPress(find.text('On passe par les égouts.'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      verify(() => service.deleteRoomMessage('message-1')).called(1);
    });

    testWidgets('garde le message si la suppression est refusée',
        (tester) async {
      when(() => service.getRoomMessages(kRoomId))
          .thenAnswer((_) async => [_message()]);
      when(() => service.deleteRoomMessage(any()))
          .thenThrow(StateError('suppression refusée'));

      await pumpAs(tester, kPlayerId, 'player');
      await tester.longPress(find.text('On passe par les égouts.'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('On passe par les égouts.'), findsOneWidget);
    });
  });
}
