import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/login_page.dart';

Widget _wrapWithProviders(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('LoginPage affiche le titre et les champs de connexion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithProviders(const LoginPage()));

    expect(find.text('Scriptoria'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('LoginPage : le champ email a un label persistant et le bouton œil un nom accessible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithProviders(const LoginPage()));

    expect(find.text('Email'), findsOneWidget);
    expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
  });

  testWidgets('LoginPage refuse la connexion si les champs sont vides', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithProviders(const LoginPage()));

    final button = find.widgetWithText(ElevatedButton, 'Se connecter');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Veuillez remplir tous les champs'), findsOneWidget);
  });
}
