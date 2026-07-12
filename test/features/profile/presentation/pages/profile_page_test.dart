import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/profile/presentation/pages/profile_page.dart';

import '../../../../helpers/mock_supabase_service.dart';

final _testUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {'display_name': 'Aurélien', 'username': 'aurelien'},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: 'aurelien@scriptoria.fr',
);

Widget _wrap(AuthProvider authProvider) {
  return ChangeNotifierProvider.value(
    value: authProvider,
    child: MaterialApp(
      home: const ProfilePage(),
      routes: {'/login': (context) => const Scaffold(body: Text('LoginPageMarker'))},
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

  testWidgets('ProfilePage affiche un indicateur de chargement puis le profil venant de la table users', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
    when(() => mockSupabaseService.getUserProfile('user-1')).thenAnswer(
      (_) async => {
        'username': 'aurelien_gm',
        'email': 'aurelien@scriptoria.fr',
        'display_name': 'Aurélien MJ',
        'bio': 'Maître du jeu depuis 10 ans',
      },
    );

    await tester.pumpWidget(_wrap(authProvider));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('aurelien_gm'), findsOneWidget);
    expect(find.text('aurelien@scriptoria.fr'), findsOneWidget);
    expect(find.text('Maître du jeu depuis 10 ans'), findsOneWidget);
  });

  testWidgets('ProfilePage retombe sur les données Supabase Auth si le profil users est introuvable', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
    when(() => mockSupabaseService.getUserProfile('user-1')).thenAnswer((_) async => null);

    await tester.pumpWidget(_wrap(authProvider));
    await tester.pumpAndSettle();

    expect(find.text('aurelien'), findsOneWidget);
    expect(find.text('aurelien@scriptoria.fr'), findsOneWidget);
    expect(find.text('Aucune bio'), findsOneWidget);
  });

  testWidgets('ProfilePage redirige vers /login si personne n\'est connecté', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);

    await tester.pumpWidget(_wrap(authProvider));
    await tester.pumpAndSettle();

    expect(find.text('LoginPageMarker'), findsOneWidget);
  });

  testWidgets('ProfilePage se déconnecte et redirige vers /login après confirmation', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
    when(() => mockSupabaseService.getUserProfile('user-1')).thenAnswer((_) async => null);
    when(() => mockSupabaseService.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(authProvider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Déconnexion'));
    await tester.tap(find.text('Déconnexion'));
    await tester.pumpAndSettle();

    // La boîte de dialogue de confirmation contient 2 TextButton : "Annuler" et "Déconnexion".
    await tester.tap(find.byType(TextButton).at(1));
    await tester.pumpAndSettle();

    verify(() => mockSupabaseService.signOut()).called(1);
    expect(find.text('LoginPageMarker'), findsOneWidget);
  });
}
