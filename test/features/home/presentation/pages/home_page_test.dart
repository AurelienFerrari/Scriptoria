import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/home/presentation/pages/home_page.dart';

void main() {
  testWidgets('HomePage affiche les sections, les campagnes et les documents', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Campagnes en cours'), findsOneWidget);
    expect(find.text('Mystères de l\'Ombre'), findsOneWidget);
    // "La Quête du Dragon" apparaît aussi en sous-titre d'un document.
    expect(find.text('La Quête du Dragon'), findsNWidgets(2));
    expect(find.text('Derniers documents modifiés'), findsOneWidget);
    expect(find.text('Carte du Royaume'), findsOneWidget);
    expect(find.text('Personnages Importants'), findsOneWidget);
    expect(find.text('Créer une room'), findsOneWidget);
    expect(find.text('Rejoindre une room'), findsOneWidget);
  });
}
