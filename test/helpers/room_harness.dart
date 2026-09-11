import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/providers/room_provider.dart';
import 'package:scriptoria/ui/app_frame.dart';
import 'package:scriptoria/ui/app_theme.dart';

import 'mock_supabase_service.dart';

/// Utilitaires de montage des écrans de room, qui ont tous besoin d'un
/// [RoomProvider] déjà chargé pour savoir qui les regarde.

const String kMjId = 'user-mj';
const String kPlayerId = 'user-player';
const String kRoomId = 'campaign-1';

User testUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2024-01-01T00:00:00Z',
      email: '$id@scriptoria.fr',
    );

Map<String, dynamic> testCampaign({
  String title = 'Mystères de l\'Ombre',
  String description = 'Une enquête dans les bas-fonds de la ville.',
  String? joinCode = 'X7K2P9',
}) =>
    {
      'id': kRoomId,
      'creator_id': kMjId,
      'title': title,
      'description': description,
      'icon_url': null,
      'join_code': joinCode,
      'created_at': '2026-07-14T10:32:00Z',
      'updated_at': null,
    };

/// Ligne de `campaign_members` enrichie du profil, telle que la renvoie
/// `SupabaseService.getCampaignMembers`.
Map<String, dynamic> testMember({
  required String userId,
  String role = 'player',
  String? displayName,
  String? username,
  String? avatarUrl,
}) =>
    {
      'user_id': userId,
      'role': role,
      'joined_at': '2026-07-14T10:32:00Z',
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };

/// Prépare le mock pour qu'une room existe et que l'utilisateur courant y ait
/// le rôle demandé, puis renvoie un [RoomProvider] déjà chargé.
Future<RoomProvider> loadedRoomProvider({
  required MockSupabaseService service,
  required AuthProvider auth,
  required String asUserId,
  required String role,
  Map<String, dynamic>? campaign,
}) async {
  when(() => service.getCurrentUser()).thenReturn(testUser(asUserId));
  when(() => service.getCampaignById(kRoomId))
      .thenAnswer((_) async => campaign ?? testCampaign());
  when(() => service.getMemberRole(campaignId: kRoomId, userId: asUserId))
      .thenAnswer((_) async => role);

  final room = RoomProvider(auth: auth, roomId: kRoomId);
  await room.load();
  return room;
}

/// Enveloppe [child] dans les deux providers dont dépend tout écran de room,
/// **en reproduisant leur position réelle dans l'arbre**.
///
/// `AuthProvider` est monté au-dessus du `MaterialApp`, comme dans
/// `main.dart` : il traverse donc les routes. `RoomProvider` est monté à
/// l'intérieur de la route, comme le fait `RoomShell` : une route poussée
/// par-dessus en sort.
///
/// Cette distinction n'est pas cosmétique. Avec les deux providers placés
/// au-dessus du `MaterialApp`, un écran atteint par `Navigator.push` trouvait
/// le `RoomProvider` en test alors qu'il échouait dans l'app — c'est
/// exactement le bogue B25.
Widget wrapRoomScreen({
  required AuthProvider auth,
  required RoomProvider room,
  required Widget child,
  Map<String, WidgetBuilder> routes = const {},
}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      // Le cadre de l'app, comme dans `main.dart` : sans lui, un écran testé
      // couché ignorerait l'encoche et les boutons que l'app, elle, évite.
      theme: appTheme,
      builder: appFrame,
      home: ChangeNotifierProvider<RoomProvider>.value(
        value: room,
        child: child,
      ),
      routes: routes,
    ),
  );
}
