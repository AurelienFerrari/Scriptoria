import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../domain/dice.dart';
import 'dice_journal.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);
const Color _successColor = Color(0xFF7BE38C);
const Color _failureColor = Color(0xFFE37B7B);

/// Lanceur de dés de la room, et journal des jets de la table.
///
/// Un jet est calculé et affiché localement — l'animation ne doit pas attendre
/// le réseau — puis enregistré dans `dice_rolls`, où toute la table le voit.
/// Le MJ peut lancer en secret : le jet reste alors visible de lui seul, règle
/// appliquée par la RLS et non par cet écran.
class DePage extends StatefulWidget {
  /// Injectable pour que les tests vérifient des résultats exacts.
  final DiceRoller? roller;

  const DePage({Key? key, this.roller}) : super(key: key);

  @override
  State<DePage> createState() => _DePageState();
}

class _DePageState extends State<DePage> with TickerProviderStateMixin {
  late final DiceRoller _roller = widget.roller ?? DiceRoller();

  DiceNotation _notation = const DiceNotation(count: 1, sides: 20);
  DiceRoll? _lastRoll;
  bool _isSecret = false;

  late final TabController _tabs;

  // Créé dès l'initialisation, et non paresseusement : un `late final` ne
  // serait construit qu'au premier accès, c'est-à-dire dans `dispose()` si
  // aucun jet n'a eu lieu — or `vsync: this` y consulte un ancêtre déjà
  // désactivé.
  late final AnimationController _animation;

