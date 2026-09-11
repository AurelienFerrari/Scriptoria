import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/outils/timeline_event_editor_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/room_harness.dart';

Map<String, dynamic> _event({
  String id = 'event-1',
  String title = 'La chute de Valmorne',
  String dateLabel = 'An 1247',
  String description = 'La ville tombe en trois jours.',
  List<String>? visibleTo,
}) =>
    {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'date_label': dateLabel,
      'title': title,
      'description': description,
      'position': 0,
      'visible_to': visibleTo,
      'created_at': '2026-09-10T09:00:00Z',
      'updated_at': '2026-09-10T09:00:00Z',
    };

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

  Future<void> pumpEditor(
    WidgetTester tester, {
    Map<String, dynamic>? event,
    int nextPosition = 0,
  }) async {
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
        child: TimelineEventEditorPage(
          event: event,
          nextPosition: nextPosition,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('création', () {
    testWidgets('enregistre l\'évènement à la place demandée', (tester) async {
      when(() => service.createTimelineEvent(
            campaignId: any(named: 'campaignId'),
            authorId: any(named: 'authorId'),
            title: any(named: 'title'),
            dateLabel: any(named: 'dateLabel'),
            description: any(named: 'description'),
            position: any(named: 'position'),
            visibleTo: any(named: 'visibleTo'),
          )).thenAnswer((_) async => _event());

      await pumpEditor(tester, nextPosition: 3);

      await tester.enterText(
        find.widgetWithText(TextField, 'Repère temporel'),
        'An 1247, au printemps',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Titre'),
        'La chute de Valmorne',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Récit'),
        'La ville tombe en trois jours.',
      );

      await tester.tap(find.byTooltip('Enregistrer'));
      await tester.pumpAndSettle();

      // `visibleTo: null` : un évènement raconte par défaut ce que toute la
      // table a vécu.
      verify(() => service.createTimelineEvent(
            campaignId: kRoomId,
            authorId: kMjId,
            title: 'La chute de Valmorne',
            dateLabel: 'An 1247, au printemps',
            description: 'La ville tombe en trois jours.',
            position: 3,
            visibleTo: null,
          )).called(1);
    });

    testWidgets('refuse un évènement sans titre', (tester) async {
      await pumpEditor(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Repère temporel'),
        'An 1247',
      );
      await tester.tap(find.byTooltip('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Donnez un titre à l\'évènement.'), findsOneWidget);
      verifyNever(() => service.createTimelineEvent(
            campaignId: any(named: 'campaignId'),
            authorId: any(named: 'authorId'),
            title: any(named: 'title'),
            dateLabel: any(named: 'dateLabel'),
            description: any(named: 'description'),
            position: any(named: 'position'),
            visibleTo: any(named: 'visibleTo'),
          ));
    });

    testWidgets('réserve un évènement préparé au MJ seul', (tester) async {
      when(() => service.createTimelineEvent(
            campaignId: any(named: 'campaignId'),
            authorId: any(named: 'authorId'),
            title: any(named: 'title'),
            dateLabel: any(named: 'dateLabel'),
            description: any(named: 'description'),
            position: any(named: 'position'),
            visibleTo: any(named: 'visibleTo'),
          )).thenAnswer((_) async => _event());

      await pumpEditor(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Titre'),
        'La trahison à venir',
      );

      await tester.tap(find.text('Qui peut le voir'));
      await tester.pumpAndSettle();

      expect(find.text('Qui peut voir cet évènement ?'), findsOneWidget);
      await tester.tap(find.text('Personne pour l\'instant'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Vous seul, pour l\'instant'), findsOneWidget);

      await tester.tap(find.byTooltip('Enregistrer'));
      await tester.pumpAndSettle();

      // Liste vide, et non `null` : « personne » et « toute la table » sont
      // deux valeurs opposées de la même colonne.
      verify(() => service.createTimelineEvent(
            campaignId: kRoomId,
            authorId: kMjId,
            title: 'La trahison à venir',
            dateLabel: '',
            description: '',
            position: 0,
            visibleTo: const [],
          )).called(1);
    });

    testWidgets('n\'offre pas au MJ de s\'exclure de sa propre frise',
        (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('Qui peut le voir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();

      expect(find.text('Aurélien'), findsNothing);
      expect(find.text('Camille'), findsOneWidget);
    });
  });

  group('modification', () {
    testWidgets('recharge les champs de l\'évènement', (tester) async {
      await pumpEditor(tester, event: _event(visibleTo: const []));

      expect(find.text('Modifier l\'évènement'), findsOneWidget);
      expect(find.text('An 1247'), findsOneWidget);
      expect(find.text('La chute de Valmorne'), findsOneWidget);
      expect(find.text('Vous seul, pour l\'instant'), findsOneWidget);
    });

    testWidgets('rouvre à toute la table un évènement gardé secret',
        (tester) async {
      when(() => service.updateTimelineEvent(
            eventId: any(named: 'eventId'),
            title: any(named: 'title'),
            dateLabel: any(named: 'dateLabel'),
            description: any(named: 'description'),
            visibleTo: any(named: 'visibleTo'),
          )).thenAnswer((_) async {});

      await pumpEditor(tester, event: _event(visibleTo: const []));

      await tester.tap(find.text('Qui peut le voir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous les joueurs'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Enregistrer'));
      await tester.pumpAndSettle();

      // `null` est bien envoyé : l'omettre laisserait l'évènement secret,
      // c'est tout l'intérêt de toujours écrire la colonne à la mise à jour.
      verify(() => service.updateTimelineEvent(
            eventId: 'event-1',
            title: 'La chute de Valmorne',
            dateLabel: 'An 1247',
            description: 'La ville tombe en trois jours.',
            visibleTo: null,
          )).called(1);
    });
  });
}
