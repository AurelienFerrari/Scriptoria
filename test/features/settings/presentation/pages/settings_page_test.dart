import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('SettingsPage affiche son titre', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Page Paramètres'), findsOneWidget);
  });
}
