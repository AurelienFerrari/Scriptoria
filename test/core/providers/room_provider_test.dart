import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/providers/room_provider.dart';

import '../../helpers/mock_supabase_service.dart';

final _testUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: 'aurelien@scriptoria.fr',
);

Map<String, dynamic> _campaign({String creatorId = 'user-1'}) => {
      'id': 'campaign-1',
      'creator_id': creatorId,
      'title': 'Mystères de l\'Ombre',
      'description': 'Une enquête dans les bas-fonds de la ville.',
      'icon_url': null,
      'join_code': 'X7K2P9',
      'created_at': '2026-07-14T10:32:00Z',
      'updated_at': null,
    };

void main() {
  late MockSupabaseService mockSupabaseService;
  late AuthProvider authProvider;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    authProvider = AuthProvider(supabaseService: mockSupabaseService);
    when(() => mockSupabaseService.getCurrentUser()).thenReturn(_testUser);
  });

  RoomProvider buildProvider() =>
      RoomProvider(auth: authProvider, roomId: 'campaign-1');

  group('roomRoleFromString', () {
    test('convertit les valeurs stockées en base', () {
      expect(roomRoleFromString('mj'), RoomRole.mj);
      expect(roomRoleFromString('player'), RoomRole.player);
    });

    test('retombe sur none pour une valeur absente ou inconnue', () {
      expect(roomRoleFromString(null), RoomRole.none);
      expect(roomRoleFromString('arbitre'), RoomRole.none);
    });
  });

  group('RoomProvider.load', () {
    test('reconnaît le MJ à partir de campaign_members', () async {
      when(() => mockSupabaseService.getCampaignById('campaign-1'))
          .thenAnswer((_) async => _campaign());
      when(
        () => mockSupabaseService.getMemberRole(
          campaignId: 'campaign-1',
          userId: 'user-1',
        ),
      ).thenAnswer((_) async => 'mj');

      final room = buildProvider();
      await room.load();

      expect(room.isLoading, isFalse);
      expect(room.exists, isTrue);
      expect(room.role, RoomRole.mj);
      expect(room.isMj, isTrue);
      expect(room.isMember, isTrue);
      expect(room.title, 'Mystères de l\'Ombre');
      expect(room.joinCode, 'X7K2P9');
    });

    test('un joueur est membre mais pas MJ', () async {
      when(() => mockSupabaseService.getCampaignById('campaign-1'))
          .thenAnswer((_) async => _campaign(creatorId: 'user-mj'));
      when(
        () => mockSupabaseService.getMemberRole(
          campaignId: 'campaign-1',
          userId: 'user-1',
        ),
      ).thenAnswer((_) async => 'player');

      final room = buildProvider();
      await room.load();

      expect(room.role, RoomRole.player);
      expect(room.isMj, isFalse);
      expect(room.isMember, isTrue);
    });

    test('un non-membre n\'a aucun rôle', () async {
      when(() => mockSupabaseService.getCampaignById('campaign-1'))
          .thenAnswer((_) async => _campaign(creatorId: 'user-mj'));
      when(
        () => mockSupabaseService.getMemberRole(
          campaignId: 'campaign-1',
          userId: 'user-1',
        ),
      ).thenAnswer((_) async => null);

      final room = buildProvider();
      await room.load();

      expect(room.role, RoomRole.none);
      expect(room.isMember, isFalse);
    });

    test(
      'le créateur reste MJ même si campaign_members ne le connaît pas '
      '(migration des rôles pas encore appliquée)',
      () async {
        when(() => mockSupabaseService.getCampaignById('campaign-1'))
            .thenAnswer((_) async => _campaign(creatorId: 'user-1'));
        when(
          () => mockSupabaseService.getMemberRole(
            campaignId: 'campaign-1',
            userId: 'user-1',
          ),
        ).thenAnswer((_) async => null);

        final room = buildProvider();
        await room.load();

        expect(room.isMj, isTrue);
      },
    );

    test('une room inexistante ne donne aucun rôle et n\'interroge pas les membres',
        () async {
      when(() => mockSupabaseService.getCampaignById('campaign-1'))
          .thenAnswer((_) async => null);

      final room = buildProvider();
      await room.load();

      expect(room.exists, isFalse);
      expect(room.role, RoomRole.none);
      expect(room.title, 'Room');
      verifyNever(
        () => mockSupabaseService.getMemberRole(
          campaignId: any(named: 'campaignId'),
          userId: any(named: 'userId'),
        ),
      );
    });

    test('notifie ses auditeurs au début et à la fin du chargement', () async {
      when(() => mockSupabaseService.getCampaignById('campaign-1'))
          .thenAnswer((_) async => _campaign());
      when(
        () => mockSupabaseService.getMemberRole(
          campaignId: any(named: 'campaignId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => 'mj');

      final room = buildProvider();
      var notifications = 0;
      room.addListener(() => notifications++);

      await room.load();

      expect(notifications, 2);
    });
  });
}
