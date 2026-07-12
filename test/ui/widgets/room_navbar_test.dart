import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/ui/widgets/room_navbar.dart';

void main() {
  testWidgets('RoomNavbar affiche les 5 onglets et notifie onTap avec le bon index', (
    WidgetTester tester,
  ) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RoomNavbar(
            currentIndex: 0,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      ),
    );

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Contenus'), findsOneWidget);
    expect(find.text('Outils'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    expect(tappedIndex, 3);
  });
}
