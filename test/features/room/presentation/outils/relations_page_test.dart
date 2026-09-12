import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/services/row_change.dart';
import 'package:scriptoria/features/room/presentation/outils/relations_page.dart';

import '../../../../helpers/mock_supabase_service.dart';
import '../../../../helpers/room_harness.dart';

/// Une information telle que la renvoie `get_relation_graph`.
///
/// [content] vaut `null` quand la base refuse de la révéler : c'est ce qui
/// fait apparaître « ??? » à l'écran.
Map<String, dynamic> _fact({
  String id = 'fact-1',
  String? content,
  List<String> discoveredBy = const [],
}) =>
    {
      'id': id,
      'position': 0,
      'content': content,
      'discovered_by': discoveredBy,
    };

Map<String, dynamic> _node({
  String id = 'node-1',
  String label = 'Le baron',
  String kind = 'person',
  String? categoryId,
  double x = 400,
  double y = 400,
  List<Map<String, dynamic>> facts = const [],
}) =>
    {
      'id': id,
      'label': label,
      'kind': kind,
      'category_id': categoryId,
      'x': x,
      'y': y,
      'fact_count': facts.length,
      'discovered_count':
          facts.where((fact) => fact['content'] != null).length,
      'facts': facts,
    };

Map<String, dynamic> _link({
  String id = 'link-1',
  String from = 'node-1',
  String to = 'node-2',
  String? categoryId,
}) =>
    {
      'id': id,
      'from_node_id': from,
      'to_node_id': to,
      'category_id': categoryId,
      'label': null,
    };

Map<String, dynamic> _category({
  String id = 'cat-1',
  String name = 'Conflit',
  int color = 0xFFE37B7B,
}) =>
    {'id': id, 'name': name, 'color': color, 'position': 0};

Map<String, dynamic> _graph({
  bool isMj = false,
  List<Map<String, dynamic>> nodes = const [],
  List<Map<String, dynamic>> links = const [],
  List<Map<String, dynamic>> categories = const [],
}) =>
    {
      'is_mj': isMj,
      'nodes': nodes,
      'links': links,
      'categories': categories,
    };

