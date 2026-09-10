import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/notes/room_note_editor_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/room_harness.dart';

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    Map<String, dynamic>? note,
    String? initialTitle,
    String? initialContent,
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
        child: RoomNoteEditorPage(
          note: note,
          initialTitle: initialTitle,
          initialContent: initialContent,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('crée une note', (tester) async {
    when(() => service.createRoomNote(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          title: any(named: 'title'),
          contentMd: any(named: 'contentMd'),
        )).thenAnswer((_) async => {'id': 'note-1'});

    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Le traître');
    await tester.enterText(find.byType(TextField).last, '# Chapitre 1');
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();

    verify(() => service.createRoomNote(
          campaignId: kRoomId,
          authorId: kMjId,
          title: 'Le traître',
          contentMd: '# Chapitre 1',
        )).called(1);
  });

  testWidgets('met à jour une note existante', (tester) async {
    when(() => service.updateRoomNote(
          noteId: any(named: 'noteId'),
          title: any(named: 'title'),
          contentMd: any(named: 'contentMd'),
        )).thenAnswer((_) async {});

    await pumpEditor(tester, note: {
      'id': 'note-1',
      'title': 'Ancien titre',
      'content_md': 'Ancien contenu',
    });

    expect(find.text('Ancien titre'), findsOneWidget);
    expect(find.text('Ancien contenu'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Nouveau titre');
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();

    verify(() => service.updateRoomNote(
          noteId: 'note-1',
          title: 'Nouveau titre',
          contentMd: 'Ancien contenu',
        )).called(1);
  });

  testWidgets('refuse d\'enregistrer une note sans titre', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).last, 'Du contenu');
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Donnez un titre à la note.'), findsOneWidget);
    verifyNever(() => service.createRoomNote(
          campaignId: any(named: 'campaignId'),
          authorId: any(named: 'authorId'),
          title: any(named: 'title'),
          contentMd: any(named: 'contentMd'),
        ));
  });

  testWidgets('bascule entre saisie et aperçu rendu', (tester) async {
    await pumpEditor(tester, initialContent: '# Titre\n\nDu **gras**.');

    // En saisie : le Markdown brut est dans un champ de texte.
    expect(find.text('# Titre\n\nDu **gras**.'), findsOneWidget);
    expect(find.byType(Markdown), findsNothing);

    await tester.tap(find.byTooltip('Aperçu'));
    await tester.pumpAndSettle();

    // En aperçu : le Markdown est rendu, la source n'est plus affichée telle
    // quelle.
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.text('# Titre\n\nDu **gras**.'), findsNothing);

    await tester.tap(find.byTooltip('Revenir à la saisie'));
    await tester.pumpAndSettle();

    expect(find.byType(Markdown), findsNothing);
  });

  testWidgets('démarre sur le contenu d\'un fichier importé', (tester) async {
    await pumpEditor(
      tester,
      initialTitle: 'scenario-1',
      initialContent: '## Acte I',
    );

    expect(find.text('scenario-1'), findsOneWidget);
    expect(find.text('## Acte I'), findsOneWidget);
  });

  testWidgets('l\'aperçu d\'une note vide le dit', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Aperçu'));
    await tester.pumpAndSettle();

    expect(find.text('Rien à afficher pour l\'instant.'), findsOneWidget);
  });
}
