import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/room_home_page.dart';

void main() {
  testWidgets('RoomHomePage affiche le nom, la description et la date de mise à jour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RoomHomePage(
          roomName: 'Salle du Dragon',
          description: 'Bienvenue dans la salle du Dragon !',
          lastUpdate: 'Aujourd\'hui à 12:30',
        ),
      ),
    );

    expect(find.text('Salle du Dragon'), findsWidgets);
    expect(find.text('Bienvenue dans la salle du Dragon !'), findsOneWidget);
    expect(find.text('Dernière mise à jour'), findsOneWidget);
    expect(find.text('Aujourd\'hui à 12:30'), findsOneWidget);
  });
}
