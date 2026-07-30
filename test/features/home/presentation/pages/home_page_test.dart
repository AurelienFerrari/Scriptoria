import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/navigation/route_observer.dart';
import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/campaigns/presentation/widgets/campaign_card.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';

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
      navigatorObservers: [routeObserver],
      home: const HomePage(),
    ),
  );
}

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
  });

  testWidgets(
    'HomePage affiche une room par campagne créée ou rejointe par l\'utilisateur',
    (WidgetTester tester) async {
      when(() => mockSupabaseService.getVisibleCampaigns('user-1')).thenAnswer(
        (_) async => [
          {
            'id': 'campaign-1',
            'title': 'Mystères de l\'Ombre',
            'icon_url': 'assets/images/mystery.png',
            'created_at': '2026-07-14T10:32:00Z',
            'updated_at': null,
          },
        ],
      );
      when(() => mockSupabaseService.getCampaignById('campaign-1')).thenAnswer(
        (_) async => {
          'id': 'campaign-1',
          'title': 'Mystères de l\'Ombre',
          'icon_url': 'assets/images/mystery.png',
          'created_at': '2026-07-14T10:32:00Z',
          'updated_at': null,
        },
      );

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Accueil'), findsOneWidget);
      expect(find.text('Campagnes en cours'), findsOneWidget);
      expect(find.byType(CampaignCard), findsOneWidget);
      expect(find.text('Mystères de l\'Ombre'), findsWidgets);
      expect(find.text('Derniers documents modifiés'), findsOneWidget);
      expect(find.text('Créer une room'), findsOneWidget);
      expect(find.text('Rejoindre une room'), findsOneWidget);

      await tester.tap(find.byType(CampaignCard));
      await tester.pumpAndSettle();
      expect(find.byType(RoomShell), findsOneWidget);
    },
  );

  testWidgets(
    "HomePage n'affiche aucune room quand l'utilisateur n'en a ni créé ni rejoint",
    (WidgetTester tester) async {
      when(() => mockSupabaseService.getVisibleCampaigns('user-1'))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      expect(find.byType(CampaignCard), findsNothing);
      expect(
        find.text("Vous n'avez pas encore de room. Créez-en une ou rejoignez-en une avec un code."),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'HomePage recharge ses campagnes quand on revient dessus après avoir dépilé une route',
    (WidgetTester tester) async {
      var callCount = 0;
      when(() => mockSupabaseService.getVisibleCampaigns('user-1')).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return [];
        return [
          {
            'id': 'campaign-1',
            'title': 'Nouvelle room',
            'icon_url': 'assets/images/mystery.png',
            'created_at': '2026-07-14T10:32:00Z',
            'updated_at': null,
          },
        ];
      });

      await tester.pumpWidget(_wrap(authProvider));
      await tester.pumpAndSettle();

      expect(find.byType(CampaignCard), findsNothing);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Autre écran'))));
      await tester.pumpAndSettle();
      expect(find.text('Autre écran'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(CampaignCard), findsOneWidget);
      expect(find.text('Nouvelle room'), findsWidgets);
      verify(() => mockSupabaseService.getVisibleCampaigns('user-1')).called(2);
    },
  );

  testWidgets('HomePage : l\'avatar de profil a un nom accessible', (
    WidgetTester tester,
  ) async {
    when(() => mockSupabaseService.getVisibleCampaigns('user-1'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(authProvider));

    expect(find.bySemanticsLabel('Voir le profil'), findsOneWidget);
  });
}
