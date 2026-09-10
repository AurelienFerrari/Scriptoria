import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/mock_supabase_service.dart';

final _testUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: 'aurelien@scriptoria.fr',
);

Widget _wrap(AuthProvider authProvider) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(
      home: const SettingsPage(),
      routes: {
        '/login': (context) => const Scaffold(body: Text('LoginPageMarker')),
      },
    ),
  );
}

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    when(() => service.getCurrentUser()).thenReturn(_testUser);
  });

  testWidgets('n\'affiche que les actions de compte réellement disponibles',
      (tester) async {
    await tester.pumpWidget(_wrap(auth));

    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Connecté avec aurelien@scriptoria.fr'), findsOneWidget);
    expect(find.text('Changer le mot de passe'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    // L'écran se contentait auparavant d'afficher son propre nom.
    expect(find.text('Page Paramètres'), findsNothing);
  });

  testWidgets('change le mot de passe', (tester) async {
    when(() => service.updatePassword(any())).thenAnswer(
      (_) async => UserResponse.fromJson({'user': null}),
    );

    await tester.pumpWidget(_wrap(auth));

    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'motdepasse123');
    await tester.enterText(find.byType(TextField).last, 'motdepasse123');
    await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    verify(() => service.updatePassword('motdepasse123')).called(1);
    expect(find.text('Mot de passe modifié'), findsOneWidget);
  });

  testWidgets('refuse un mot de passe trop court', (tester) async {
    await tester.pumpWidget(_wrap(auth));

    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'court');
    await tester.enterText(find.byType(TextField).last, 'court');
    await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    // Même règle qu'à l'inscription : un mot de passe accepté ici et refusé
    // là serait incompréhensible.
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );
    verifyNever(() => service.updatePassword(any()));
  });

  testWidgets('refuse deux saisies différentes', (tester) async {
    await tester.pumpWidget(_wrap(auth));

    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'motdepasse123');
    await tester.enterText(find.byType(TextField).last, 'motdepasse456');
    await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
    verifyNever(() => service.updatePassword(any()));
  });

  testWidgets('se déconnecte et revient à la connexion après confirmation',
      (tester) async {
    when(() => service.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(auth));

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.text('Se déconnecter ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Déconnexion'));
    await tester.pumpAndSettle();

    verify(() => service.signOut()).called(1);
    expect(find.text('LoginPageMarker'), findsOneWidget);
  });

  testWidgets('ne déconnecte pas si on annule', (tester) async {
    await tester.pumpWidget(_wrap(auth));

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    verifyNever(() => service.signOut());
  });
}
