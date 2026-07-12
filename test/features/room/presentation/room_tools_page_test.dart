import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/room_tools_page.dart';

void main() {
  testWidgets('RoomToolsPage affiche les 3 outils et navigue vers Dé au tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomToolsPage()));

    expect(find.text('Outils'), findsOneWidget);
    expect(find.text('Dé'), findsOneWidget);
    expect(find.text('Frise'), findsOneWidget);
    expect(find.text('Relations'), findsOneWidget);

    await tester.tap(find.text('Dé'));
    await tester.pumpAndSettle();

    expect(find.text('Fonctionnalité Dé à venir'), findsOneWidget);
  });
}
