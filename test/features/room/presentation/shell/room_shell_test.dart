import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';

import '../../../../helpers/mock_supabase_service.dart';

Widget _wrap(AuthProvider authProvider, String roomId) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(home: RoomShell(roomId: roomId)),
  );
}

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
  });

  testWidgets('RoomShell affiche les vraies données de la room et change de page au tap', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCampaignById('campaign-1')).thenAnswer(
      (_) async => {
        'id': 'campaign-1',
        'title': 'Mystères de l\'Ombre',
        'description': 'Une enquête dans les bas-fonds de la ville.',
        'icon_url': null,
        'created_at': '2026-07-14T10:32:00Z',
        'updated_at': null,
      },
    );

    await tester.pumpWidget(_wrap(authProvider, 'campaign-1'));
    await tester.pumpAndSettle();

    // Les vraies données de la campagne sont affichées, pas le contenu de démo.
    expect(find.text('Mystères de l\'Ombre'), findsWidgets);
    expect(find.text('Une enquête dans les bas-fonds de la ville.'), findsOneWidget);
    expect(find.text('Salle du Dragon'), findsNothing);

    // Onglet 3 : Chat.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Chat de la room'), findsOneWidget);

    // Onglet 4 : Paramètres de la room.
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres de la Room'), findsOneWidget);
  });

  testWidgets('RoomShell affiche un message si la room est introuvable', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCampaignById('inconnue')).thenAnswer((_) async => null);

    await tester.pumpWidget(_wrap(authProvider, 'inconnue'));
    await tester.pumpAndSettle();

    expect(find.text("Cette room n'existe pas ou plus."), findsOneWidget);
  });
}
