import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/home/room_join_page.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';

import '../../../../helpers/mock_supabase_service.dart';

Widget _wrap(AuthProvider authProvider) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(home: const RoomJoinPage()),
  );
}

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
  });

  testWidgets('RoomJoinPage affiche une erreur si le code est vide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(authProvider));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Veuillez entrer un code'), findsOneWidget);
  });

  testWidgets('RoomJoinPage affiche une erreur si le code ne correspond à aucune room', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCampaignByJoinCode('X7K2P9')).thenAnswer((_) async => null);

    await tester.pumpWidget(_wrap(authProvider));
    await tester.enterText(find.byType(TextFormField), 'x7k2p9');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Aucune room ne correspond à ce code.'), findsOneWidget);
  });

  testWidgets('RoomJoinPage rejoint la room quand le code est valide', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCampaignByJoinCode('X7K2P9')).thenAnswer(
      (_) async => {'id': 'campaign-1', 'title': 'Mystères de l\'Ombre'},
    );
    when(() => mockSupabaseService.getCampaignById('campaign-1')).thenAnswer(
      (_) async => {'id': 'campaign-1', 'title': 'Mystères de l\'Ombre'},
    );

    await tester.pumpWidget(_wrap(authProvider));
    await tester.enterText(find.byType(TextFormField), 'x7k2p9');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomShell), findsOneWidget);
  });
}
