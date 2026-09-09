import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';
import 'package:scriptoria/features/room/presentation/room_settings_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/room_harness.dart';

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
      (_) async => [
        testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
        testMember(userId: kPlayerId, displayName: 'Camille'),
      ],
    );
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
        child: const RoomSettingsPage(),
        routes: {'/home': (context) => const HomePage()},
      ),
    );
    await tester.pumpAndSettle();
  }

  group('vue MJ', () {
    testWidgets('affiche le nom de la room, le code d\'invitation et les membres',
        (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      expect(find.text('Paramètres de la Room'), findsOneWidget);
      expect(find.text('Mystères de l\'Ombre'), findsOneWidget);
      expect(find.text('Code d\'invitation'), findsOneWidget);
      expect(find.text('X7K2P9'), findsOneWidget);
      expect(find.text('Aurélien'), findsOneWidget);
      expect(find.text('Camille'), findsOneWidget);
      expect(find.text('MJ'), findsOneWidget);
      expect(find.text('Supprimer la room'), findsOneWidget);
    });

    testWidgets('renomme la room et rafraîchit l\'affichage', (tester) async {
      when(() => service.updateCampaign(
            campaignId: kRoomId,
            title: any(named: 'title'),
            description: any(named: 'description'),
          )).thenAnswer((_) async => testCampaign(title: 'La Quête du Dragon'));

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.text('Nom de la room'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'La Quête du Dragon');
      // Le titre de la boîte de dialogue porte le même libellé que la tuile :
      // on vise le bouton par son texte propre.
      await tester.tap(find.text('Enregistrer'));

      // Le provider recharge la campagne : elle doit revenir renommée.
      when(() => service.getCampaignById(kRoomId))
          .thenAnswer((_) async => testCampaign(title: 'La Quête du Dragon'));
      await tester.pumpAndSettle();

      verify(() => service.updateCampaign(
            campaignId: kRoomId,
            title: 'La Quête du Dragon',
          )).called(1);
    });

    testWidgets('n\'enregistre rien si le nom est laissé vide', (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.text('Nom de la room'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      verifyNever(() => service.updateCampaign(
            campaignId: any(named: 'campaignId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
          ));
    });

    testWidgets('exclut un joueur, rafraîchit la liste, et sans erreur',
        (tester) async {
      when(() => service.removeCampaignMember(
            campaignId: kRoomId,
            userId: kPlayerId,
          )).thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Exclure Camille'));
      await tester.pumpAndSettle();

      expect(find.text('Exclure Camille ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Exclure'));
      await tester.pumpAndSettle();

      verify(() => service.removeCampaignMember(
            campaignId: kRoomId,
            userId: kPlayerId,
          )).called(1);

      // La liste doit être rechargée : une fois au montage, une fois après
      // l'exclusion. C'est ce rechargement qui plantait dans le bogue B24,
      // sans que la suppression elle-même échoue.
      verify(() => service.getCampaignMembers(kRoomId)).called(2);

      // Et surtout : aucun message d'erreur. Le test précédent se contentait
      // de vérifier l'appel de suppression, ce qui laissait passer un écran
      // qui affichait « une erreur est survenue » après un succès.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('n\'exclut personne si on annule', (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Exclure Camille'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => service.removeCampaignMember(
            campaignId: any(named: 'campaignId'),
            userId: any(named: 'userId'),
          ));
    });

    testWidgets('ne propose pas d\'exclure le MJ lui-même', (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      expect(find.byTooltip('Exclure Aurélien'), findsNothing);
    });

    testWidgets(
      'ne propose pas de quitter la room : un meneur ne peut pas abandonner '
      'sa table, il la supprime',
      (tester) async {
        await pumpAs(tester, kMjId, 'mj');

        expect(find.text('Quitter la room'), findsNothing);
      },
    );

    testWidgets('copie le code d\'invitation dans le presse-papiers', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Copier le code d\'invitation'));
      await tester.pumpAndSettle();

      expect(copied, 'X7K2P9');
      expect(find.text('Code d\'invitation copié'), findsOneWidget);
    });

    testWidgets('supprime la room et revient à l\'accueil après confirmation',
        (tester) async {
      when(() => service.deleteCampaign(kRoomId)).thenAnswer((_) async {});
      // L'écran d'arrivée charge ses propres campagnes.
      when(() => service.getVisibleCampaigns(any())).thenAnswer((_) async => []);

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.text('Supprimer la room'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      verify(() => service.deleteCampaign(kRoomId)).called(1);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('annule la suppression si on ne confirme pas', (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.text('Supprimer la room'));
      await tester.pumpAndSettle();
      expect(find.text('Cette action est irréversible.'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => service.deleteCampaign(any()));
      expect(find.text('Paramètres de la Room'), findsOneWidget);
    });
  });

  group('vue joueur', () {
    testWidgets('voit les membres mais aucun outil de MJ', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Aurélien'), findsOneWidget);
      expect(find.text('Camille'), findsOneWidget);
      expect(find.text('MJ'), findsOneWidget);

      // Réservé au MJ : renommage, code d'invitation, exclusion, suppression.
      expect(find.text('Code d\'invitation'), findsNothing);
      expect(find.byTooltip('Exclure Aurélien'), findsNothing);
      expect(find.byTooltip('Exclure Camille'), findsNothing);
      expect(find.text('Supprimer la room'), findsNothing);
    });

    testWidgets('ne peut pas ouvrir la boîte de renommage', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      await tester.tap(find.text('Nom de la room'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('peut quitter la room de lui-même', (tester) async {
      when(() => service.removeCampaignMember(
            campaignId: kRoomId,
            userId: kPlayerId,
          )).thenAnswer((_) async {});
      when(() => service.getVisibleCampaigns(any())).thenAnswer((_) async => []);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Quitter la room'), findsOneWidget);
      await tester.tap(find.text('Quitter la room'));
      await tester.pumpAndSettle();

      expect(find.text('Quitter cette room ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Quitter'));
      await tester.pumpAndSettle();

      verify(() => service.removeCampaignMember(
            campaignId: kRoomId,
            userId: kPlayerId,
          )).called(1);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('ne quitte pas la room si on annule', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      await tester.tap(find.text('Quitter la room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => service.removeCampaignMember(
            campaignId: any(named: 'campaignId'),
            userId: any(named: 'userId'),
          ));
      expect(find.text('Paramètres de la Room'), findsOneWidget);
    });
  });

  testWidgets('un membre sans profil reste identifiable', (tester) async {
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
      (_) async => [
        testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
        testMember(userId: kPlayerId),
      ],
    );

    await pumpAs(tester, kMjId, 'mj');

    expect(find.text('Utilisateur sans profil'), findsOneWidget);
  });

  testWidgets('affiche un message quand la room n\'a aucun membre', (tester) async {
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer((_) async => []);

    await pumpAs(tester, kMjId, 'mj');

    expect(find.text('Aucun joueur pour l\'instant'), findsOneWidget);
  });
}
