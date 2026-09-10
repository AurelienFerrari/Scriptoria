import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/room_contents_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/network_image_stub.dart';
import '../../../helpers/room_harness.dart';

/// [visibleTo] suit la convention de `images.visible_to` : `null` pour tous les
/// membres, liste vide pour personne.
Map<String, dynamic> _image({
  String id = 'image-1',
  String url = 'https://exemple.test/carte.png',
  String path = 'user-mj/campaign-campaign-1/carte.png',
  List<String>? visibleTo = const [],
}) =>
    {
      'id': id,
      'owner_id': kMjId,
      'campaign_id': kRoomId,
      'bucket': 'images',
      'path': path,
      'url': url,
      'visible_to': visibleTo,
      'created_at': '2026-09-09T10:00:00Z',
    };

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  // La galerie affiche des Image.network : sans interception, le binding de
  // test répond 400 et l'écran ne peut pas être testé du tout.
  setUpAll(() => HttpOverrides.global = StubImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    when(() => service.getCampaignImages(kRoomId)).thenAnswer((_) async => []);
    // La vue MJ monte aussi la section des notes.
    when(() => service.getRoomNotes(kRoomId)).thenAnswer((_) async => []);
  });

  Future<void> pumpAs(WidgetTester tester, String userId, String role) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: userId,
      role: role,
    );
    await tester.pumpWidget(
      wrapRoomScreen(auth: auth, room: room, child: const RoomContentsPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('charge les images de la room au montage', (tester) async {
    when(() => service.getCampaignImages(kRoomId))
        .thenAnswer((_) async => [_image()]);

    await pumpAs(tester, kMjId, 'mj');

    expect(find.text('Contenus'), findsOneWidget);
    expect(find.text('Galerie'), findsOneWidget);
    verify(() => service.getCampaignImages(kRoomId)).called(1);
  });

  group('vue MJ', () {
    testWidgets('peut publier une image', (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      expect(find.bySemanticsLabel('Ajouter une image'), findsOneWidget);
      expect(
        find.text(
          'Une image importée reste masquée : à vous de choisir qui la voit, image par image.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('retire une image après confirmation et recharge la galerie',
        (tester) async {
      when(() => service.getCampaignImages(kRoomId))
          .thenAnswer((_) async => [_image()]);
      when(() => service.removeCampaignImage(
            imageId: any(named: 'imageId'),
            bucket: any(named: 'bucket'),
            path: any(named: 'path'),
          )).thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur l\'image 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer cette image ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
      await tester.pumpAndSettle();

      verify(() => service.removeCampaignImage(
            imageId: 'image-1',
            bucket: 'images',
            path: 'user-mj/campaign-campaign-1/carte.png',
          )).called(1);

      // Une fois au montage, une fois après la suppression.
      verify(() => service.getCampaignImages(kRoomId)).called(2);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('voit les images masquées, contrairement aux joueurs',
        (tester) async {
      when(() => service.getCampaignImages(kRoomId))
          .thenAnswer((_) async => [_image()]);

      await pumpAs(tester, kMjId, 'mj');

      expect(find.bySemanticsLabel('Visibilité : Masquée'), findsOneWidget);
    });

    testWidgets('ouvre la room à tous les joueurs depuis la boîte de visibilité',
        (tester) async {
      when(() => service.getCampaignImages(kRoomId))
          .thenAnswer((_) async => [_image()]);
      when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
        (_) async => [
          testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
          testMember(userId: kPlayerId, displayName: 'Camille'),
        ],
      );
      when(() => service.updateImageVisibility(
            imageId: any(named: 'imageId'),
            visibleTo: any(named: 'visibleTo'),
          )).thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur l\'image 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visibilité'));
      await tester.pumpAndSettle();

      expect(find.text('Qui peut voir cette image ?'), findsOneWidget);
      await tester.tap(find.text('Tous les joueurs'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      // `null` ouvre l'image à tous les membres.
      verify(() => service.updateImageVisibility(
            imageId: 'image-1',
            visibleTo: null,
          )).called(1);
    });

    testWidgets('réserve une image à un joueur choisi', (tester) async {
      when(() => service.getCampaignImages(kRoomId))
          .thenAnswer((_) async => [_image()]);
      when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
        (_) async => [
          testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
          testMember(userId: kPlayerId, displayName: 'Camille'),
        ],
      );
      when(() => service.updateImageVisibility(
            imageId: any(named: 'imageId'),
            visibleTo: any(named: 'visibleTo'),
          )).thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur l\'image 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visibilité'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();

      // Le MJ ne figure pas dans la liste : il voit toujours ses images, l'y
      // faire apparaître laisserait croire qu'il peut s'en exclure.
      expect(find.text('Aurélien'), findsNothing);
      expect(find.text('Camille'), findsOneWidget);

      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.updateImageVisibility(
            imageId: 'image-1',
            visibleTo: [kPlayerId],
          )).called(1);
    });

    testWidgets('n\'écrit rien si la boîte de visibilité est annulée',
        (tester) async {
      when(() => service.getCampaignImages(kRoomId))
          .thenAnswer((_) async => [_image()]);
      when(() => service.getCampaignMembers(kRoomId))
          .thenAnswer((_) async => []);

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur l\'image 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visibilité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Annuler doit rester sans effet : un `null` renvoyé par la boîte
      // signifierait « tous les joueurs », soit l'inverse de l'intention.
      verifyNever(() => service.updateImageVisibility(
            imageId: any(named: 'imageId'),
            visibleTo: any(named: 'visibleTo'),
          ));
    });
  });

  group('vue joueur', () {
    testWidgets('consulte la galerie sans pouvoir y toucher', (tester) async {
      when(() => service.getCampaignImages(kRoomId))
          .thenAnswer((_) async => [_image()]);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.bySemanticsLabel('Ajouter une image'), findsNothing);
      expect(
        find.text('Les images publiées par le maître du jeu.'),
        findsOneWidget,
      );
    });

    testWidgets('voit un message quand la galerie est vide', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      expect(
        find.text("Le maître du jeu n'a pas encore publié d'image."),
        findsOneWidget,
      );
    });
  });
}
