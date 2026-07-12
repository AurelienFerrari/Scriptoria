import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';

void main() {
  testWidgets('RoomShell affiche la page Accueil par défaut et change de page au tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomShell(roomId: 'demo')));

    // Onglet 0 (Accueil) : RoomHomePage("Salle du Dragon") par défaut.
    expect(find.text('Salle du Dragon'), findsWidgets);

    // Onglet 3 : Chat.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Chat de la room'), findsOneWidget);

    // Onglet 4 : Paramètres de la room.
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres de la Room'), findsOneWidget);
  });
}
