import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/room/domain/dice.dart';
import 'package:scriptoria/features/room/presentation/outils/de_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/room_harness.dart';

/// Rend toujours la même face : le test porte sur l'écran, pas sur l'aléa,
/// déjà couvert par `dice_test.dart`.
class _FixedRandom implements Random {
  final int face;

  _FixedRandom(this.face);

  @override
  int nextInt(int max) => face - 1;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    when(() => service.getDiceRolls(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => service.addDiceRoll(
          campaignId: any(named: 'campaignId'),
          userId: any(named: 'userId'),
          sides: any(named: 'sides'),
          diceCount: any(named: 'diceCount'),
          modifier: any(named: 'modifier'),
          results: any(named: 'results'),
          isSecret: any(named: 'isSecret'),
        )).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    int face = 12,
    String role = 'player',
    String? userId,
  }) async {
    final id = userId ?? (role == 'mj' ? kMjId : kPlayerId);
    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: id,
      role: role,
    );
    await tester.pumpWidget(
      wrapRoomScreen(
        auth: auth,
        room: room,
        child: DePage(roller: DiceRoller(random: _FixedRandom(face))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('DePage propose les dés usuels et un d20 par défaut', (tester) async {
    await pump(tester);

    expect(find.text('Dé'), findsOneWidget);
    for (final sides in DiceNotation.supportedSides) {
      expect(find.text('d$sides'), findsOneWidget);
    }
    expect(find.text('Lancer 1d20'), findsOneWidget);
    expect(find.text('Aucun jet pour l\'instant'), findsOneWidget);
  });

  testWidgets('DePage affiche le total et le détail après un lancer', (tester) async {
    await pump(tester, face: 12);

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsWidgets);
    expect(find.text('Aucun jet pour l\'instant'), findsNothing);
  });

  testWidgets('DePage additionne le modificateur au total', (tester) async {
    await pump(tester, face: 4);

    final plusButtons = find.byTooltip('Augmenter : Modificateur');
    await tester.tap(plusButtons);
    await tester.tap(plusButtons);
    await tester.pump();

    expect(find.text('Lancer 1d20+2'), findsOneWidget);

    await tester.tap(find.text('Lancer 1d20+2'));
    await tester.pumpAndSettle();

    // 4 sur le dé, +2 de modificateur.
    expect(find.text('6'), findsWidgets);
    expect(find.text('4 (+2)'), findsOneWidget);
  });

  testWidgets('DePage lance plusieurs dés du type choisi', (tester) async {
    await pump(tester, face: 3);

    await tester.tap(find.text('d6'));
    await tester.pump();
    await tester.tap(find.byTooltip('Augmenter : Nombre de dés'));
    await tester.pump();

    expect(find.text('Lancer 2d6'), findsOneWidget);

    await tester.tap(find.text('Lancer 2d6'));
    await tester.pumpAndSettle();

    expect(find.text('3 + 3'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
  });

  testWidgets('DePage signale une réussite critique sur un d20 seul', (tester) async {
    await pump(tester, face: 20);

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('Réussite critique'), findsOneWidget);
  });

  testWidgets('DePage signale un échec critique sur un d20 seul', (tester) async {
    await pump(tester, face: 1);

    await tester.tap(find.text('Lancer 1d20'));
    await tester.pumpAndSettle();

    expect(find.text('Échec critique'), findsOneWidget);
  });

  testWidgets('DePage ne descend pas sous un dé', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Diminuer : Nombre de dés'));
    await tester.pump();

    expect(find.text('Lancer 1d20'), findsOneWidget);
  });

  group('journal des jets', () {
    testWidgets('un jet est enregistré dans le journal de la room',
        (tester) async {
      await pump(tester, face: 5, role: 'player');

      await tester.tap(find.text('d6'));
      await tester.pump();
      await tester.tap(find.text('Lancer 1d6'));
      await tester.pumpAndSettle();

      verify(() => service.addDiceRoll(
            campaignId: kRoomId,
            userId: kPlayerId,
            sides: 6,
            diceCount: 1,
            modifier: 0,
            results: [5],
            isSecret: false,
          )).called(1);
    });

    testWidgets('l\'échec d\'enregistrement ne fait pas disparaître le résultat',
        (tester) async {
      when(() => service.addDiceRoll(
            campaignId: any(named: 'campaignId'),
            userId: any(named: 'userId'),
            sides: any(named: 'sides'),
            diceCount: any(named: 'diceCount'),
            modifier: any(named: 'modifier'),
            results: any(named: 'results'),
            isSecret: any(named: 'isSecret'),
          )).thenThrow(Exception('réseau indisponible'));

      await pump(tester, face: 12);

      await tester.tap(find.text('Lancer 1d20'));
      await tester.pumpAndSettle();

      // Le dé est tombé : son résultat reste affiché, et l'échec est signalé
      // sans l'effacer.
      expect(find.text('12'), findsWidgets);
      expect(find.textContaining('Jet non enregistré'), findsOneWidget);
    });

    testWidgets('affiche les jets de la table avec leur auteur', (tester) async {
      when(() => service.getDiceRolls(kRoomId, limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                {
                  'id': 'roll-1',
                  'user_id': kPlayerId,
                  'sides': 20,
                  'dice_count': 1,
                  'modifier': 3,
                  'results': [14],
                  'is_secret': false,
                  'created_at': DateTime.now().toIso8601String(),
                  'display_name': 'Camille',
                },
              ]);

      await pump(tester, role: 'mj');
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Camille · 1d20+3'), findsOneWidget);
      // 14 sur le dé, +3 de modificateur.
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('un jet est annoncé comme sien à son auteur', (tester) async {
      when(() => service.getDiceRolls(kRoomId, limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                {
                  'id': 'roll-1',
                  'user_id': kPlayerId,
                  'sides': 6,
                  'dice_count': 2,
                  'modifier': 0,
                  'results': [3, 4],
                  'is_secret': false,
                  'created_at': DateTime.now().toIso8601String(),
                  'display_name': 'Camille',
                },
              ]);

      await pump(tester, role: 'player');
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Vous · 2d6'), findsOneWidget);
    });
  });

  group('jet secret', () {
    testWidgets('le MJ peut lancer en secret', (tester) async {
      await pump(tester, face: 8, role: 'mj');

      expect(find.text('Jet secret'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      await tester.tap(find.text('Lancer 1d20'));
      await tester.pumpAndSettle();

      verify(() => service.addDiceRoll(
            campaignId: kRoomId,
            userId: kMjId,
            sides: 20,
            diceCount: 1,
            modifier: 0,
            results: [8],
            isSecret: true,
          )).called(1);
    });

    testWidgets('un joueur n\'a pas cette possibilité', (tester) async {
      await pump(tester, role: 'player');

      expect(find.text('Jet secret'), findsNothing);
    });

    testWidgets('un jet secret est signalé dans le journal', (tester) async {
      when(() => service.getDiceRolls(kRoomId, limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                {
                  'id': 'roll-1',
                  'user_id': kMjId,
                  'sides': 20,
                  'dice_count': 1,
                  'modifier': 0,
                  'results': [4],
                  'is_secret': true,
                  'created_at': DateTime.now().toIso8601String(),
                  'display_name': 'Aurélien',
                },
              ]);

      await pump(tester, role: 'mj');
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('vider le journal', () {
    setUp(() {
      when(() => service.getDiceRolls(kRoomId, limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                {
                  'id': 'roll-1',
                  'user_id': kPlayerId,
                  'sides': 6,
                  'dice_count': 1,
                  'modifier': 0,
                  'results': [5],
                  'is_secret': false,
                  'created_at': DateTime.now().toIso8601String(),
                  'display_name': 'Camille',
                },
              ]);
    });

    testWidgets('le MJ vide le journal après confirmation', (tester) async {
      when(() => service.clearDiceRolls(kRoomId)).thenAnswer((_) async {});

      await pump(tester, role: 'mj');
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vider le journal'));
      await tester.pumpAndSettle();

      expect(find.text('Vider le journal ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Vider'));
      await tester.pumpAndSettle();

      verify(() => service.clearDiceRolls(kRoomId)).called(1);
    });

    testWidgets('un joueur ne peut pas vider le journal', (tester) async {
      await pump(tester, role: 'player');
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Vider le journal'), findsNothing);
    });
  });
}
