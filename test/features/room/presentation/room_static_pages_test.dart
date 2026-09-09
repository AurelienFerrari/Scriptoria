import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/room_map_page.dart';

// `RoomPlayersPage` a été remplacée par `RoomPlayersSection`, intégrée aux
// paramètres de la room : voir `room_settings_page_test.dart`, qui couvre
// aussi `RoomSettingsPage` depuis qu'elle dépend du RoomProvider.

void main() {
  testWidgets('RoomMapPage affiche son texte', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomMapPage()));
    expect(find.text('Carte de la room'), findsOneWidget);
  });
}
