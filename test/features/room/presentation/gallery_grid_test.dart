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

    // Le bouton d'ajout + 2 images = 3 tuiles au total dans la grille.
    expect(find.byType(GestureDetector), findsNWidgets(3));
  });
}
