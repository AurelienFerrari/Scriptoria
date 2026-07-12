import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/room_map_page.dart';
import 'package:scriptoria/features/room/presentation/room_players_page.dart';
import 'package:scriptoria/features/room/presentation/room_settings_page.dart';

void main() {
  testWidgets('RoomMapPage affiche son texte', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomMapPage()));
    expect(find.text('Carte de la room'), findsOneWidget);
  });

  testWidgets('RoomPlayersPage affiche son texte', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomPlayersPage()));
    expect(find.text('Joueurs de la room'), findsOneWidget);
  });

  testWidgets('RoomSettingsPage affiche les options de la room', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoomSettingsPage()));

    expect(find.text('Paramètres de la Room'), findsOneWidget);
    expect(find.text('Nom de la room'), findsOneWidget);
    expect(find.text('Room privée'), findsOneWidget);
    expect(find.text('Supprimer la room'), findsOneWidget);
  });
}