  /// Incrémenté après chaque jet enregistré : le journal s'y abonne et se
  /// recharge, sans que cet écran ait à connaître son état interne.
  final ValueNotifier<int> _journalRevision = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _animation.dispose();
    _journalRevision.dispose();
    super.dispose();
  }

  /// Durée pendant laquelle le premier dé tourne avant de se figer.
  static const int _spinMs = 1150;

  /// Temps laissé après le dernier dé pour faire apparaître le calcul.
  static const int _revealMs = 320;

  /// Décalage entre l'arrêt de deux dés successifs : ils se posent l'un après
  /// l'autre, comme sur une table, au lieu de s'immobiliser tous ensemble.
  ///
  /// Resserré au-delà de six dés, sinon une poignée de dés ferait attendre
  /// plusieurs secondes avant le total.
  int _staggerMs(int count) => count > 6 ? 90 : 190;

  int get _diceCount => _lastRoll?.results.length ?? 1;

  int _rollDurationMs(int count) =>
      _spinMs + (count - 1) * _staggerMs(count) + _revealMs;

  /// Instant, en fraction de l'animation, où le dé [index] se fige.
  double _settleFraction(int index) {
    final count = _diceCount;
    return (_spinMs + index * _staggerMs(count)) / _rollDurationMs(count);
  }

  /// Face affichée par un dé encore en train de tourner.
  ///
  /// [spinProgress] va de 0 au lancer à 1 à l'arrêt de ce dé. La courbe
  /// d'atténuation espace les changements de face à mesure qu'on approche de
  /// l'arrêt : le dé ralentit au lieu de s'arrêter net, ce qui fait toute la
  /// différence entre un chiffre qui clignote et un dé qui roule.
  ///
  /// La face est dérivée du temps et non tirée au sort : l'animation reste
  /// reproductible en test, et deux dés voisins ne montrent jamais la même
  /// face au même instant.
  int _spinningFace(int index, double spinProgress, int sides) {
    final eased = Curves.easeOutCubic.transform(spinProgress.clamp(0.0, 1.0));
    final step = (eased * 22).floor();
    return ((step * 7 + index * 13) % sides) + 1;
  }

  void _roll() {
    final roll = _roller.roll(_notation);

    setState(() => _lastRoll = roll);

    _animation.duration =
        Duration(milliseconds: _rollDurationMs(roll.results.length));
    _animation.forward(from: 0);

    // Le résultat change sans qu'aucun focus ne bouge : sans annonce
    // explicite, un lecteur d'écran ne dirait rien du jet. Annoncé tout de
    // suite : personne ne devrait avoir à attendre la fin d'une animation
    // pour connaître son jet.
    SemanticsService.announce(
      'Résultat du jet ${roll.notation.label} : ${roll.total}',
      Directionality.of(context),
    );

    _record(roll);
  }

  /// Enregistre le jet dans le journal de la room.
  ///
  /// Volontairement détaché de l'animation : celle-ci ne doit pas attendre le
  /// réseau, et un jet reste valable même si son enregistrement échoue — le
  /// dé est tombé. L'échec est signalé sans effacer le résultat affiché.
  Future<void> _record(DiceRoll roll) async {
    final room = context.read<RoomProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    try {
      await auth.addDiceRoll(
        campaignId: room.roomId,
        userId: userId,
        sides: roll.notation.sides,
        diceCount: roll.notation.count,
        modifier: roll.notation.modifier,
        results: roll.results,
        isSecret: _isSecret,
      );
      _journalRevision.value++;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jet non enregistré : ${friendlyErrorMessage(e)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dé'),
        backgroundColor: _bgColor,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _primaryColor,
          labelColor: _primaryColor,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Lancer'),
            Tab(text: 'Journal'),
          ],
        ),
      ),
      backgroundColor: _bgColor,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildRollTab(room),
          DiceJournal(revision: _journalRevision),
        ],
      ),
    );
  }

  Widget _buildRollTab(RoomProvider room) {
    // Le bouton « Lancer » est ancré hors de la zone défilante : le bloc de
    // résultat change de hauteur selon le nombre de dés, et l'action
    // principale ne doit pas se déplacer sous le doigt entre deux jets.
    // `SafeArea` l'écarte de la barre de navigation du téléphone.
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidesSelector(),
                  const SizedBox(height: 24),
                  _buildCountAndModifier(),
                  if (room.isMj) ...[
                    const SizedBox(height: 8),
                    _buildSecretToggle(),
                  ],
                  const SizedBox(height: 24),
                  _buildResult(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _buildRollButton(),
          ),
        ],
      ),
    );
  }

  /// Réservé au MJ : un joueur qui pourrait masquer ses jets ne masquerait que
  /// ceux qui l'arrangent. La policy d'insertion le refuse de toute façon.
  Widget _buildSecretToggle() {
    return SwitchListTile(
      value: _isSecret,
      onChanged: (value) => setState(() => _isSecret = value),
      contentPadding: EdgeInsets.zero,
      title: const Text('Jet secret', style: TextStyle(color: Colors.white)),
      subtitle: const Text(
        'Visible de vous seul dans le journal',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      ),
      activeColor: _primaryColor,
    );
  }


  Widget _buildSidesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de dé',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: DiceNotation.supportedSides.map((sides) {
            final selected = _notation.sides == sides;
            return ChoiceChip(
              label: Text('d$sides'),
              selected: selected,
              onSelected: (_) => setState(() {
                _notation = _notation.copyWith(sides: sides);
              }),
              backgroundColor: _cardColor,
              selectedColor: _primaryColor,
              labelStyle: TextStyle(
                color: selected ? _bgColor : Colors.white,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: selected ? _primaryColor : Colors.white24),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCountAndModifier() {
    return Row(
      children: [
        Expanded(
          child: _buildStepper(
            label: 'Nombre de dés',
            value: _notation.count,
            display: '${_notation.count}',
            onChanged: (delta) {
              final next = _notation.count + delta;
              if (next < 1 || next > DiceNotation.maxCount) return;
              setState(() => _notation = _notation.copyWith(count: next));
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStepper(
            label: 'Modificateur',
            value: _notation.modifier,
            display: _notation.modifier > 0 ? '+${_notation.modifier}' : '${_notation.modifier}',
            onChanged: (delta) {
              final next = _notation.modifier + delta;
              if (next.abs() > DiceNotation.maxModifier) return;
              setState(() => _notation = _notation.copyWith(modifier: next));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required String display,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: _primaryColor),
                tooltip: 'Diminuer : $label',
                onPressed: () => onChanged(-1),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: _primaryColor),
                tooltip: 'Augmenter : $label',
                onPressed: () => onChanged(1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final roll = _lastRoll;

    Color accent = _primaryColor;
    String? mention;
    if (roll != null && roll.isCriticalSuccess) {
      accent = _successColor;
      mention = 'Réussite critique';
    } else if (roll != null && roll.isCriticalFailure) {
      accent = _failureColor;
      mention = 'Échec critique';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(roll == null ? 0.2 : 0.6), width: 2),
      ),
      child: roll == null
          ? Column(
              children: [
                Text(
                  _notation.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aucun jet pour l\'instant',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ],
            )
          : AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final t = _animation.value;
                final lastSettle = _settleFraction(roll.results.length - 1);
                final allSettled = t >= lastSettle;

                return Column(
                  children: [
                    Text(
                      roll.notation.label,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    _buildDice(roll, t, accent),
                    // Le calcul n'apparaît qu'une fois tous les dés posés :
                    // afficher un total pendant que les dés tournent encore
                    // enlèverait tout intérêt à les regarder.
                    AnimatedOpacity(
                      opacity: allSettled ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          if (roll.results.length > 1 || roll.notation.modifier != 0)
                            Text(
                              roll.detail,
                              style: const TextStyle(color: Colors.white70, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${roll.total}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          if (mention != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              mention,
                              style: TextStyle(
                                color: accent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Les dés du jet, chacun visible séparément.
  Widget _buildDice(DiceRoll roll, double t, Color accent) {
    final sides = roll.notation.sides;
    // Les dés rétrécissent quand ils sont nombreux, pour que la ligne reste
    // lisible sans déborder.
    final size = roll.results.length > 8 ? 48.0 : 66.0;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(roll.results.length, (i) {
        final settleAt = _settleFraction(i);
        final settled = t >= settleAt;
        final spinProgress = settleAt == 0 ? 1.0 : (t / settleAt).clamp(0.0, 1.0);

        return _DieFace(
          value: settled ? roll.results[i] : _spinningFace(i, spinProgress, sides),
          sides: sides,
          size: size,
          settled: settled,
          spinProgress: spinProgress,
          accent: accent,
        );
      }),
    );
  }

  Widget _buildRollButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.casino),
      label: Text('Lancer ${_notation.label}'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: _primaryColor,
        foregroundColor: _bgColor,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: _roll,
    );
  }

}

/// Un dé du jet, affiché seul.
///
/// Tant qu'il tourne, il oscille et flotte légèrement, sa face change de plus
/// en plus lentement, et il reste grisé. À l'arrêt il se pose d'un rebond,
/// reprend sa taille pleine et se colore : on voit lesquels sont figés sans
/// avoir à comparer les chiffres.
class _DieFace extends StatelessWidget {
  final int value;
  final int sides;
  final double size;
  final bool settled;

  /// 0 au lancer, 1 quand ce dé se fige.
  final double spinProgress;

  final Color accent;

  const _DieFace({
    required this.value,
    required this.sides,
    required this.size,
    required this.settled,
    required this.spinProgress,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // Oscillation et flottement amortis : l'amplitude décroît avec
    // `1 - spinProgress`, le dé se stabilise donc au lieu de s'arrêter net.
    final damping = 1 - spinProgress;
    final wobble = settled ? 0.0 : math.sin(spinProgress * math.pi * 7) * 0.30 * damping;
    final lift = settled ? 0.0 : -math.sin(spinProgress * math.pi * 5) * 7 * damping;

    return Semantics(
      label: settled ? 'Dé à $sides faces : $value' : 'Dé en cours de lancer',
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.rotate(
          angle: wobble,
          child: AnimatedScale(
            scale: settled ? 1 : 0.86,
            // `elasticOut` donne au dé un rebond à l'atterrissage, là où une
            // courbe classique le ferait simplement grandir.
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            child: CustomPaint(
              size: Size.square(size),
              painter: _DiePainter(
                sides: sides,
                settled: settled,
                accent: accent,
              ),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: settled ? Colors.white : Colors.white38,
                      fontSize: size * (value >= 100 ? 0.28 : 0.36),
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dessine la silhouette d'un dé.
///
/// Chaque type de dé a sa forme reconnaissable à la table : triangle pour le
/// d4, carré pour le d6, losange pour le d8, pentagone pour les d10 et d12,
/// hexagone pour les d20 et d100. Un carré unique pour tous ferait perdre
/// l'information la plus immédiate de l'écran — quel dé on lance.
class _DiePainter extends CustomPainter {
  final int sides;
  final bool settled;
  final Color accent;

  _DiePainter({
    required this.sides,
    required this.settled,
    required this.accent,
  });

  /// Nombre de côtés de la silhouette, et son orientation.
  ({int corners, double rotation}) get _shape {
    switch (sides) {
      case 4:
        return (corners: 3, rotation: 0);
      case 6:
        return (corners: 4, rotation: math.pi / 4);
      case 8:
        return (corners: 4, rotation: 0);
      case 10:
      case 12:
        return (corners: 5, rotation: 0);
      default:
        return (corners: 6, rotation: 0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final path = _roundedPolygon(
      center: center,
      radius: radius,
      corners: shape.corners,
      rotation: shape.rotation,
      cornerRadius: size.width * 0.12,
    );

    // Halo derrière un dé posé : il le détache du fond sombre.
    if (settled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: settled
              ? [accent.withOpacity(0.30), accent.withOpacity(0.10)]
              : [Colors.white12, Colors.white10],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = settled ? 2.4 : 1.2
        ..color = settled ? accent : Colors.white24,
    );
  }

  /// Polygone régulier à coins arrondis.
  ///
  /// Les sommets vifs d'un polygone tracé naïvement font tache à côté du
  /// reste de l'interface, qui est entièrement en angles adoucis.
  Path _roundedPolygon({
    required Offset center,
    required double radius,
    required int corners,
    required double rotation,
    required double cornerRadius,
  }) {
    final points = List.generate(corners, (i) {
      // -pi/2 : le premier sommet pointe vers le haut.
      final angle = rotation - math.pi / 2 + i * 2 * math.pi / corners;
      return center + Offset(math.cos(angle), math.sin(angle)) * radius;
    });

    final path = Path();
    for (var i = 0; i < corners; i++) {
      final current = points[i];
      final previous = points[(i - 1 + corners) % corners];
      final next = points[(i + 1) % corners];

      final toPrevious = _shorten(current, previous, cornerRadius);
      final toNext = _shorten(current, next, cornerRadius);

      if (i == 0) {
        path.moveTo(toPrevious.dx, toPrevious.dy);
      } else {
        path.lineTo(toPrevious.dx, toPrevious.dy);
      }
      // Le sommet devient le point de contrôle : l'angle est remplacé par une
      // courbe qui le frôle.
      path.quadraticBezierTo(current.dx, current.dy, toNext.dx, toNext.dy);
    }
    path.close();
    return path;
  }

  /// Point situé à [distance] de [from], en direction de [towards].
  Offset _shorten(Offset from, Offset towards, double distance) {
    final delta = towards - from;
    final length = delta.distance;
    if (length == 0) return from;
    // Jamais au-delà du milieu du segment, sinon les arrondis de deux sommets
    // voisins se chevauchent et la forme se replie sur elle-même.
    final clamped = math.min(distance, length / 2);
    return from + delta / length * clamped;
  }

  @override
  bool shouldRepaint(_DiePainter oldDelegate) =>
      oldDelegate.sides != sides ||
      oldDelegate.settled != settled ||
      oldDelegate.accent != accent;
}
