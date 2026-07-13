import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';

import '../../helpers/mock_supabase_service.dart';

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
  });

  test('isLoggedIn est false quand SupabaseService ne renvoie aucun utilisateur', () {
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(null);

    expect(authProvider.isLoggedIn, isFalse);
    expect(authProvider.currentUser, isNull);
  });

  test('signIn délègue à SupabaseService et notifie les écouteurs', () async {
    when(
      () => mockSupabaseService.signIn(
        email: 'demo@scriptoria.fr',
        password: 'motdepasse123',
      ),
    ).thenAnswer((_) async => AuthResponse());

    var notified = false;
    authProvider.addListener(() => notified = true);

    await authProvider.signIn(email: 'demo@scriptoria.fr', password: 'motdepasse123');

    verify(
      () => mockSupabaseService.signIn(
        email: 'demo@scriptoria.fr',
        password: 'motdepasse123',
      ),
    ).called(1);
    expect(notified, isTrue);
  });

  test('signUp délègue à SupabaseService et notifie les écouteurs', () async {
    when(
      () => mockSupabaseService.signUp(
        email: 'demo@scriptoria.fr',
        password: 'motdepasse123',
        username: 'demo',
        displayName: 'Demo',
      ),
    ).thenAnswer((_) async => AuthResponse());

    var notified = false;
    authProvider.addListener(() => notified = true);

    await authProvider.signUp(
      email: 'demo@scriptoria.fr',
      password: 'motdepasse123',
      username: 'demo',
      displayName: 'Demo',
    );

    verify(
      () => mockSupabaseService.signUp(
        email: 'demo@scriptoria.fr',
        password: 'motdepasse123',
        username: 'demo',
        displayName: 'Demo',
      ),
    ).called(1);
    expect(notified, isTrue);
  });

  test('signOut délègue à SupabaseService et notifie les écouteurs', () async {
    when(() => mockSupabaseService.signOut()).thenAnswer((_) async {});

    var notified = false;
    authProvider.addListener(() => notified = true);

    await authProvider.signOut();

    verify(() => mockSupabaseService.signOut()).called(1);
    expect(notified, isTrue);
  });

  test('getUserProfile délègue à SupabaseService', () async {
    when(
      () => mockSupabaseService.getUserProfile('user-1'),
    ).thenAnswer((_) async => {'username': 'demo'});

    final profile = await authProvider.getUserProfile('user-1');

    expect(profile, {'username': 'demo'});
    verify(() => mockSupabaseService.getUserProfile('user-1')).called(1);
  });

  test('resetPassword délègue à SupabaseService', () async {
    when(() => mockSupabaseService.resetPassword('demo@scriptoria.fr')).thenAnswer((_) async {});

    await authProvider.resetPassword('demo@scriptoria.fr');

    verify(() => mockSupabaseService.resetPassword('demo@scriptoria.fr')).called(1);
  });

  test('createCampaign délègue à SupabaseService', () async {
    when(
      () => mockSupabaseService.createCampaign(
        creatorId: 'user-1',
        title: 'Ma room',
        description: 'Une description',
        iconUrl: 'assets/images/dragon.png',
        maxPlayers: 4,
        joinCode: 'ABC123',
      ),
    ).thenAnswer((_) async => {'id': 'campaign-1'});

    final campaign = await authProvider.createCampaign(
      creatorId: 'user-1',
      title: 'Ma room',
      description: 'Une description',
      iconUrl: 'assets/images/dragon.png',
      maxPlayers: 4,
      joinCode: 'ABC123',
    );

    expect(campaign, {'id': 'campaign-1'});
  });

  test('getCampaignByJoinCode délègue à SupabaseService', () async {
    when(
      () => mockSupabaseService.getCampaignByJoinCode('ABC123'),
    ).thenAnswer((_) async => {'id': 'campaign-1'});

    final campaign = await authProvider.getCampaignByJoinCode('ABC123');

    expect(campaign, {'id': 'campaign-1'});
  });
}
