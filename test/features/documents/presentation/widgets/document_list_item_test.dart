import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/documents/presentation/widgets/document_list_item.dart';

void main() {
  testWidgets('DocumentListItem affiche titre, sous-titre, date et déclenche onTap', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentListItem(
            title: 'Carte du Royaume',
            subtitle: 'Mystères de l\'Ombre',
            lastModified: 'il y a 1 jour',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Carte du Royaume'), findsOneWidget);
    expect(find.text('Mystères de l\'Ombre'), findsOneWidget);
    expect(find.text('il y a 1 jour'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byType(DocumentListItem));
    expect(tapped, isTrue);
  });
}
