import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/home/room_join_page.dart';

void main() {
  testWidgets('RoomJoinPage affiche une erreur si le code est vide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomJoinPage()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Veuillez entrer un code'), findsOneWidget);
  });

  testWidgets('RoomJoinPage accepte un code renseigné', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomJoinPage()));

    await tester.enterText(find.byType(TextFormField), '1234-ABCD');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Veuillez entrer un code'), findsNothing);
    expect(find.text('Bon code'), findsOneWidget);
  });
}
