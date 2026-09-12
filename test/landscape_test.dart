import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/navigation/route_observer.dart';
import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:scriptoria/features/auth/presentation/pages/login_page.dart';
import 'package:scriptoria/features/auth/presentation/pages/register_page.dart';
import 'package:scriptoria/features/auth/presentation/pages/reset_password_page.dart';
import 'package:scriptoria/features/home/presentation/pages/home_page.dart';
import 'package:scriptoria/features/profile/presentation/pages/profile_page.dart';
import 'package:scriptoria/features/room/domain/dice.dart';
import 'package:scriptoria/features/room/presentation/feed/room_post_composer_page.dart';
import 'package:scriptoria/features/room/presentation/home/room_create_page.dart';
import 'package:scriptoria/features/room/presentation/home/room_join_page.dart';
import 'package:scriptoria/features/room/presentation/notes/room_note_editor_page.dart';
import 'package:scriptoria/features/room/presentation/outils/de_page.dart';
import 'package:scriptoria/features/room/presentation/outils/frise_page.dart';
import 'package:scriptoria/features/room/presentation/outils/relations_page.dart';
import 'package:scriptoria/features/room/presentation/outils/timeline_event_editor_page.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';
import 'package:scriptoria/features/room/presentation/zoomable_image_viewer.dart';
import 'package:scriptoria/ui/app_frame.dart';
import 'package:scriptoria/ui/app_theme.dart';
import 'package:scriptoria/ui/widgets/room_navbar.dart';

import 'helpers/mock_supabase_service.dart';
import 'helpers/network_image_stub.dart';
import 'helpers/room_harness.dart';

/// Chaque écran de l'app, monté téléphone à l'horizontale.
///
/// Deux choses sont vérifiées.
///
/// Que l'écran tient : un débordement de mise en page (`RenderFlex
/// overflowed`) est signalé par Flutter comme une erreur, qui fait échouer le
/// test de lui-même. Les écrans sont remplis de données réalistes, textes longs
/// compris — un écran vide tient toujours. Le cas le plus dur est le
/// formulaire clavier ouvert : couché, le clavier mange la moitié d'une hauteur
/// qui n'était déjà que de 411 dp.
///
/// Que rien ne se cache sous le matériel : couché, l'encoche de la caméra
/// passe d'un côté et les trois boutons Samsung de l'autre. Un écran peut
/// tenir sans déborder et poser malgré tout un bouton sous la barre de
/// navigation — le premier contrôle ne le verrait pas.

// Galaxy S24+ (SM-S926U1), l'appareil de test : 2340 × 1080 px physiques à une
// densité de 2,625, soit 891 × 411 dp une fois couché.
const double _dpr = 2.625;
const Size _landscape = Size(2340, 1080);
final double _widthDp = _landscape.width / _dpr;

const double _leftInset = 32;
const double _rightInset = 48;

// Barre d'état en haut, encoche à gauche, boutons Samsung à droite.
const FakeViewPadding _systemBars = FakeViewPadding(
  top: 24 * _dpr,
  left: _leftInset * _dpr,
  right: _rightInset * _dpr,
);

// Le clavier Samsung couché occupe à peu près la moitié de la hauteur.
const FakeViewPadding _keyboard = FakeViewPadding(bottom: 190 * _dpr);

const String _longText =
    'Le brouillard se lève sur Val-Morne. Les cloches de la citadelle sonnent '
    'trois fois, puis se taisent. Personne ne sait qui les a fait sonner, mais '
    'chacun a compris que la trêve venait de prendre fin.';

// Distinct de la description de la room, pour qu'on sache lequel des deux
// textes on retrouve à l'écran.
const String _longPost =
    'Les éclaireurs sont revenus de la forêt de Brume avec des nouvelles '
    'inquiétantes. Trois villages ont été désertés, et personne n\'a vu partir '
    'leurs habitants.';

