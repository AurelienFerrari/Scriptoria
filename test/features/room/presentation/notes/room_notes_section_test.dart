import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/notes/room_note_editor_page.dart';
import 'package:scriptoria/features/room/presentation/notes/room_notes_section.dart';
import 'package:scriptoria/features/room/presentation/room_contents_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/network_image_stub.dart';
import '../../../../helpers/room_harness.dart';
import 'dart:io';

Map<String, dynamic> _note({
  String id = 'note-1',
  String title = 'Intrigue principale',
  String content = '# Le traître\n\nC\'est **Camille**.',
}) =>
    {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'title': title,
      'content_md': content,
      'created_at': '2026-09-10T09:00:00Z',
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
    when(() => service.getRoomNotes(kRoomId)).thenAnswer((_) async => []);
    when(() => service.getCampaignImages(kRoomId)).thenAnswer((_) async => []);
  });

  Future<void> pumpSection(WidgetTester tester) async {
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
        child: const Scaffold(
          body: SingleChildScrollView(child: RoomNotesSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('liste les notes de la room', (tester) async {
    when(() => service.getRoomNotes(kRoomId))
        .thenAnswer((_) async => [_note(), _note(id: 'note-2', title: 'PNJ')]);

    await pumpSection(tester);

    expect(find.text('Intrigue principale'), findsOneWidget);
    expect(find.text('PNJ'), findsOneWidget);
    expect(
      find.text('Visibles de vous seul. Les joueurs n\'y ont aucun accès.'),
      findsOneWidget,
    );
  });

  testWidgets('annonce une room sans note', (tester) async {
    await pumpSection(tester);

    expect(find.text('Aucune note pour l\'instant.'), findsOneWidget);
  });

  testWidgets('ouvre l\'éditeur vierge pour une nouvelle note', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Nouvelle note'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomNoteEditorPage), findsOneWidget);
    expect(find.text('Nouvelle note'), findsWidgets);
  });

  testWidgets('ouvre une note existante dans l\'éditeur', (tester) async {
    when(() => service.getRoomNotes(kRoomId)).thenAnswer((_) async => [_note()]);

    await pumpSection(tester);

    await tester.tap(find.text('Intrigue principale'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomNoteEditorPage), findsOneWidget);
    expect(find.text('Modifier la note'), findsOneWidget);
    // Le contenu Markdown est chargé tel quel dans la zone de saisie.
    expect(find.text('# Le traître\n\nC\'est **Camille**.'), findsOneWidget);
  });

  testWidgets('supprime une note après confirmation', (tester) async {
    when(() => service.getRoomNotes(kRoomId)).thenAnswer((_) async => [_note()]);
    when(() => service.deleteRoomNote('note-1')).thenAnswer((_) async {});

    await pumpSection(tester);

    await tester.tap(find.byTooltip('Supprimer « Intrigue principale »'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer « Intrigue principale » ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    verify(() => service.deleteRoomNote('note-1')).called(1);
    // Une fois au montage, une fois après la suppression.
    verify(() => service.getRoomNotes(kRoomId)).called(2);
  });

  testWidgets('ne supprime rien si on annule', (tester) async {
    when(() => service.getRoomNotes(kRoomId)).thenAnswer((_) async => [_note()]);

    await pumpSection(tester);

    await tester.tap(find.byTooltip('Supprimer « Intrigue principale »'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    verifyNever(() => service.deleteRoomNote(any()));
  });

  group('dans l\'onglet Contenus', () {
    Future<void> pumpContents(WidgetTester tester, String role) async {
      final room = await loadedRoomProvider(
        service: service,
        auth: auth,
        asUserId: role == 'mj' ? kMjId : kPlayerId,
        role: role,
      );
      await tester.pumpWidget(
        wrapRoomScreen(auth: auth, room: room, child: const RoomContentsPage()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('le MJ y trouve ses notes', (tester) async {
      when(() => service.getRoomNotes(kRoomId))
          .thenAnswer((_) async => [_note()]);

      await pumpContents(tester, 'mj');

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Intrigue principale'), findsOneWidget);
    });

    testWidgets(
      'un joueur ne voit aucune trace des notes, pas même une section vide',
      (tester) async {
        await pumpContents(tester, 'player');

        expect(find.text('Notes'), findsNothing);
        expect(find.text('Nouvelle note'), findsNothing);
        expect(find.text('Importer un .md'), findsNothing);
        // La base ne lui en renverrait aucune de toute façon : l'écran n'a
        // même pas à demander.
        verifyNever(() => service.getRoomNotes(any()));
      },
    );
  });
}
