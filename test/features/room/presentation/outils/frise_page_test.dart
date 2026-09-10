import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/outils/frise_page.dart';
import 'package:scriptoria/features/room/presentation/outils/timeline_event_editor_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/room_harness.dart';

/// [visibleTo] suit la convention de `room_timeline_events.visible_to` :
/// `null` pour toute la table, liste vide pour personne.
Map<String, dynamic> _event({
  String id = 'event-1',
  String title = 'Le siège de Valmorne',
  String dateLabel = 'An 1247, au printemps',
  String description = 'La ville tombe en trois jours.',
  int position = 0,
  List<String>? visibleTo,
}) =>
    {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'date_label': dateLabel,
      'title': title,
      'description': description,
      'position': position,
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
    when(() => service.getTimelineEvents(kRoomId)).thenAnswer((_) async => []);
    // L'éditeur charge les joueurs pour la boîte de destinataires.
    when(() => service.getCampaignMembers(kRoomId)).thenAnswer((_) async => []);
  });

  Future<void> pumpAs(WidgetTester tester, String userId, String role) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: userId,
      role: role,
    );
    await tester.pumpWidget(
      wrapRoomScreen(auth: auth, room: room, child: const FrisePage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('charge la frise de la room au montage', (tester) async {
    when(() => service.getTimelineEvents(kRoomId))
        .thenAnswer((_) async => [_event()]);

    await pumpAs(tester, kMjId, 'mj');

    expect(find.text('Frise'), findsOneWidget);
    expect(find.text('Le siège de Valmorne'), findsOneWidget);
    expect(find.text('La ville tombe en trois jours.'), findsOneWidget);
    // Le repère temporel est affiché en capitales.
    expect(find.text('AN 1247, AU PRINTEMPS'), findsOneWidget);
    verify(() => service.getTimelineEvents(kRoomId)).called(1);
  });

  group('récit long', () {
    // Assez long pour déborder d'une ligne à la largeur de l'écran de test.
    const longDescription =
        'La ville tombe en trois jours. Les remparts cèdent au matin du '
        'deuxième, et la garde se replie vers la citadelle sans que personne '
        'ait vu passer le signal convenu la veille au soir.';

    testWidgets('replie le récit et propose de le déplier', (tester) async {
      when(() => service.getTimelineEvents(kRoomId)).thenAnswer(
        (_) async => [_event(description: longDescription)],
      );

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Voir plus'), findsOneWidget);
      expect(find.text('Voir moins'), findsNothing);

      final replie = tester.widget<Text>(find.text(longDescription));
      expect(replie.maxLines, 1);

      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();

      expect(find.text('Voir moins'), findsOneWidget);
      final deplie = tester.widget<Text>(find.text(longDescription));
      expect(deplie.maxLines, isNull);
    });

    testWidgets('ne propose rien sur un récit qui tient sur une ligne',
        (tester) async {
      when(() => service.getTimelineEvents(kRoomId))
          .thenAnswer((_) async => [_event(description: 'Trois jours.')]);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Trois jours.'), findsOneWidget);
      expect(find.text('Voir plus'), findsNothing);
    });
  });

  group('vue MJ', () {
    testWidgets('ouvre l\'éditeur sur la place suivante de la frise',
        (tester) async {
      when(() => service.getTimelineEvents(kRoomId)).thenAnswer(
        (_) async => [
          _event(position: 0),
          _event(id: 'event-2', title: 'La trahison', position: 4),
        ],
      );

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.text('Évènement'));
      await tester.pumpAndSettle();

      final editor = tester.widget<TimelineEventEditorPage>(
        find.byType(TimelineEventEditorPage),
      );
      expect(editor.event, isNull);
      // Le maximum des positions + 1, et non le nombre d'évènements : après
      // des suppressions, repartir du compte réinsèrerait au milieu.
      expect(editor.nextPosition, 5);
    });

    testWidgets('ouvre un évènement existant dans l\'éditeur', (tester) async {
      when(() => service.getTimelineEvents(kRoomId))
          .thenAnswer((_) async => [_event()]);

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur « Le siège de Valmorne »'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier l\'évènement'), findsOneWidget);

      // La frise reste montée sous la route poussée : son titre est toujours
      // dans l'arbre, et le chercher par son texte ne prouverait rien. C'est
      // l'évènement transmis à l'éditeur qui fait foi.
      final editor = tester.widget<TimelineEventEditorPage>(
        find.byType(TimelineEventEditorPage),
      );
      expect(editor.event?['id'], 'event-1');
      expect(
        find.widgetWithText(TextField, 'Le siège de Valmorne'),
        findsOneWidget,
      );
    });

    testWidgets('annonce la visibilité de chaque évènement', (tester) async {
      when(() => service.getTimelineEvents(kRoomId)).thenAnswer(
        (_) async => [
          _event(),
          _event(id: 'event-2', title: 'La trahison', visibleTo: const []),
          _event(id: 'event-3', title: 'Le pacte', visibleTo: [kPlayerId]),
        ],
      );

      await pumpAs(tester, kMjId, 'mj');

      expect(find.bySemanticsLabel('Visibilité : Toute la table'), findsOneWidget);
      expect(find.bySemanticsLabel('Visibilité : Vous seul'), findsOneWidget);
      expect(find.bySemanticsLabel('Visibilité : 1 joueur'), findsOneWidget);
    });

    testWidgets('descend un évènement et n\'écrit que les places changées',
        (tester) async {
      when(() => service.getTimelineEvents(kRoomId)).thenAnswer(
        (_) async => [
          _event(id: 'event-1', title: 'Premier', position: 0),
          _event(id: 'event-2', title: 'Deuxième', position: 1),
          _event(id: 'event-3', title: 'Troisième', position: 2),
        ],
      );
      when(() => service.updateTimelinePositions(any()))
          .thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur « Premier »'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descendre'));
      await tester.pumpAndSettle();

      // « Troisième » n'a pas bougé : sa position ne doit pas être réécrite.
      verify(() => service.updateTimelinePositions({
            'event-2': 0,
            'event-1': 1,
          })).called(1);
    });

    testWidgets('ne propose pas de monter le premier évènement',
        (tester) async {
      when(() => service.getTimelineEvents(kRoomId)).thenAnswer(
        (_) async => [
          _event(id: 'event-1', title: 'Premier', position: 0),
          _event(id: 'event-2', title: 'Deuxième', position: 1),
        ],
      );

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur « Premier »'));
      await tester.pumpAndSettle();

      final monter = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Monter'),
      );
      expect(monter.enabled, isFalse);

      final descendre = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Descendre'),
      );
      expect(descendre.enabled, isTrue);
    });

    testWidgets('supprime un évènement après confirmation et recharge',
        (tester) async {
      when(() => service.getTimelineEvents(kRoomId))
          .thenAnswer((_) async => [_event()]);
      when(() => service.deleteTimelineEvent('event-1'))
          .thenAnswer((_) async {});

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur « Le siège de Valmorne »'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer « Le siège de Valmorne » ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      verify(() => service.deleteTimelineEvent('event-1')).called(1);
      // Une fois au montage, une fois après la suppression.
      verify(() => service.getTimelineEvents(kRoomId)).called(2);
    });

    testWidgets('ne supprime rien si on annule', (tester) async {
      when(() => service.getTimelineEvents(kRoomId))
          .thenAnswer((_) async => [_event()]);

      await pumpAs(tester, kMjId, 'mj');

      await tester.tap(find.byTooltip('Actions sur « Le siège de Valmorne »'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => service.deleteTimelineEvent(any()));
    });

    testWidgets('annonce une frise vide comme une invitation à l\'écrire',
        (tester) async {
      await pumpAs(tester, kMjId, 'mj');

      expect(
        find.text('La frise est vide. Ajoutez le premier évènement.'),
        findsOneWidget,
      );
    });
  });

  group('vue joueur', () {
    testWidgets('lit la frise sans aucune prise dessus', (tester) async {
      when(() => service.getTimelineEvents(kRoomId))
          .thenAnswer((_) async => [_event()]);

      await pumpAs(tester, kPlayerId, 'player');

      expect(find.text('Le siège de Valmorne'), findsOneWidget);

      // Ni création, ni menu d'actions, ni indication de visibilité : ce que
      // le joueur voit lui est ouvert, la nuance ne le concerne pas.
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Actions sur « Le siège de Valmorne »'), findsNothing);
      expect(find.bySemanticsLabel('Visibilité : Toute la table'), findsNothing);
      expect(
        find.text(
          'L\'histoire de la campagne, telle que votre maître du jeu la raconte.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('voit un message quand la frise est vide', (tester) async {
      await pumpAs(tester, kPlayerId, 'player');

      expect(
        find.text('Le maître du jeu n\'a pas encore écrit la frise.'),
        findsOneWidget,
      );
    });
  });
}