Future<void> _pumpLandscape(
  WidgetTester tester,
  Widget app, {
  bool keyboard = false,
}) async {
  tester.view.physicalSize = _landscape;
  tester.view.devicePixelRatio = _dpr;
  tester.view.padding = _systemBars;
  tester.view.viewPadding = _systemBars;
  if (keyboard) tester.view.viewInsets = _keyboard;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Contrôle de fin de test, commun à tous les écrans audités.
Future<void> _verifyLandscape(WidgetTester tester, {String prefix = ''}) async {
  _expectClearOfSystemBars(tester);
  await _captureIfRequested(tester, prefix);
}

/// Pour la revue visuelle, en complément des deux contrôles :
///
///     LANDSCAPE_CAPTURE_DIR=<dossier> flutter test test/landscape_test.dart --update-goldens
///
/// enregistre une capture de chaque écran audité dans ce dossier — ceux de la
/// room préfixés du rôle qui les regarde, MJ et joueur ne voyant pas le même
/// écran. Sans la
/// variable, rien n'est écrit et l'audit reste un simple test.
Future<void> _captureIfRequested(WidgetTester tester, String prefix) async {
  final dir = Platform.environment['LANDSCAPE_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) return;

  final name =
      '$prefix${tester.testDescription}'.replaceAll(RegExp(r'[^\w-]+'), '_');
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(Uri.file('$dir/$name.png')),
  );
}

/// Aucun texte, champ ni icône ne doit reposer sous l'encoche de la caméra ou
/// sous les boutons Samsung.
///
/// Un fond qui passe dessous est voulu — c'est l'affichage bord à bord
/// d'Android. Un bouton ou une ligne de texte, en revanche, y devient
/// inaccessible ou illisible.
void _expectClearOfSystemBars(WidgetTester tester) {
  final safeLeft = _leftInset;
  final safeRight = _widthDp - _rightInset;
  final offenders = <String>{};

  for (final finder in [
    find.byType(Text),
    find.byType(EditableText),
    find.byType(Icon),
  ]) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;

      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.isEmpty || _scrolledOutOfView(element, rect)) continue;

      // Un demi-point de tolérance pour les arrondis de mise en page.
      if (rect.left < safeLeft - 0.5 || rect.right > safeRight + 0.5) {
        offenders.add(
          '${_describe(element.widget)} '
          '(x ${rect.left.toStringAsFixed(0)} → ${rect.right.toStringAsFixed(0)})',
        );
      }
    }
  }

  expect(
    offenders,
    isEmpty,
    reason: 'Zone sûre : x ${safeLeft.toStringAsFixed(0)} → '
        '${safeRight.toStringAsFixed(0)}. En deçà, l\'encoche de la caméra ; '
        'au-delà, les boutons Samsung.',
  );
}

/// Un élément d'une liste horizontale qui dépasse de sa fenêtre de défilement
/// n'est pas « posé » sous le matériel : il attend qu'on fasse défiler. Les
/// pages d'un `TabBarView` au repos, elles, sont entièrement dans la fenêtre et
/// restent vérifiées.
bool _scrolledOutOfView(Element element, Rect rect) {
  var outOfView = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.horizontal) {
      final box = ancestor.renderObject;
      if (box is RenderBox && box.hasSize) {
        final viewport = box.localToGlobal(Offset.zero) & box.size;
        outOfView = rect.left < viewport.left - 0.5 ||
            rect.right > viewport.right + 0.5;
      }
      return false;
    }
    return true;
  });
  return outOfView;
}

String _describe(Widget widget) {
  if (widget is Text) {
    return 'texte « ${widget.data ?? widget.textSpan?.toPlainText() ?? ''} »';
  }
  if (widget is Icon) {
    return 'icône 0x${widget.icon?.codePoint.toRadixString(16)}';
  }
  return 'champ de saisie';
}

Widget _app(AuthProvider auth, Widget home) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      navigatorObservers: [routeObserver],
      theme: appTheme,
      builder: appFrame,
      home: home,
    ),
  );
}

Map<String, dynamic> _campaign(String id, String title) => {
      'id': id,
      'creator_id': kMjId,
      'title': title,
      'description': _longText,
      'icon_url': 'assets/images/mystery.png',
      'join_code': 'X7K2P9',
      'created_at': '2026-07-14T10:32:00Z',
      'updated_at': null,
    };

Map<String, dynamic> _post(String id, {String? body, String? imageUrl}) => {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'body': body,
      'image_url': imageUrl,
      'image_bucket': imageUrl == null ? null : 'images',
      'image_path': imageUrl == null ? null : 'user-mj/post/scene.png',
      'visible_to': null,
      'created_at': '2026-09-10T10:00:00Z',
      'updated_at': '2026-09-10T10:00:00Z',
    };

