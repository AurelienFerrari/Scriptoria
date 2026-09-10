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
      routes: {
        '/login': (context) => const Scaffold(body: Text('LoginPageMarker')),
      },
    ),
  );
}

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
    when(() => mockSupabaseService.getVisibleCampaigns(any()))
        .thenAnswer((_) async => []);
  });

  testWidgets(
    'affiche un indicateur de chargement puis le profil venant de la table users',
    (WidgetTester tester) async {
      when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
      when(() => mockSupabaseService.getUserProfile('user-1')).thenAnswer(
        (_) async => {
          'username': 'aurelien_gm',
          'email': 'aurelien@scriptoria.fr',
          'display_name': 'Aurélien MJ',
          'bio': 'Maître du jeu depuis 10 ans',
          'created_at': '2024-01-01T00:00:00Z',
        },
      );

      await tester.pumpWidget(_wrap(authProvider));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Aurélien MJ'), findsOneWidget);
      expect(find.text('@aurelien_gm'), findsOneWidget);
      expect(find.text('aurelien@scriptoria.fr'), findsOneWidget);
      expect(find.text('Maître du jeu depuis 10 ans'), findsOneWidget);
    },
  );

  testWidgets(
    'retombe sur les données Supabase Auth si le profil users est introuvable',
    (WidgetTester tester) async {
      when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
      when(() => mockSupabaseService.getUserProfile('user-1'))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Aurélien'), findsOneWidget);
      expect(find.text('@aurelien'), findsOneWidget);
      expect(find.text('aurelien@scriptoria.fr'), findsOneWidget);
      expect(find.text('Aucune bio pour l\'instant.'), findsOneWidget);
    },
  );

  testWidgets('redirige vers /login si personne n\'est connecté',
      (WidgetTester tester) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);

    await tester.pumpWidget(_wrap(authProvider));
    await tester.pumpAndSettle();

    expect(find.text('LoginPageMarker'), findsOneWidget);
  });

  testWidgets('compte les rooms de l\'utilisateur, et rien d\'autre',
      (WidgetTester tester) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
    when(() => mockSupabaseService.getUserProfile('user-1'))
        .thenAnswer((_) async => null);
    when(() => mockSupabaseService.getVisibleCampaigns('user-1'))
        .thenAnswer((_) async => [
              {'id': 'campaign-1'},
              {'id': 'campaign-2'},
            ]);

    await tester.pumpWidget(_wrap(authProvider));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('2 rooms'), findsOneWidget);

    // Les compteurs « Personnages » et « Sessions » ont disparu : aucun écran
    // ne crée de personnage et la notion de session n'existe nulle part. Ils
    // affichaient zéro depuis toujours.
    expect(find.text('Personnages'), findsNothing);
    expect(find.text('Sessions'), findsNothing);
  });

  testWidgets(
    'n\'affiche plus les campagnes, personnages et activités inventés',
    (WidgetTester tester) async {
      when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
      when(() => mockSupabaseService.getUserProfile('user-1'))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      for (final invente in [
        'Les Chroniques d\'Eldoria',
        'Station Omega-7',
        'Lunaéa',
        'Thorn',
        'Iris-7',
        'Session 1 - La Porte de Brume',
      ]) {
        expect(find.text(invente), findsNothing, reason: '$invente était codé en dur');
      }
    },
  );

  testWidgets('enregistre réellement une modification du profil',
      (WidgetTester tester) async {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
    when(() => mockSupabaseService.getUserProfile('user-1'))
        .thenAnswer((_) async => null);
    when(() => mockSupabaseService.updateUserProfile(
          userId: any(named: 'userId'),
          displayName: any(named: 'displayName'),
          bio: any(named: 'bio'),
          avatarUrl: any(named: 'avatarUrl'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(authProvider));
    await tester.pumpAndSettle();

    // Le bouton « Modifier le profil » ne faisait auparavant que changer une
    // icône : rien n'était jamais enregistré.
    await tester.tap(find.byTooltip('Modifier le profil'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Aurélien le Meneur');
    await tester.enterText(find.byType(TextField).last, 'Je mène depuis 10 ans.');
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();

    verify(() => mockSupabaseService.updateUserProfile(
          userId: 'user-1',
          displayName: 'Aurélien le Meneur',
          bio: 'Je mène depuis 10 ans.',
        )).called(1);

    expect(find.text('Aurélien le Meneur'), findsOneWidget);
    expect(find.text('Je mène depuis 10 ans.'), findsOneWidget);
  });

  group('actions de compte', () {
    setUp(() {
      when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
      when(() => mockSupabaseService.getUserProfile('user-1'))
          .thenAnswer((_) async => null);
    });

    testWidgets('sont sur cet écran, plus derrière un engrenage',
        (tester) async {
      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Changer le mot de passe'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(find.byTooltip('Paramètres'), findsNothing);
    });

    testWidgets('changent le mot de passe', (tester) async {
      when(() => mockSupabaseService.updatePassword(any())).thenAnswer(
        (_) async => UserResponse.fromJson({'user': null}),
      );

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changer le mot de passe'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'motdepasse123');
      await tester.enterText(find.byType(TextField).last, 'motdepasse123');
      await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      verify(() => mockSupabaseService.updatePassword('motdepasse123')).called(1);
      expect(find.text('Mot de passe modifié'), findsOneWidget);
    });

    testWidgets('refusent un mot de passe trop court', (tester) async {
      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

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
      verifyNever(() => mockSupabaseService.updatePassword(any()));
    });

    testWidgets('refusent deux saisies différentes', (tester) async {
      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changer le mot de passe'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'motdepasse123');
      await tester.enterText(find.byType(TextField).last, 'motdepasse456');
      await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
      verifyNever(() => mockSupabaseService.updatePassword(any()));
    });

    testWidgets('déconnectent après confirmation', (tester) async {
      when(() => mockSupabaseService.signOut()).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Déconnexion'));
      await tester.pumpAndSettle();

      verify(() => mockSupabaseService.signOut()).called(1);
      expect(find.text('LoginPageMarker'), findsOneWidget);
    });

    testWidgets('ne déconnectent pas si on annule', (tester) async {
      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => mockSupabaseService.signOut());
    });
  });
}
