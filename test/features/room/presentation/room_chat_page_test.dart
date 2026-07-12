import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/room_chat_page.dart';

void main() {
  testWidgets('RoomChatPage affiche les messages initiaux', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomChatPage()));

    expect(find.text('Chat de la room'), findsOneWidget);
    expect(find.text('Bienvenue dans le chat !'), findsOneWidget);
    expect(find.text('Salut à tous !'), findsOneWidget);
  });

  testWidgets('RoomChatPage ajoute un message envoyé à la liste', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomChatPage()));

    await tester.enterText(find.byType(TextField), 'Un nouveau message de test');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Un nouveau message de test'), findsOneWidget);
  });

  testWidgets('RoomChatPage ignore un message vide', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomChatPage()));

    // Chaque message est rendu dans un Align dédié : 3 messages initiaux.
    final initialCount = find.byType(Align).evaluate().length;

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(Align).evaluate().length, initialCount);
  });
}
