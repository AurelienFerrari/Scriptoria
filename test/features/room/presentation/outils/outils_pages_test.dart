import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/room/presentation/outils/de_page.dart';
import 'package:scriptoria/features/room/presentation/outils/frise_page.dart';
import 'package:scriptoria/features/room/presentation/outils/relations_page.dart';

void main() {
  testWidgets('DePage affiche son titre', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DePage()));
    expect(find.text('Dé'), findsOneWidget);
    expect(find.text('Fonctionnalité Dé à venir'), findsOneWidget);
  });

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
