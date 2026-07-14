import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/home/room_create_page.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';

import '../../../../helpers/mock_supabase_service.dart';

final _testUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: 'aurelien@scriptoria.fr',
);

void main() {
  testWidgets('RoomCreatePage affiche les erreurs de validation si le formulaire est vide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.pump();

    expect(find.text('Veuillez entrer un nom'), findsOneWidget);
    expect(find.text('Veuillez entrer une description'), findsOneWidget);
  });

  testWidgets('RoomCreatePage exige une icône même si les champs texte sont remplis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mystères de l\'Ombre');
    await tester.enterText(fields.at(1), 'Une ambiance mystérieuse');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.pump();

    expect(find.text('Sélectionne une icône !'), findsOneWidget);
  });

  testWidgets('RoomCreatePage : le sélecteur d\'icônes propose des icônes nommées', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));

    await tester.tap(find.byIcon(Icons.add_a_photo));
    await tester.pumpAndSettle();

    expect(find.text('Choisir une icône (PNG carré 96x96)'), findsOneWidget);
    expect(find.bySemanticsLabel('Icône Dragon'), findsOneWidget);
    expect(find.bySemanticsLabel('Icône Mystère'), findsOneWidget);
    expect(find.bySemanticsLabel('Importer une image depuis la galerie'), findsOneWidget);
  });

  testWidgets('RoomCreatePage crée réellement la room et navigue vers RoomShell', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    final authProvider = AuthProvider(supabaseService: mockSupabaseService);
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
    when(
      () => mockSupabaseService.createCampaign(
        creatorId: 'user-1',
        title: 'Mystères de l\'Ombre',
        description: 'Une ambiance mystérieuse',
        iconUrl: 'assets/images/dragon.png',
        maxPlayers: 4,
        joinCode: any(named: 'joinCode'),
      ),
    ).thenAnswer((_) async => {'id': 'campaign-1', 'title': 'Mystères de l\'Ombre'});
    when(() => mockSupabaseService.getCampaignById('campaign-1')).thenAnswer(
      (_) async => {'id': 'campaign-1', 'title': 'Mystères de l\'Ombre'},
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(home: RoomCreatePage()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mystères de l\'Ombre');
    await tester.enterText(fields.at(1), 'Une ambiance mystérieuse');

    await tester.tap(find.byIcon(Icons.add_a_photo));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Icône Dragon'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomShell), findsOneWidget);
  });
}