Map<String, dynamic> _image(String id) => {
      'id': id,
      'owner_id': kMjId,
      'campaign_id': kRoomId,
      'bucket': 'images',
      'path': 'user-mj/campaign-campaign-1/$id.png',
      'url': 'https://exemple.test/$id.png',
      'visible_to': null,
      'created_at': '2026-09-09T10:00:00Z',
    };

Map<String, dynamic> _note(String id, String title) => {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'title': title,
      'content_md': '# $title\n\n$_longText',
      'created_at': '2026-09-10T09:00:00Z',
      'updated_at': '2026-09-10T10:00:00Z',
    };

Map<String, dynamic> _event(String id, int position, {String? title}) => {
      'id': id,
      'campaign_id': kRoomId,
      'author_id': kMjId,
      'date_label': 'An 1247, au printemps',
      'title': title ?? 'Le siège de Valmorne',
      'description': _longText,
      'position': position,
      'visible_to': null,
      'created_at': '2026-09-10T09:00:00Z',
      'updated_at': '2026-09-10T09:00:00Z',
    };

Map<String, dynamic> _roll(String id, {bool secret = false}) => {
      'id': id,
      'campaign_id': kRoomId,
      'user_id': kPlayerId,
      'display_name': 'Camille',
      'username': 'camille',
      'sides': 20,
      'dice_count': 3,
      'modifier': 2,
      'results': [14, 7, 19],
      'is_secret': secret,
      'created_at': '2026-09-10T10:00:00Z',
    };

/// Remplit toutes les requêtes des écrans avec des données réalistes.
void _stubRichData(MockSupabaseService service) {
  stubHomeScreen(service);
  stubRoomScreens(service);

  when(() => service.getVisibleCampaigns(any())).thenAnswer(
    (_) async => [
      _campaign(kRoomId, 'Mystères de l\'Ombre'),
      _campaign(
          'campaign-2', 'La Quête du Dragon d\'Émeraude et des Neuf Couronnes'),
      _campaign('campaign-3', 'Les Brumes'),
    ],
  );
  when(() => service.getCampaignOverviews(any())).thenAnswer(
    (_) async => {
      kRoomId: {'members': 4, 'images': 12, 'notes': 3},
      'campaign-2': {'members': 6, 'images': 0, 'notes': 11},
    },
  );
  when(() => service.getRecentActivity(limit: any(named: 'limit'))).thenAnswer(
    (_) async => [
      for (var i = 0; i < 4; i++)
        {
          'kind': i.isEven ? 'note' : 'image',
          'id': 'activity-$i',
          'label': i.isEven
              ? 'Le traître se révèle au bal masqué'
              : 'Image partagée',
          'campaign_id': kRoomId,
          'campaign_title': 'Mystères de l\'Ombre',
          'at': '2026-09-10T10:00:00Z',
        },
    ],
  );
  when(() => service.getUserProfile(any())).thenAnswer(
    (_) async => {
      'username': 'aurelien_gm',
      'email': 'aurelien@scriptoria.fr',
      'display_name': 'Aurélien',
      'bio': _longText,
      'created_at': '2024-01-01T00:00:00Z',
    },
  );

  when(() => service.getCampaignById(kRoomId))
      .thenAnswer((_) async => _campaign(kRoomId, 'Mystères de l\'Ombre'));
  when(() => service.getRoomPosts(kRoomId)).thenAnswer(
    (_) async => [
      _post('post-1', body: _longPost),
      _post('post-2',
          body: 'Rendez-vous samedi.',
          imageUrl: 'https://exemple.test/scene.png'),
      _post('post-3', imageUrl: 'https://exemple.test/carte.png'),
    ],
  );
  when(() => service.getCampaignImages(kRoomId)).thenAnswer(
      (_) async => [for (var i = 0; i < 7; i++) _image('image-$i')]);
  when(() => service.getRoomNotes(kRoomId)).thenAnswer(
    (_) async => [
      _note('note-1', 'Intrigue principale'),
      _note('note-2', 'PNJ de la cour et leurs allégeances secrètes'),
      _note('note-3', 'Carte'),
    ],
  );
  when(() => service.getCampaignMembers(kRoomId)).thenAnswer(
    (_) async => [
      testMember(userId: kMjId, role: 'mj', displayName: 'Aurélien'),
      testMember(userId: kPlayerId, displayName: 'Camille'),
      testMember(userId: 'user-3', displayName: 'Maximilien de la Tour-Vernet'),
      testMember(userId: 'user-4', username: 'lea'),
    ],
  );
  when(() => service.getTimelineEvents(kRoomId)).thenAnswer(
    (_) async => [
      _event('event-1', 0),
      _event('event-2', 1,
          title: 'La trahison du chambellan au solstice d\'hiver'),
      _event('event-3', 2, title: 'Le pacte'),
    ],
  );
  // Un chat vide tient toujours : un message long et un chuchotement du MJ.
  when(() => service.getRoomMessages(kRoomId)).thenAnswer(
    (_) async => [
      {
        "id": "message-1",
        "campaign_id": kRoomId,
        "author_id": kPlayerId,
        "body": _longText,
        "visible_to": null,
        "created_at": "2026-09-11T10:00:00Z",
      },
      {
        "id": "message-2",
        "campaign_id": kRoomId,
        "author_id": kMjId,
        "body": "Le garde ment. Ne le laissez pas quitter la salle.",
        "visible_to": [kPlayerId],
        "created_at": "2026-09-11T10:01:00Z",
      },
    ],
  );
  when(() => service.getDiceRolls(kRoomId, limit: any(named: 'limit')))
      .thenAnswer(
    (_) async => [for (var i = 0; i < 6; i++) _roll('roll-$i', secret: i == 2)],
  );
  when(() => service.addDiceRoll(
        campaignId: any(named: 'campaignId'),
        userId: any(named: 'userId'),
        sides: any(named: 'sides'),
        diceCount: any(named: 'diceCount'),
        modifier: any(named: 'modifier'),
        results: any(named: 'results'),
        isSecret: any(named: 'isSecret'),
      )).thenAnswer((_) async {});
}

