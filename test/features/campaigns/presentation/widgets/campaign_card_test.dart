import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/features/campaigns/presentation/widgets/campaign_card.dart';

void main() {
  testWidgets('CampaignCard affiche le titre, le MJ et déclenche onTap', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'Mystères de l\'Ombre',
            lastUpdate: 'il y a 3 h',
            imageUrl: 'assets/images/mystery.png',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Mystères de l\'Ombre'), findsOneWidget);
    expect(find.text('MJ: il y a 3 h'), findsOneWidget);

    await tester.tap(find.byType(CampaignCard));
    expect(tapped, isTrue);
  });

  testWidgets('CampaignCard affiche le bouton optionnel actionButton quand fourni', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            title: 'La Quête du Dragon',
            lastUpdate: 'il y a 2 jours',
            imageUrl: 'assets/images/dragon.png',
            onTap: () {},
            actionButton: const Text('Quitter'),
          ),
        ),
      ),
    );

    expect(find.text('Quitter'), findsOneWidget);
  });
}
