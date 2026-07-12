import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/register_page.dart';

Widget _wrapWithProviders(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('RegisterPage affiche le titre, les champs et le bouton d\'inscription', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithProviders(const RegisterPage()));

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.text('S\'inscrire'), findsOneWidget);
  });

  testWidgets('RegisterPage refuse l\'inscription si les champs sont vides', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithProviders(const RegisterPage()));

    final button = find.widgetWithText(ElevatedButton, 'S\'inscrire');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
  });
}
