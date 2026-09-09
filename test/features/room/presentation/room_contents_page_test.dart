import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/room_contents_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/network_image_stub.dart';
import '../../../helpers/room_harness.dart';

Map<String, dynamic> _image({
  String id = 'image-1',
  String url = 'https://exemple.test/carte.png',
  String path = 'user-mj/campaign-campaign-1/carte.png',
}) =>
    {
      'id': id,
      'owner_id': kMjId,
      'campaign_id': kRoomId,
      'bucket': 'images',
      'path': path,
      'url': url,
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
          'Les images que vous publiez ici sont visibles par tous les joueurs.',
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

      // L'aperçu plein écran porte le bouton de suppression.
      await tester.tap(find.bySemanticsLabel('Ouvrir l\'image 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Supprimer l\'image'));
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
