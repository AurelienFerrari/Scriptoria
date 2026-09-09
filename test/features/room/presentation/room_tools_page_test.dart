import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/presentation/outils/de_page.dart';
import 'package:scriptoria/features/room/presentation/room_tools_page.dart';

import '../../../helpers/mock_supabase_service.dart';
import '../../../helpers/room_harness.dart';

void main() {
  testWidgets('RoomToolsPage affiche les 3 outils et navigue vers Dé au tap', (
    WidgetTester tester,
  ) async {
    final service = MockSupabaseService();
    final auth = AuthProvider(supabaseService: service);
    // Le dé consulte le journal de la room dès son ouverture.
    when(() => service.getDiceRolls(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);

    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: kPlayerId,
      role: 'player',
    );

    await tester.pumpWidget(
      wrapRoomScreen(auth: auth, room: room, child: const RoomToolsPage()),
    );

    expect(find.text('Outils'), findsOneWidget);
    expect(find.text('Dé'), findsOneWidget);
    expect(find.text('Frise'), findsOneWidget);
    expect(find.text('Relations'), findsOneWidget);

    await tester.tap(find.text('Dé'));
    await tester.pumpAndSettle();

    expect(find.byType(DePage), findsOneWidget);
    expect(find.text('Lancer 1d20'), findsOneWidget);
  });
}
