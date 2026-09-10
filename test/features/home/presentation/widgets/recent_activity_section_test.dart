import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/home/presentation/widgets/recent_activity_section.dart';

import '../../../../helpers/network_image_stub.dart';

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

  testWidgets('une image est représentée par sa propre vignette', (tester) async {
    HttpOverrides.global = StubImageHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);

    await tester.pumpWidget(_wrap(const [
      {
        'kind': 'image',
        'id': 'image-1',
        'label': 'Image partagée',
        'url': 'https://exemple.test/carte.png',
        'campaign_id': 'campaign-1',
        'campaign_title': 'Mystères de l\'Ombre',
        'at': '2026-09-10T10:00:00Z',
      },
    ]));
    await tester.pumpAndSettle();

    // La vignette réelle remplace l'icône générique : c'est l'information la
    // plus utile qu'on puisse mettre à cet endroit.
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(find.byIcon(Icons.image_outlined), findsNothing);
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
