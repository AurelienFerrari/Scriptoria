import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/route_observer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/format_last_update.dart';
import '../../../campaigns/presentation/widgets/campaign_card.dart';
import '../widgets/recent_activity_section.dart';
import '../../../room/presentation/shell/room_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  late Future<List<Map<String, dynamic>>> _campaignsFuture;
  late Future<List<Map<String, dynamic>>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _campaignsFuture = _loadCampaigns();
    _activityFuture = _loadActivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Charge les campagnes **et** leurs compteurs en une passe.
  ///
  /// Les compteurs arrivent d'une seule requête sur la vue
  /// `campaign_overview` : une par campagne en aurait fait une dizaine pour
  /// trois rooms.
  Future<List<Map<String, dynamic>>> _loadCampaigns() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    if (userId == null) return <Map<String, dynamic>>[];

    final campaigns = await authProvider.getVisibleCampaigns(userId);
    if (campaigns.isEmpty) return campaigns;

    final overviews = await authProvider.getCampaignOverviews(
      campaigns.map((campaign) => campaign['id'] as String).toList(),
    );

    return campaigns
        .map((campaign) => {
              ...campaign,
              'overview': overviews[campaign['id']] ?? const <String, int>{},
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadActivity() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser == null) {
      return Future.value(<Map<String, dynamic>>[]);
    }
    return authProvider.getRecentActivity();
  }

  void _openRoom(String campaignId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoomShell(roomId: campaignId)),
    );
  }

  @override
  void didPopNext() {
    // On revient sur l'accueil après avoir dépilé une route poussée
    // par-dessus (créer/rejoindre/ouvrir puis supprimer une room) :
    // la liste peut avoir changé, il faut la recharger.
    setState(() {
      _campaignsFuture = _loadCampaigns();
      _activityFuture = _loadActivity();
    });
  }

  Widget _buildCampaigns() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _campaignsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final campaigns = snapshot.data ?? [];
        if (campaigns.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Vous n'avez pas encore de room. Créez-en une ou rejoignez-en une avec un code.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // La liste ne défile pas d'elle-même : c'est la page entière qui
        // défile, pour que les cartes et l'activité récente se suivent au lieu
        // de se disputer la hauteur disponible.
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: campaigns.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            final overview =
                (campaign['overview'] as Map<String, int>?) ?? const {};

            return CampaignCard(
              title: campaign['title'] as String? ?? 'Sans titre',
              description: campaign['description'] as String? ?? '',
              lastUpdate: formatLastUpdate(
                (campaign['updated_at'] ?? campaign['created_at']) as String?,
              ),
              imageUrl: campaign['icon_url'] as String?,
              memberCount: overview['members'],
              imageCount: overview['images'],
              noteCount: overview['notes'],
              onTap: () => _openRoom(campaign['id'] as String),
            );
          },
        );
      },
    );
  }

  Widget _buildActivity() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _activityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        return RecentActivitySection(
          activity: snapshot.data ?? const [],
          onOpenRoom: _openRoom,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png',
                height: 40, excludeFromSemantics: true),
            const SizedBox(width: 12),
            const Text('Accueil'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Semantics(
              button: true,
              label: 'Voir le profil',
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: const Icon(Icons.person_outline),
                ),
              ),
            ),
          ),
        ],
      ),
      // Le contenu défile dans un `Expanded`, les deux boutons d'action
      // restent ancrés en bas. Sans cet ancrage, le retrait de la section de
      // démonstration (bogue B22) les laissait flotter au milieu du vide.
      // `SafeArea` : sans elle, ils passent sous la barre de navigation
      // gestuelle du téléphone.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Campagnes en cours',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCampaigns(),
                      const SizedBox(height: 28),
                      _buildActivity(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/CreationRoom');
                      },
                      label: const Text(
                        'Créer une room',
                        style: TextStyle(
                          color: Color(0xFFB39DDB),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: const BorderSide(
                            color: Color(0xFFB39DDB), width: 2),
                        backgroundColor: Colors.white.withOpacity(0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        shadowColor: Colors.black.withOpacity(0.12),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/JoinRoom');
                      },
                      label: const Text(
                        'Rejoindre une room',
                        style: TextStyle(
                          color: Color(0xFFB39DDB),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: const BorderSide(
                            color: Color(0xFFB39DDB), width: 2),
                        backgroundColor: Colors.white.withOpacity(0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        shadowColor: Colors.black.withOpacity(0.12),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
