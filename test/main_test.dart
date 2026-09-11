import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/login_page.dart';
import 'package:scriptoria/features/auth/presentation/pages/register_page.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';
import 'package:scriptoria/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:scriptoria/main.dart';
import 'package:scriptoria/ui/app_frame.dart';

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
    when(() => mockSupabaseService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

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
    stubHomeScreen(mockSupabaseService);
    when(() => mockSupabaseService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(supabaseService: mockSupabaseService),
        child: const MyApp(),
      ),
    );

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('MyApp résout la route nommée /register', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);
    when(() => mockSupabaseService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

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
  });

  testWidgets('MyApp résout la route nommée /forgot-password', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);
    when(() => mockSupabaseService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(supabaseService: mockSupabaseService),
        child: const MyApp(),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // La route `/settings` a disparu avec son écran : ses deux actions de
    // compte sont passées sur la page de profil.
    navigator.pushNamed('/forgot-password');
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
  });

  testWidgets('MyApp écarte ses écrans de l\'encoche et des boutons', (
    WidgetTester tester,
  ) async {
    final mockSupabaseService = MockSupabaseService();
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);
    when(() => mockSupabaseService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(supabaseService: mockSupabaseService),
        child: const MyApp(),
      ),
    );

    // L'audit en paysage monte ses écrans avec ce même cadre : c'est ce test
    // qui garantit que l'app, elle, s'en sert vraiment.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.builder, appFrame);
  });
}
