import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/forgot_password_page.dart';

import '../../../../helpers/mock_supabase_service.dart';

Widget _wrap(AuthProvider authProvider) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(home: const ForgotPasswordPage()),
  );
}

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
  });

  testWidgets('ForgotPasswordPage refuse un email vide', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(authProvider));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Envoyer le lien'));
    await tester.pump();

    expect(find.text('Veuillez entrer votre email'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage confirme l\'envoi et appelle resetPassword', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.resetPassword('aurelien@scriptoria.fr')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(authProvider));
    await tester.enterText(find.byType(TextField), 'aurelien@scriptoria.fr');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Envoyer le lien'));
    await tester.pumpAndSettle();

    verify(() => mockSupabaseService.resetPassword('aurelien@scriptoria.fr')).called(1);
    expect(find.text('Email envoyé ! Vérifiez votre boîte de réception.'), findsOneWidget);
  });
}
