import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/login_page.dart';
import 'package:scriptoria/features/auth/presentation/pages/register_page.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';
import 'package:scriptoria/main.dart';

import 'helpers/mock_supabase_service.dart';

final _testUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: 'aurelien@scriptoria.fr',
);

void main() {
  testWidgets('SupabaseInitErrorApp affiche le message d\'erreur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SupabaseInitErrorApp(error: Exception('Clés Supabase manquantes')));

    expect(find.text("Impossible d'initialiser Supabase"), findsOneWidget);
    expect(find.textContaining('Clés Supabase manquantes'), findsOneWidget);
  });

  testWidgets('MyApp affiche LoginPage quand personne n\'est connecté', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(supabaseService: mockSupabaseService),
        child: const MyApp(),
      ),
    );

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('MyApp affiche HomePage quand un utilisateur est connecté', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(supabaseService: mockSupabaseService),
        child: const MyApp(),
      ),
    );

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('MyApp résout les routes nommées /register et /room', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(supabaseService: mockSupabaseService),
        child: const MyApp(),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.pushNamed('/register');
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();

    navigator.pushNamed('/room');
    await tester.pumpAndSettle();
    expect(find.byType(RoomShell), findsOneWidget);
  });
}
