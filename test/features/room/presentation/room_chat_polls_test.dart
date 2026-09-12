import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/services/row_change.dart';
import 'package:scriptoria/features/room/presentation/room_chat_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/room_harness.dart';

/// Le message qui porte le sondage : `kind = 'poll'`, la question dans `body`.
Map<String, dynamic> _pollMessage({String authorId = kPlayerId}) => {
      'id': 'message-p',
      'campaign_id': kRoomId,
      'author_id': authorId,
      'body': 'Où allons-nous ?',
      'kind': 'poll',
      'visible_to': null,
      'reply_to': null,
      'created_at': '2026-09-11T10:00:00Z',
    };

Map<String, dynamic> _poll({bool revealed = false, List<int>? votes}) => {
      'poll_id': 'poll-1',
      'message_id': 'message-p',
      'multiple': false,
      'closed': false,
      'revealed': revealed,
      'total_voters': revealed ? 1 : 0,
      'my_votes': revealed ? ['opt-2'] : <String>[],
      'options': [
        {'id': 'opt-1', 'label': 'La forêt', 'position': 0, 'votes': votes?[0]},
        {'id': 'opt-2', 'label': 'La mine', 'position': 1, 'votes': votes?[1]},
      ],
    };

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;
  late StreamController<RowChange> pollChanges;
  late Map<String, dynamic> currentPoll;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    pollChanges = StreamController<RowChange>();
    currentPoll = _poll();

    when(() => service.getRoomMessages(kRoomId))
        .thenAnswer((_) async => [_pollMessage()]);
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
      (_) async => [
        testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
        testMember(userId: kPlayerId, displayName: 'Camille'),
      ],
    );
    when(() => service.watchRoomTable('room_messages', kRoomId))
        .thenAnswer((_) => const Stream.empty());
    when(() => service.watchRoomTable('room_polls', kRoomId))
        .thenAnswer((_) => pollChanges.stream);
    when(() => service.getRoomPolls(any()))
        .thenAnswer((_) async => [currentPoll]);
    when(() => service.voteRoomPoll(
          pollId: any(named: 'pollId'),
          optionIds: any(named: 'optionIds'),
        )).thenAnswer((_) async {});
    when(() => service.closeRoomPoll(any())).thenAnswer((_) async {});
  });

  tearDown(() => pollChanges.close());

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

  testWidgets('affiche un sondage de la room dans la conversation',
      (tester) async {
    await pumpAs(tester, kPlayerId, 'player');

    expect(find.text('Où allons-nous ?'), findsOneWidget);
    expect(find.text('La forêt'), findsOneWidget);
    expect(find.text('La mine'), findsOneWidget);
    verify(() => service.getRoomPolls(['message-p'])).called(1);
  });

  testWidgets('ne demande aucun sondage quand le chat n\'en contient pas',
      (tester) async {
    when(() => service.getRoomMessages(kRoomId)).thenAnswer(
      (_) async => [
        {..._pollMessage(), 'id': 'message-1', 'kind': 'text', 'body': 'Salut'},
      ],
    );

    await pumpAs(tester, kPlayerId, 'player');

    verifyNever(() => service.getRoomPolls(any()));
  });

  testWidgets('vote depuis le chat, puis découvre les résultats',
      (tester) async {
    await pumpAs(tester, kPlayerId, 'player');
    expect(find.textContaining('%'), findsNothing);

    // Après le vote, la base accepte de révéler les compteurs.
    currentPoll = _poll(revealed: true, votes: [0, 1]);
    await tester.tap(find.text('La mine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Voter'));
    await tester.pumpAndSettle();

    verify(() => service.voteRoomPoll(pollId: 'poll-1', optionIds: ['opt-2']))
        .called(1);
    expect(find.text('100 %'), findsOneWidget);
  });

  testWidgets('rafraîchit un sondage quand un autre membre vote',
      (tester) async {
    await pumpAs(tester, kPlayerId, 'player');
    clearInteractions(service);

    // Un vote ailleurs touche le sondage : seul ce signal circule, jamais le
    // vote lui-même.
    pollChanges.add(const RowChange(
      RowChangeKind.updated,
      {'id': 'poll-1', 'message_id': 'message-p'},
    ));
    await tester.pumpAndSettle();

    verify(() => service.getRoomPolls(['message-p'])).called(1);
  });

  testWidgets('le MJ clôt le sondage d\'un joueur après confirmation',
      (tester) async {
    await pumpAs(tester, kMjId, 'mj');

    await tester.tap(find.text('Clore le sondage'));
    await tester.pumpAndSettle();
    expect(find.text('Clore le sondage ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Clore'));
    await tester.pumpAndSettle();

    verify(() => service.closeRoomPoll('poll-1')).called(1);
  });

  testWidgets('un joueur ne peut pas clore le sondage d\'un autre',
      (tester) async {
    when(() => service.getRoomMessages(kRoomId))
        .thenAnswer((_) async => [_pollMessage(authorId: kMjId)]);

    await pumpAs(tester, kPlayerId, 'player');

    expect(find.text('Clore le sondage'), findsNothing);
  });

  testWidgets('lance un sondage depuis le chat', (tester) async {
    when(() => service.getRoomMessages(kRoomId)).thenAnswer((_) async => []);
    when(() => service.createRoomPoll(
          campaignId: any(named: 'campaignId'),
          question: any(named: 'question'),
          options: any(named: 'options'),
          multiple: any(named: 'multiple'),
        )).thenAnswer((_) async => _pollMessage());

    await pumpAs(tester, kPlayerId, 'player');

    await tester.tap(find.byTooltip('Lancer un sondage'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau sondage'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Question'),
      'Où allons-nous ?',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Réponse 1'), 'La forêt');
    await tester.enterText(find.widgetWithText(TextField, 'Réponse 2'), 'La mine');
    await tester.tap(find.text('Lancer le sondage'));
    await tester.pumpAndSettle();

    // Retour au chat : le sondage y a pris sa place.
    expect(find.text('Nouveau sondage'), findsNothing);
    expect(find.text('Où allons-nous ?'), findsOneWidget);
    verify(() => service.getRoomPolls(['message-p'])).called(1);
  });
}