void main() {
  late MockSupabaseService service;
  late AuthProvider auth;
  late StreamController<RowChange> changes;

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    changes = StreamController<RowChange>.broadcast();

    when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
      (_) async => [
        testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
        testMember(userId: kPlayerId, displayName: 'Camille'),
      ],
    );
    when(() => service.watchRoomTable(any(), any()))
        .thenAnswer((_) => changes.stream);
    when(() => service.createRelationNode(
          campaignId: any(named: 'campaignId'),
          label: any(named: 'label'),
          kind: any(named: 'kind'),
          categoryId: any(named: 'categoryId'),
          x: any(named: 'x'),
          y: any(named: 'y'),
        )).thenAnswer((_) async => _node());
    when(() => service.setRelationNodeCategory(
          nodeId: any(named: 'nodeId'),
          categoryId: any(named: 'categoryId'),
        )).thenAnswer((_) async {});
    when(() => service.updateRelationNode(
          nodeId: any(named: 'nodeId'),
          label: any(named: 'label'),
          kind: any(named: 'kind'),
          x: any(named: 'x'),
          y: any(named: 'y'),
        )).thenAnswer((_) async {});
    when(() => service.createRelationFact(
          campaignId: any(named: 'campaignId'),
          nodeId: any(named: 'nodeId'),
          content: any(named: 'content'),
          position: any(named: 'position'),
        )).thenAnswer((_) async {});
    when(() => service.setFactDiscoverers(
          factId: any(named: 'factId'),
          userIds: any(named: 'userIds'),
        )).thenAnswer((_) async {});
    when(() => service.createRelationCategory(
          campaignId: any(named: 'campaignId'),
          name: any(named: 'name'),
          color: any(named: 'color'),
          position: any(named: 'position'),
        )).thenAnswer((_) async => _category());
    when(() => service.updateRelationLink(
          linkId: any(named: 'linkId'),
          categoryId: any(named: 'categoryId'),
        )).thenAnswer((_) async {});
    when(() => service.clearRelationGraph(any())).thenAnswer((_) async {});
  });

  tearDown(() => changes.close());

  Future<void> pumpMap(
    WidgetTester tester,
    Map<String, dynamic> graph, {
    bool asMj = false,
  }) async {
    when(() => service.getRelationGraph(kRoomId)).thenAnswer((_) async => graph);

    final room = await loadedRoomProvider(
      service: service,
      auth: auth,
      asUserId: asMj ? kMjId : kPlayerId,
      role: asMj ? 'mj' : 'player',
    );
    await tester.pumpWidget(
      wrapRoomScreen(auth: auth, room: room, child: const RelationsPage()),
    );
    await tester.pumpAndSettle();
  }

  group('cadrage de la carte', () {
    testWidgets('amène le contenu au milieu de l\'écran à l\'ouverture',
        (tester) async {
      // La carte fait plus de 1000 dp de côté : sans cadrage, l'écran
      // s'ouvre sur son coin haut-gauche, qui est vide.
      await pumpMap(tester, _graph(nodes: [_node(x: 700, y: 500)]));

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final translation =
          viewer.transformationController!.value.getTranslation();

      // Le rond, à 700, se retrouve au milieu des 800 dp de l'écran de test.
      expect(translation.x, closeTo(400 - 700, 1));
      expect(translation.y, lessThan(0));
    });

    testWidgets('le rond + ne suit pas un rond que l\'on déplace',
        (tester) async {
      await pumpMap(tester, _graph(isMj: true, nodes: [_node()]), asMj: true);

      final before = tester.getRect(find.byTooltip('Ajouter un rond'));
      await tester.drag(find.text('Le baron'), const Offset(120, 60));
      await tester.pumpAndSettle();

      // Sa place est fixée au chargement : déduite du rond le plus à droite,
      // elle suivait le doigt comme si les deux étaient attachés.
      expect(tester.getRect(find.byTooltip('Ajouter un rond')), before);
    });
  });

  group('vue joueur', () {
    testWidgets('affiche les ronds de la carte', (tester) async {
      await pumpMap(
        tester,
        _graph(nodes: [
          _node(),
          _node(id: 'node-2', label: 'La citadelle', kind: 'place', x: 700),
        ]),
      );

      expect(find.text('Le baron'), findsOneWidget);
      expect(find.text('La citadelle'), findsOneWidget);
    });

    testWidgets('annonce une carte que le MJ n\'a pas encore dessinée',
        (tester) async {
      await pumpMap(tester, _graph());

      expect(
        find.textContaining('pas encore dessiné la carte'),
        findsOneWidget,
      );
      // Le rond « + » est réservé au MJ.
      expect(find.byTooltip('Ajouter un rond'), findsNothing);
    });

    testWidgets('masque ce qui n\'a pas été découvert', (tester) async {
      await pumpMap(
        tester,
        _graph(nodes: [
          _node(facts: [
            _fact(content: 'Il a vendu la carte aux contrebandiers.'),
            _fact(id: 'fact-2'),
            _fact(id: 'fact-3'),
          ]),
        ]),
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();

      expect(find.text('Informations (1/3)'), findsOneWidget);
      expect(
        find.text('Il a vendu la carte aux contrebandiers.'),
        findsOneWidget,
      );
      // Deux informations restent à trouver, et leur texte n'est jamais arrivé.
      expect(find.text('???'), findsNWidgets(2));
    });

    testWidgets('ne donne au joueur aucun outil du MJ', (tester) async {
      await pumpMap(
        tester,
        _graph(nodes: [
          _node(facts: [_fact(content: 'Un secret déjà connu.')]),
        ]),
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();

      expect(find.text('Information'), findsNothing);
      expect(find.text('Relier'), findsNothing);
      expect(find.text('Catégorie'), findsNothing);
      expect(find.byTooltip('Supprimer le rond'), findsNothing);
      expect(find.byTooltip('Qui a découvert cette information'), findsNothing);
    });
  });

  group('vue MJ', () {
    testWidgets('ajoute un rond depuis le rond +', (tester) async {
      await pumpMap(tester, _graph(isMj: true), asMj: true);

      await tester.tap(find.byTooltip('Ajouter un rond'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau rond'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nom'),
        'La citadelle',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lieu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.createRelationNode(
            campaignId: kRoomId,
            label: 'La citadelle',
            kind: 'place',
            categoryId: null,
            x: any(named: 'x'),
            y: any(named: 'y'),
          )).called(1);
    });

    testWidgets('donne une catégorie au rond dès sa création', (tester) async {
      await pumpMap(
        tester,
        _graph(isMj: true, categories: [_category()]),
        asMj: true,
      );

      await tester.tap(find.byTooltip('Ajouter un rond'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nom'),
        'La citadelle',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Conflit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.createRelationNode(
            campaignId: kRoomId,
            label: 'La citadelle',
            kind: 'person',
            categoryId: 'cat-1',
            x: any(named: 'x'),
            y: any(named: 'y'),
          )).called(1);
    });

    testWidgets('range un rond dans une catégorie depuis sa fiche',
        (tester) async {
      await pumpMap(
        tester,
        _graph(isMj: true, nodes: [_node()], categories: [_category()]),
        asMj: true,
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();
      // L'attribution se fait depuis le rond, et non depuis la légende.
      await tester.tap(find.text('Catégorie'));
      await tester.pumpAndSettle();

      expect(find.text('Catégorie du rond'), findsOneWidget);
      await tester.tap(find.text('Conflit').last);
      await tester.pumpAndSettle();

      verify(() => service.setRelationNodeCategory(
            nodeId: 'node-1',
            categoryId: 'cat-1',
          )).called(1);
    });

    testWidgets('voit le texte de toutes les informations', (tester) async {
      await pumpMap(
        tester,
        _graph(isMj: true, nodes: [
          _node(facts: [
            _fact(content: 'Il a vendu la carte.', discoveredBy: [kPlayerId]),
            _fact(id: 'fact-2', content: 'Sa fille est vivante.'),
          ]),
        ]),
        asMj: true,
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();

      expect(find.text('Il a vendu la carte.'), findsOneWidget);
      expect(find.text('Sa fille est vivante.'), findsOneWidget);
      expect(find.text('???'), findsNothing);
      // Le MJ sait à qui il a déjà révélé quoi.
      expect(find.text('Découverte par 1 joueur'), findsOneWidget);
      expect(find.text('Personne ne l\'a découverte'), findsOneWidget);
    });

    testWidgets('ajoute une information à un rond', (tester) async {
      await pumpMap(
        tester,
        _graph(isMj: true, nodes: [
          _node(facts: [_fact(content: 'Déjà écrite.')]),
        ]),
        asMj: true,
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Information'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Il ment sur son âge.');
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.createRelationFact(
            campaignId: kRoomId,
            nodeId: 'node-1',
            content: 'Il ment sur son âge.',
            // À la suite de celle qui existe déjà.
            position: 1,
          )).called(1);
    });

    testWidgets('désigne qui a découvert une information', (tester) async {
      await pumpMap(
        tester,
        _graph(isMj: true, nodes: [
          _node(facts: [_fact(content: 'Il a vendu la carte.')]),
        ]),
        asMj: true,
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Qui a découvert cette information'));
      await tester.pumpAndSettle();

      expect(find.text('Qui a découvert cette information ?'), findsOneWidget);
      await tester.tap(find.text('Joueurs choisis'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Camille'));
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.setFactDiscoverers(
            factId: 'fact-1',
            userIds: [kPlayerId],
          )).called(1);
    });

    testWidgets('enregistre la position d\'un rond déplacé', (tester) async {
      await pumpMap(tester, _graph(isMj: true, nodes: [_node()]), asMj: true);

      await tester.drag(find.text('Le baron'), const Offset(60, 40));
      await tester.pumpAndSettle();

      final moved = verify(() => service.updateRelationNode(
            nodeId: 'node-1',
            label: any(named: 'label'),
            kind: any(named: 'kind'),
            x: captureAny(named: 'x'),
            y: captureAny(named: 'y'),
          )).captured;

      // Pas de valeur exacte attendue : le seuil de déclenchement du geste
      // absorbe les premiers pixels du glissement. Ce qui compte, c'est que
      // la nouvelle position parte en base.
      expect(moved[0] as double, greaterThan(400));
      expect(moved[1] as double, greaterThan(400));
    });

    testWidgets('crée une catégorie', (tester) async {
      await pumpMap(tester, _graph(isMj: true), asMj: true);

      await tester.tap(find.byTooltip('Catégories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter une catégorie'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Conflit');
      await tester.tap(find.widgetWithText(TextButton, 'Valider'));
      await tester.pumpAndSettle();

      verify(() => service.createRelationCategory(
            campaignId: kRoomId,
            name: 'Conflit',
            color: any(named: 'color'),
            position: 0,
          )).called(1);
    });

    testWidgets('pose une catégorie sur un lien déjà tracé', (tester) async {
      await pumpMap(
        tester,
        _graph(
          isMj: true,
          nodes: [_node(), _node(id: 'node-2', label: 'La citadelle', x: 700)],
          links: [_link()],
          categories: [_category()],
        ),
        asMj: true,
      );

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();
      expect(find.text('Sans catégorie'), findsOneWidget);

      await tester.tap(find.byTooltip('Changer la catégorie du lien'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conflit').last);
      await tester.pumpAndSettle();

      verify(() => service.updateRelationLink(
            linkId: 'link-1',
            categoryId: 'cat-1',
          )).called(1);
    });

    testWidgets('explique qu\'il faut un deuxième rond pour relier',
        (tester) async {
      await pumpMap(tester, _graph(isMj: true, nodes: [_node()]), asMj: true);

      await tester.tap(find.text('Le baron'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relier'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ajoutez un deuxième rond pour pouvoir les relier.'),
        findsOneWidget,
      );
    });

    testWidgets('vide toute la carte après confirmation', (tester) async {
      await pumpMap(
        tester,
        _graph(isMj: true, nodes: [_node()], categories: [_category()]),
        asMj: true,
      );

      await tester.tap(find.byTooltip('Vider la carte'));
      await tester.pumpAndSettle();

      expect(find.text('Vider la carte ?'), findsOneWidget);
      // La confirmation annonce ce qui ne se reconstitue pas.
      expect(find.textContaining('découvertes des joueurs'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Vider'));
      await tester.pumpAndSettle();

      verify(() => service.clearRelationGraph(kRoomId)).called(1);
    });

    testWidgets('ne vide rien si on renonce', (tester) async {
      await pumpMap(tester, _graph(isMj: true, nodes: [_node()]), asMj: true);

      await tester.tap(find.byTooltip('Vider la carte'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => service.clearRelationGraph(any()));
    });
  });

  testWidgets('un joueur ne peut pas vider la carte', (tester) async {
    await pumpMap(tester, _graph(nodes: [_node()]));

    expect(find.byTooltip('Vider la carte'), findsNothing);
  });

  testWidgets('le rond porte la couleur de sa catégorie', (tester) async {
    await pumpMap(
      tester,
      _graph(
        nodes: [_node(categoryId: 'cat-1')],
        categories: [_category()],
      ),
    );

    final circle = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.person_outline),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (circle.decoration as BoxDecoration).border as Border;

    // Celle de la catégorie, et non celle de l'état des découvertes.
    expect(border.top.color, const Color(0xFFE37B7B));
  });

  testWidgets('la couleur de catégorie ne masque pas ce qu\'il reste à trouver',
      (tester) async {
    await pumpMap(
      tester,
      _graph(
        nodes: [
          _node(categoryId: 'cat-1', facts: [_fact()]),
        ],
        categories: [_category()],
      ),
    );

    // Le rond a pris la couleur de sa catégorie ; la pastille, elle, garde
    // l'ambre qui dit qu'une information reste à découvrir ici.
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.backgroundColor, const Color(0xFFE3C77B));
  });

  testWidgets('la légende met une catégorie en avant', (tester) async {
    await pumpMap(
      tester,
      _graph(
        nodes: [_node(), _node(id: 'node-2', label: 'La citadelle', x: 700)],
        links: [_link(categoryId: 'cat-1')],
        categories: [_category()],
      ),
    );

    // Annoncée comme un filtre du regard : sans cet intitulé, on la prend
    // pour un moyen d'attribuer une couleur.
    expect(find.text('Mettre en avant'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Conflit'), findsOneWidget);
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).selected,
      isFalse,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Conflit'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).selected,
      isTrue,
    );
  });

  testWidgets('recharge la carte quand le MJ y touche', (tester) async {
    await pumpMap(tester, _graph(nodes: [_node()]));
    clearInteractions(service);

    // Révéler une information touche son rond : c'est ce signal qui circule.
    changes.add(const RowChange(RowChangeKind.updated, {'id': 'node-1'}));
    // Le rechargement attend que la rafale soit passée.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    verify(() => service.getRelationGraph(kRoomId)).called(1);
  });
}
