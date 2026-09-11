import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/outils/relations_page.dart';

// Ne restent ici que les outils encore à l'état d'ébauche. Chaque outil
// implémenté prend son propre fichier de test, où le rôle de celui qui regarde
// l'écran devient le sujet : voir `de_page_test.dart` et `frise_page_test.dart`.

void main() {
  testWidgets('RelationsPage affiche son titre', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RelationsPage()));
    expect(find.text('Relations'), findsOneWidget);
    expect(find.text('Fonctionnalité Relations à venir'), findsOneWidget);
  });
}
