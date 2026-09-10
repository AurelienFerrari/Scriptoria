import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/home/presentation/widgets/recent_activity_section.dart';

Widget _wrap(List<Map<String, dynamic>> activity, {void Function(String)? onOpen}) {
  return MaterialApp(
    home: Scaffold(
      body: RecentActivitySection(
        activity: activity,
        onOpenRoom: onOpen ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('disparaît complètement quand il n\'y a rien à montrer',
      (tester) async {
    await tester.pumpWidget(_wrap(const []));

    // Pas même un titre : une section « Activité récente » vide occuperait de
    // la place pour annoncer qu'il ne s'est rien passé.
    expect(find.text('Activité récente'), findsNothing);
  });

  testWidgets('liste les notes et les images avec leur room', (tester) async {
    await tester.pumpWidget(_wrap(const [
      {
        'kind': 'note',
        'id': 'note-1',
        'label': 'Le traître',
        'campaign_id': 'campaign-1',
        'campaign_title': 'Mystères de l\'Ombre',
        'at': '2026-09-10T10:00:00Z',
      },
      {
        'kind': 'image',
        'id': 'image-1',
        'label': 'Image partagée',
        'campaign_id': 'campaign-2',
        'campaign_title': 'La Quête du Dragon',
        'at': '2026-09-09T18:00:00Z',
      },
    ]));

    expect(find.text('Activité récente'), findsOneWidget);
    expect(find.text('Le traître'), findsOneWidget);
    expect(find.text('Image partagée'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.textContaining('Mystères de l\'Ombre'), findsOneWidget);
    expect(find.textContaining('La Quête du Dragon'), findsOneWidget);
  });

  testWidgets('chaque ligne ouvre la room concernée', (tester) async {
    String? opened;

    await tester.pumpWidget(_wrap(
      const [
        {
          'kind': 'note',
          'id': 'note-1',
          'label': 'Le traître',
          'campaign_id': 'campaign-1',
          'campaign_title': 'Mystères de l\'Ombre',
          'at': '2026-09-10T10:00:00Z',
        },
      ],
      onOpen: (id) => opened = id,
    ));

    await tester.tap(find.text('Le traître'));
    await tester.pumpAndSettle();

    expect(opened, 'campaign-1');
  });
}
