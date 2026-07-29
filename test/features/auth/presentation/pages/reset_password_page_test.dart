import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/reset_password_page.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';

import '../../../../helpers/mock_supabase_service.dart';

Widget _wrap(AuthProvider authProvider) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(
      home: const ResetPasswordPage(),
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

  testWidgets('ResetPasswordPage refuse des champs vides', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(authProvider));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
  });

  testWidgets('ResetPasswordPage refuse des mots de passe qui ne correspondent pas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(authProvider));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'motdepasse1');
    await tester.enterText(fields.at(1), 'motdepasse2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });

  testWidgets('ResetPasswordPage refuse un mot de passe de moins de 8 caractères', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(authProvider));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'abc123');
    await tester.enterText(fields.at(1), 'abc123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pump();

    expect(find.text('Le mot de passe doit contenir au moins 8 caractères'), findsOneWidget);
  });

  testWidgets('ResetPasswordPage met à jour le mot de passe et revient à l\'accueil', (
    WidgetTester tester,
  ) async {
    final user = User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2024-01-01T00:00:00Z',
      email: 'demo@scriptoria.fr',
    );
    when(() => mockSupabaseService.updatePassword('nouveauMotDePasse1')).thenAnswer(
      (_) async => UserResponse.fromJson(user.toJson()),
    );
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(user);
    when(() => mockSupabaseService.getVisibleCampaigns('user-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(authProvider));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'nouveauMotDePasse1');
    await tester.enterText(fields.at(1), 'nouveauMotDePasse1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
    await tester.pumpAndSettle();

    verify(() => mockSupabaseService.updatePassword('nouveauMotDePasse1')).called(1);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