/// Aléa figé : chaque dé tombe sur [face]. Le résultat d'un lancer devient
/// prévisible, et l'audit peut vérifier qu'il s'affiche.
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

  // Les publications et la galerie affichent des Image.network, auxquelles le
  // binding de test répond 400 sans interception.
  setUpAll(() => HttpOverrides.global = StubImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    service = MockSupabaseService();
    auth = AuthProvider(supabaseService: service);
    _stubRichData(service);
  });

  group('hors connexion', () {
    final screens = <String, Widget>{
      'Connexion': const LoginPage(),
      'Inscription': const RegisterPage(),
      'Mot de passe oublié': const ForgotPasswordPage(),
      'Nouveau mot de passe': const ResetPasswordPage(),
    };

    for (final entry in screens.entries) {
      for (final keyboard in [false, true]) {
        testWidgets('${entry.key}${keyboard ? ', clavier ouvert' : ''}',
            (tester) async {
          when(() => service.getCurrentUser()).thenReturn(null);
          await _pumpLandscape(tester, _app(auth, entry.value),
              keyboard: keyboard);
          await _verifyLandscape(tester);
        });
      }
    }
  });

  group('accueil et compte', () {
    setUp(
        () => when(() => service.getCurrentUser()).thenReturn(testUser(kMjId)));

    testWidgets('Accueil', (tester) async {
      await _pumpLandscape(tester, _app(auth, const HomePage()));
      await _verifyLandscape(tester);
    });

    testWidgets('Profil', (tester) async {
      await _pumpLandscape(tester, _app(auth, const ProfilePage()));
      await _verifyLandscape(tester);
    });

    for (final keyboard in [false, true]) {
      final suffix = keyboard ? ', clavier ouvert' : '';

      testWidgets('Créer une room$suffix', (tester) async {
        await _pumpLandscape(tester, _app(auth, const RoomCreatePage()),
            keyboard: keyboard);
        await _verifyLandscape(tester);
      });

      testWidgets('Rejoindre une room$suffix', (tester) async {
        await _pumpLandscape(tester, _app(auth, const RoomJoinPage()),
            keyboard: keyboard);
        await _verifyLandscape(tester);
      });
    }

    testWidgets('Image en plein écran', (tester) async {
      await _pumpLandscape(
        tester,
        _app(
          auth,
          ZoomableImageViewer(
            imageWidget: Container(width: 600, height: 900, color: Colors.teal),
          ),
        ),
      );
      await _verifyLandscape(tester);
    });
  });

  for (final role in ['mj', 'player']) {
    final userId = role == 'mj' ? kMjId : kPlayerId;

    group('room, vue ${role == 'mj' ? 'MJ' : 'joueur'}', () {
      setUp(() {
        when(() => service.getCurrentUser()).thenReturn(testUser(userId));
        when(() => service.getMemberRole(
              campaignId: any(named: 'campaignId'),
              userId: any(named: 'userId'),
            )).thenAnswer((_) async => role);
      });

      Future<void> pumpTab(
        WidgetTester tester,
        String tab, {
        bool keyboard = false,
      }) async {
        await _pumpLandscape(
          tester,
          _app(auth, const RoomShell(roomId: kRoomId)),
          keyboard: keyboard,
        );
        await tester.tap(find.descendant(
          of: find.byType(RoomNavbar),
          matching: find.text(tab),
        ));
        await tester.pumpAndSettle();
        await _verifyLandscape(tester, prefix: '$role ');
      }

      for (final tab in [
        'Accueil',
        'Contenus',
        'Outils',
        'Chat',
        'Paramètres'
      ]) {
        testWidgets('onglet $tab', (tester) => pumpTab(tester, tab));
      }

      testWidgets('onglet Accueil, le fil visible sans défiler',
          (tester) async {
        await pumpTab(tester, 'Accueil');

        // Couché, l'en-tête de la room occupait tout le premier écran et
        // repoussait le fil — le contenu principal de l'onglet — sous la
        // ligne de flottaison.
        final navbarTop = tester.getRect(find.byType(RoomNavbar)).top;
        final firstPost = tester.getRect(find.textContaining('Les éclaireurs'));
        expect(firstPost.bottom, lessThanOrEqualTo(navbarTop));
      });

      testWidgets('onglet Chat, clavier ouvert',
          (tester) => pumpTab(tester, 'Chat', keyboard: true));

      Future<void> pumpInRoom(
        WidgetTester tester,
        Widget screen, {
        bool keyboard = false,
      }) async {
        final room = await loadedRoomProvider(
          service: service,
          auth: auth,
          asUserId: userId,
          role: role,
        );
        await _pumpLandscape(
          tester,
          wrapRoomScreen(auth: auth, room: room, child: screen),
          keyboard: keyboard,
        );
        await _verifyLandscape(tester, prefix: '$role ');
      }

      testWidgets('Dé', (tester) => pumpInRoom(tester, const DePage()));

      testWidgets('Dé, après un lancer', (tester) async {
        await pumpInRoom(
          tester,
          DePage(roller: DiceRoller(random: _FixedRandom(17))),
        );
        await tester.tap(find.text('Lancer 1d20'));
        await tester.pumpAndSettle();

        // Couché, le résultat tombait sous la ligne de flottaison : on
        // appuyait sur « Lancer » et rien ne changeait à l'écran. Le 17 doit
        // se lire sans défiler, sur le dé comme dans le total.
        final screenHeight = _landscape.height / _dpr;
        final shown = find.text('17');
        expect(shown, findsWidgets);
        for (var i = 0; i < shown.evaluate().length; i++) {
          expect(
            tester.getRect(shown.at(i)).bottom,
            lessThanOrEqualTo(screenHeight),
          );
        }
        await _verifyLandscape(tester, prefix: '$role ');
      });

      testWidgets('Dé, journal', (tester) async {
        await pumpInRoom(tester, const DePage());
        await tester.tap(find.text('Journal'));
        await tester.pumpAndSettle();
        await _verifyLandscape(tester, prefix: '$role ');
      });

      testWidgets('Frise', (tester) => pumpInRoom(tester, const FrisePage()));

      testWidgets(
          'Relations', (tester) => pumpInRoom(tester, const RelationsPage()));

      if (role == 'mj') {
        final editors = <String, Widget>{
          'Éditeur de note':
              RoomNoteEditorPage(note: _note('note-1', 'Intrigue')),
          'Nouvelle publication': const RoomPostComposerPage(),
          'Éditeur d\'évènement':
              TimelineEventEditorPage(event: _event('event-1', 0)),
        };

        for (final entry in editors.entries) {
          for (final keyboard in [false, true]) {
            testWidgets(
                '${entry.key}${keyboard ? ', clavier ouvert' : ''}',
                (tester) =>
                    pumpInRoom(tester, entry.value, keyboard: keyboard));
          }
        }
      }
    });
  }
}
