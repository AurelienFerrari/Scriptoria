import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/campaigns/presentation/widgets/campaign_card.dart';

void main() {
  testWidgets('CampaignCard affiche le titre, la mise à jour et déclenche onTap', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'Mystères de l\'Ombre',
            lastUpdate: 'il y a 3 h',
            imageUrl: 'assets/images/mystery.png',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Mystères de l\'Ombre'), findsOneWidget);
    // Le libellé annonçait « MJ : » suivi d'une date de mise à jour, vestige
    // d'un ancien contenu de démonstration.
    expect(find.text('Mise à jour : il y a 3 h'), findsOneWidget);

    await tester.tap(find.byType(CampaignCard));
    expect(tapped, isTrue);
  });

  testWidgets('CampaignCard affiche la description et les compteurs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'Mystères de l\'Ombre',
            description: 'Une enquête dans les bas-fonds de la ville.',
            lastUpdate: 'il y a 3 h',
            imageUrl: null,
            memberCount: 3,
            imageCount: 7,
            noteCount: 2,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('Une enquête dans les bas-fonds de la ville.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('3 membres'), findsOneWidget);
    expect(find.bySemanticsLabel('7 images'), findsOneWidget);
    expect(find.bySemanticsLabel('2 notes'), findsOneWidget);
  });

  testWidgets('CampaignCard tait les compteurs à zéro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'Room qui démarre',
            lastUpdate: 'il y a 1 h',
            imageUrl: null,
            memberCount: 1,
            imageCount: 0,
            // Un joueur reçoit toujours zéro note : la RLS ne lui en renvoie
            // aucune. La ligne doit disparaître d'elle-même.
            noteCount: 0,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('1 membre'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.description_outlined), findsNothing);
  });

  testWidgets('CampaignCard affiche le bouton optionnel actionButton quand fourni', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'La Quête du Dragon',
            lastUpdate: 'il y a 2 jours',
            imageUrl: 'assets/images/dragon.png',
            onTap: () {},
            actionButton: const Text('Quitter'),
          ),
        ),
      ),
    );

    expect(find.text('Quitter'), findsOneWidget);
  });

  testWidgets('CampaignCard affiche une icône de remplacement quand imageUrl est nul', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'Room sans icône',
            lastUpdate: 'il y a 1 h',
            imageUrl: null,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('CampaignCard affiche une icône réseau quand imageUrl est une URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'Room avec icône uploadée',
            lastUpdate: 'il y a 1 h',
            imageUrl: 'https://example.com/icon.png',
            onTap: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
  });
}
