import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';
import 'package:scriptoria/features/room/presentation/room_settings_page.dart';

import '../../../helpers/mock_supabase_service.dart';

Widget _wrap(AuthProvider authProvider) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(
      home: const RoomSettingsPage(roomId: 'campaign-1', isCreator: true),
      routes: {'/home': (context) => const HomePage()},
    ),
  );
}

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
  });

  testWidgets("RoomSettingsPage n'affiche pas le bouton supprimer pour un non-créateur", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(
          home: RoomSettingsPage(roomId: 'campaign-1', isCreator: false),
        ),
      ),
    );

    expect(find.text('Supprimer la room'), findsNothing);
  });

  testWidgets('RoomSettingsPage annule la suppression si on ne confirme pas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(authProvider));

    await tester.tap(find.text('Supprimer la room'));
    await tester.pumpAndSettle();
    expect(find.text('Cette action est irréversible.'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    verifyNever(() => mockSupabaseService.deleteCampaign(any()));
    expect(find.text('Paramètres de la Room'), findsOneWidget);
  });

  testWidgets('RoomSettingsPage supprime la room et revient à l\'accueil après confirmation', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.deleteCampaign('campaign-1')).thenAnswer((_) async {});
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);

    await tester.pumpWidget(_wrap(authProvider));

    await tester.tap(find.text('Supprimer la room'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    verify(() => mockSupabaseService.deleteCampaign('campaign-1')).called(1);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
