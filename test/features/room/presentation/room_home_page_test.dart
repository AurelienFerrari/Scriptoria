import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/room_home_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/room_harness.dart';

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
  });

  Future<void> pumpAs(WidgetTester tester, String userId, String role) async {
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: userId,
      role: role,
    );
    await tester.pumpWidget(
      wrapRoomScreen(
        auth: auth,
        room: room,
        child: const RoomHomePage(
          roomName: 'Salle du Dragon',
          description: 'Bienvenue dans la salle du Dragon !',
          lastUpdate: 'Aujourd\'hui à 12:30',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche le nom, la description et la date de mise à jour',
      (tester) async {
    await pumpAs(tester, kMjId, 'mj');

    expect(find.text('Salle du Dragon'), findsWidgets);
    expect(find.text('Bienvenue dans la salle du Dragon !'), findsOneWidget);
    expect(find.text('Dernière mise à jour'), findsOneWidget);
    expect(find.text('Aujourd\'hui à 12:30'), findsOneWidget);
  });

  testWidgets('n\'affiche plus la galerie, passée dans l\'onglet Contenus',
      (tester) async {
    await pumpAs(tester, kMjId, 'mj');

    expect(find.bySemanticsLabel('Ajouter une image'), findsNothing);
  });
}
