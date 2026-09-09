import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/gallery_grid.dart';

void main() {
  testWidgets('GalleryGrid affiche le bouton d\'ajout et déclenche onAddImage', (
    WidgetTester tester,
  ) async {
    var addCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryGrid(
            images: const [],
            onAddImage: () => addCalled = true,
            onDeleteImage: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.bySemanticsLabel('Ajouter une image'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(addCalled, isTrue);
  });

  testWidgets('GalleryGrid affiche une image par entrée de la liste', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryGrid(
            images: const [
              GalleryImage.asset('assets/images/dragon.png'),
              GalleryImage.asset('assets/images/mystery.png'),
            ],
            onAddImage: () {},
            onDeleteImage: (_) {},
          ),
        ),
      ),
    );

    // Chaque vignette est annoncée par son propre nom accessible. Compter les
    // GestureDetector serait fragile : les boutons de la tuile en contiennent
    // eux aussi.
    expect(find.bySemanticsLabel('Ouvrir l\'image 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Ouvrir l\'image 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Ajouter une image'), findsOneWidget);
  });

  testWidgets('GalleryGrid n\'offre aucune action en lecture seule', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryGrid(
            images: [GalleryImage.asset('assets/images/dragon.png')],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Ouvrir l\'image 1'), findsOneWidget);
    expect(find.byTooltip('Actions sur l\'image 1'), findsNothing);
    expect(find.bySemanticsLabel('Ajouter une image'), findsNothing);
  });

  testWidgets('GalleryGrid ouvre les actions d\'une image depuis la grille', (
    WidgetTester tester,
  ) async {
    int? visibilityIndex;
    int? deleteIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryGrid(
            images: const [
              GalleryImage.asset(
                'assets/images/dragon.png',
                visibility: GalleryVisibility.nobody,
              ),
            ],
            onDeleteImage: (index) => deleteIndex = index,
            onEditVisibility: (index) => visibilityIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Actions sur l\'image 1'));
    await tester.pumpAndSettle();

    // L'état courant est rappelé sous l'entrée, pour ne pas avoir à ouvrir la
    // boîte de dialogue rien que pour le consulter.
    expect(find.text('Masquée'), findsOneWidget);

    await tester.tap(find.text('Visibilité'));
    await tester.pumpAndSettle();
    expect(visibilityIndex, 0);

    await tester.tap(find.byTooltip('Actions sur l\'image 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(deleteIndex, 0);
  });

  testWidgets('GalleryGrid signale la visibilité de chaque image', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryGrid(
            images: const [
              GalleryImage.asset(
                'assets/images/dragon.png',
                visibility: GalleryVisibility.everyone,
              ),
              GalleryImage.asset(
                'assets/images/mystery.png',
                visibility: GalleryVisibility.restricted,
              ),
            ],
            onEditVisibility: (_) {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Visibilité : Tous les joueurs'), findsOneWidget);
    expect(find.bySemanticsLabel('Visibilité : Joueurs choisis'), findsOneWidget);
  });
}
