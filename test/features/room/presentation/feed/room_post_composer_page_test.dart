import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/feed/room_post_composer_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/room_harness.dart';

class _FakeXFile extends Fake implements XFile {}

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUpAll(() => registerFallbackValue(_FakeXFile()));

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
      (_) async => [
        testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
        testMember(userId: kPlayerId, displayName: 'Camille'),
      ],
    );
    when(() => service.createRoomPost(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          body: any(named: 'body'),
          image: any(named: 'image'),
          visibleTo: any(named: 'visibleTo'),
        )).thenAnswer((_) async => {'id': 'post-1'});
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: kMjId,
      role: 'mj',
    );
    await tester.pumpWidget(
      wrapRoomScreen(
        auth: auth,
        room: room,
        child: const RoomPostComposerPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('publie à toute la table par défaut', (tester) async {
    await pumpComposer(tester);

    expect(find.text('Tous les joueurs'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Le brouillard se lève.');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    // `null` désigne tous les membres : une annonce s'adresse à la table sauf
    // mention contraire.
    verify(() => service.createRoomPost(
          campaignId: kRoomId,
          authorId: kMjId,
          body: 'Le brouillard se lève.',
          image: null,
          visibleTo: null,
        )).called(1);
  });

  testWidgets('adresse une publication à un joueur précis', (tester) async {
    await pumpComposer(tester);

    await tester.enterText(find.byType(TextField), 'Toi seul le remarques.');

    await tester.tap(find.text('Destinataires'));
    await tester.pumpAndSettle();

    expect(find.text('Qui reçoit cette publication ?'), findsOneWidget);
    // Le MJ reçoit toujours ce qu'il publie : il n'apparaît pas dans la liste.
    await tester.tap(find.text('Joueurs choisis'));
    await tester.pumpAndSettle();
    expect(find.text('Aurélien'), findsNothing);

    await tester.tap(find.text('Camille'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Valider'));
    await tester.pumpAndSettle();

    expect(find.text('1 joueur'), findsOneWidget);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    verify(() => service.createRoomPost(
          campaignId: kRoomId,
          authorId: kMjId,
          body: 'Toi seul le remarques.',
          image: null,
          visibleTo: [kPlayerId],
        )).called(1);
  });

  testWidgets('refuse une publication vide', (tester) async {
    await pumpComposer(tester);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(find.text('Écrivez un texte ou ajoutez une image.'), findsOneWidget);
    verifyNever(() => service.createRoomPost(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          body: any(named: 'body'),
          image: any(named: 'image'),
          visibleTo: any(named: 'visibleTo'),
        ));
  });

  testWidgets(
    'refuse une sélection vide : publier à personne serait un accident, pas '
    'une intention',
    (tester) async {
      await pumpComposer(tester);

      await tester.enterText(find.byType(TextField), 'Un texte.');

      await tester.tap(find.text('Destinataires'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();
      // Aucune case cochée.
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun destinataire choisi'), findsOneWidget);

      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();

      expect(find.text('Choisissez au moins un destinataire.'), findsOneWidget);
      verifyNever(() => service.createRoomPost(
            campaignId: any(named: 'campaignId'),
            authorId: any(named: 'authorId'),
            body: any(named: 'body'),
            image: any(named: 'image'),
            visibleTo: any(named: 'visibleTo'),
          ));
    },
  );

  testWidgets('signale un échec sans faire disparaître le texte saisi',
      (tester) async {
    when(() => service.createRoomPost(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          body: any(named: 'body'),
          image: any(named: 'image'),
          visibleTo: any(named: 'visibleTo'),
        )).thenThrow(Exception('réseau indisponible'));

    await pumpComposer(tester);

    await tester.enterText(find.byType(TextField), 'Un texte qu\'on ne veut pas perdre.');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomPostComposerPage), findsOneWidget);
    expect(find.text('Un texte qu\'on ne veut pas perdre.'), findsOneWidget);
  });
}
