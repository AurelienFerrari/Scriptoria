import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/home/room_create_page.dart';

void main() {
  testWidgets('RoomCreatePage affiche les erreurs de validation si le formulaire est vide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.pump();

    expect(find.text('Veuillez entrer un nom'), findsOneWidget);
    expect(find.text('Veuillez entrer une description'), findsOneWidget);
  });

  testWidgets('RoomCreatePage exige une icône même si les champs texte sont remplis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mystères de l\'Ombre');
    await tester.enterText(fields.at(1), 'Une ambiance mystérieuse');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.pump();

    expect(find.text('Sélectionne une icône !'), findsOneWidget);
  });

  testWidgets('RoomCreatePage : le sélecteur d\'icônes propose des icônes nommées', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));

    await tester.tap(find.byIcon(Icons.add_a_photo));
    await tester.pumpAndSettle();

    expect(find.text('Choisir une icône (PNG carré 96x96)'), findsOneWidget);
    expect(find.bySemanticsLabel('Icône Dragon'), findsOneWidget);
    expect(find.bySemanticsLabel('Icône Mystère'), findsOneWidget);
    expect(find.bySemanticsLabel('Importer une image depuis la galerie'), findsOneWidget);
  });
}
