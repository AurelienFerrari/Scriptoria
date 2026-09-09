import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/outils/frise_page.dart';
import 'package:scriptoria/features/room/presentation/outils/relations_page.dart';

// `DePage` a son propre fichier de test depuis qu'elle est implémentée :
// voir `de_page_test.dart`.

void main() {
  testWidgets('FrisePage affiche son titre', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FrisePage()));
    expect(find.text('Frise'), findsOneWidget);
    expect(find.text('Fonctionnalité Frise à venir'), findsOneWidget);
  });

  testWidgets('RelationsPage affiche son titre', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RelationsPage()));
    expect(find.text('Relations'), findsOneWidget);
    expect(find.text('Fonctionnalité Relations à venir'), findsOneWidget);
  });
}
