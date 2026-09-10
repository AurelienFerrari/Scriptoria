import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/feed/room_post_composer_page.dart';
import 'package:scriptoria/features/room/presentation/room_home_page.dart';
import 'package:scriptoria/features/room/presentation/zoomable_image_viewer.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/network_image_stub.dart';
import '../../../helpers/room_harness.dart';

Map<String, dynamic> _post({
  String id = 'post-1',
  String? body = 'Le brouillard se lève sur Val-Morne.',
  String? imageUrl,
  List<String>? visibleTo,
}) =>
    {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'body': body,
      'image_url': imageUrl,
      'image_bucket': imageUrl == null ? null : 'images',
      'image_path': imageUrl == null ? null : 'user-mj/post-campaign-1/scene.png',
      'visible_to': visibleTo,
      'created_at': '2026-09-10T10:00:00Z',
      'updated_at': '2026-09-10T10:00:00Z',
    };

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUpAll(() => HttpOverrides.global = StubImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    stubRoomScreens(service);
  });

  Future<void> pumpAs(WidgetTester tester, String userId, String role) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: userId,
      role: role,
    );
    await tester.pumpWidget(
      wrapRoomScreen(
        auth: auth,
        room: room,
        child: const RoomHomePage(
          roomName: 'Salle du Dragon',
          description: 'Bienvenue dans la salle du Dragon !',
          lastUpdate: 'Aujourd\'hui à 12:30',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche l\'identité de la room en en-tête', (tester) async {
    await pumpAs(tester, kMjId, 'mj');

    expect(find.text('Salle du Dragon'), findsWidgets);
    expect(find.text('Bienvenue dans la salle du Dragon !'), findsOneWidget);
    expect(
      find.text('Dernière mise à jour : Aujourd\'hui à 12:30'),
      findsOneWidget,
    );
  });

  testWidgets('n\'affiche plus la galerie, passée dans l\'onglet Contenus',
      (tester) async {
    await pumpAs(tester, kMjId, 'mj');

    expect(find.bySemanticsLabel('Ajouter une image'), findsNothing);
  });

  group('le fil', () {
    testWidgets('liste les publications', (tester) async {
      when(() => service.getRoomPosts(kRoomId)).thenAnswer((_) async => [
            _post(),
            _post(id: 'post-2', body: 'Une silhouette vous observe.'),
          ]);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Le fil de la table'), findsOneWidget);
      expect(find.text('Le brouillard se lève sur Val-Morne.'), findsOneWidget);
      expect(find.text('Une silhouette vous observe.'), findsOneWidget);
    });

    testWidgets('affiche l\'image d\'une publication', (tester) async {
      when(() => service.getRoomPosts(kRoomId)).thenAnswer((_) async => [
            _post(body: null, imageUrl: 'https://exemple.test/scene.png'),
          ]);

      await pumpAs(tester, kPlayerId, 'player');

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
    });

    testWidgets('replie un texte long derrière « Voir plus »', (tester) async {
      final texteLong = List.filled(40, 'Le brouillard se lève.').join(' ');
      when(() => service.getRoomPosts(kRoomId))
          .thenAnswer((_) async => [_post(body: texteLong)]);

      await pumpAs(tester, kPlayerId, 'player');

      // Replié : une seule ligne. Sans cela, une publication de trente lignes
      // ferait une carte haute de trois écrans et le fil deviendrait
      // impossible à parcourir.
      var texte = tester.widget<Text>(find.text(texteLong));
      expect(texte.maxLines, 1);
      expect(find.text('Voir plus'), findsOneWidget);

      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();

      texte = tester.widget<Text>(find.text(texteLong));
      expect(texte.maxLines, isNull);
      expect(find.text('Voir moins'), findsOneWidget);
    });

    testWidgets('ne propose pas « Voir plus » sur un texte court',
        (tester) async {
      when(() => service.getRoomPosts(kRoomId))
          .thenAnswer((_) async => [_post(body: 'Court.')]);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Voir plus'), findsNothing);
    });

    testWidgets('ouvre l\'image en grand au tap', (tester) async {
      when(() => service.getRoomPosts(kRoomId)).thenAnswer((_) async => [
            _post(body: null, imageUrl: 'https://exemple.test/scene.png'),
          ]);

      await pumpAs(tester, kPlayerId, 'player');

      await tester.tap(find.bySemanticsLabel('Voir l\'image en grand'));
      await tester.pumpAndSettle();

      expect(find.byType(ZoomableImageViewer), findsOneWidget);
      expect(find.byTooltip('Fermer'), findsOneWidget);
    });

    testWidgets('annonce un fil vide différemment selon le rôle', (tester) async {
      await pumpAs(tester, kMjId, 'mj');
      expect(
        find.textContaining('Utilisez « Publier » pour parler à votre table.'),
        findsOneWidget,
      );

      await pumpAs(tester, kPlayerId, 'player');
      expect(
        find.text('Le maître du jeu n\'a rien publié pour l\'instant.'),
        findsOneWidget,
      );
    });
  });

  group('vue MJ', () {
    testWidgets('peut ouvrir le composeur', (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      expect(find.text('Publier'), findsOneWidget);
      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();

      expect(find.byType(RoomPostComposerPage), findsOneWidget);
    });

    testWidgets('voit à combien de joueurs une publication est adressée',
        (tester) async {
      when(() => service.getRoomPosts(kRoomId))
          .thenAnswer((_) async => [_post(visibleTo: [kPlayerId])]);

      await pumpAs(tester, kMjId, 'mj');

      expect(find.bySemanticsLabel('Adressée à 1 joueur'), findsOneWidget);
    });

    testWidgets('supprime une publication après confirmation', (tester) async {
      when(() => service.getRoomPosts(kRoomId))
          .thenAnswer((_) async => [_post()]);
      when(() => service.deleteRoomPost(any())).thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur la publication'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cette publication ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      verify(() => service.deleteRoomPost(any())).called(1);
      // Une fois au montage, une fois après la suppression.
      verify(() => service.getRoomPosts(kRoomId)).called(2);
    });

    testWidgets('change les destinataires d\'une publication', (tester) async {
      when(() => service.getRoomPosts(kRoomId))
          .thenAnswer((_) async => [_post()]);
      when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
        (_) async => [
          testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
          testMember(userId: kPlayerId, displayName: 'Camille'),
        ],
      );
      when(() => service.updateRoomPostAudience(
            postId: any(named: 'postId'),
            visibleTo: any(named: 'visibleTo'),
          )).thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur la publication'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Destinataires'));
      await tester.pumpAndSettle();

      expect(find.text('Qui reçoit cette publication ?'), findsOneWidget);
      // « Personne » n'a pas de sens pour une annonce : l'option est absente.
      expect(find.text('Personne pour l\'instant'), findsNothing);

      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.updateRoomPostAudience(
            postId: 'post-1',
            visibleTo: [kPlayerId],
          )).called(1);
    });
  });

  group('vue joueur', () {
    testWidgets('ne peut ni publier ni gérer une publication', (tester) async {
      when(() => service.getRoomPosts(kRoomId))
          .thenAnswer((_) async => [_post(visibleTo: [kPlayerId])]);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Publier'), findsNothing);
      expect(find.byTooltip('Actions sur la publication'), findsNothing);
      // Le badge de destinataires ne lui apprendrait rien : il ne reçoit que
      // ce qui lui est adressé.
      expect(find.bySemanticsLabel('Adressée à 1 joueur'), findsNothing);
    });
  });
}
