import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/route_observer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/format_last_update.dart';
import '../../../campaigns/presentation/widgets/campaign_card.dart';
import '../../../room/presentation/shell/room_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  late Future<List<Map<String, dynamic>>> _campaignsFuture;

  @override
  void initState() {
    super.initState();
    _campaignsFuture = _loadCampaigns();
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

  Future<List<Map<String, dynamic>>> _loadCampaigns() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    return userId == null
        ? Future.value(<Map<String, dynamic>>[])
        : authProvider.getVisibleCampaigns(userId);
  }

  @override
  void didPopNext() {
    // On revient sur l'accueil après avoir dépilé une route poussée
    // par-dessus (créer/rejoindre/ouvrir puis supprimer une room) :
    // la liste peut avoir changé, il faut la recharger.
    setState(() {
      _campaignsFuture = _loadCampaigns();
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
          // Aligné en haut : le parent `Expanded` donne toute la hauteur
          // restante, sans quoi le message se retrouverait centré au milieu
          // du vide.
          return const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Vous n'avez pas encore de room. Créez-en une ou rejoignez-en une avec un code.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // La liste occupe la hauteur que lui donne son parent `Expanded` et
        // défile sur elle-même : les boutons d'action restent ancrés en bas
        // de l'écran quel que soit le nombre de rooms.
        return ListView.separated(
          itemCount: campaigns.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            return CampaignCard(
              title: campaign['title'] as String? ?? 'Sans titre',
              lastUpdate: formatLastUpdate(
                (campaign['updated_at'] ?? campaign['created_at']) as String?,
              ),
              imageUrl: campaign['icon_url'] as String?,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RoomShell(roomId: campaign['id'] as String),
                  ),
                );
              },
            );
          },
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
      // Colonne plutôt que zone défilante : la liste des rooms absorbe la
      // hauteur disponible et les deux boutons d'action restent ancrés en bas
      // de l'écran. Sans cela, le retrait de la section « Derniers documents
      // modifiés » (bogue B22) les laissait flotter au milieu du vide.
      // `SafeArea` : sans elle, les boutons ancrés en bas passent sous la
      // barre de navigation gestuelle du téléphone.
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
              Expanded(child: _buildCampaigns()),
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
