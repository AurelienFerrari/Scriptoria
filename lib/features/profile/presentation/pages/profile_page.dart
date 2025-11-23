import 'package:flutter/material.dart';
import 'package:scriptoria/core/services/supabase_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditMode = false;
  final _supabaseService = SupabaseService();

  // Données de l'utilisateur
  String username = '';
  String email = '';
  String displayName = '';
  String bio = '';
  int campaignsCount = 0;
  int charactersCount = 0;
  int sessionsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUser = _supabaseService.getCurrentUser();
      print('[PROFILE] currentUser: $currentUser');
      
      if (currentUser != null) {
        print('[PROFILE] Chargement du profil pour l\'utilisateur: ${currentUser.id}');
        final profile = await _supabaseService.getUserProfile(currentUser.id);
        print('[PROFILE] Profil reçu: $profile');
        
        if (profile != null) {
          setState(() {
            username = profile['username'] ?? '';
            email = profile['email'] ?? '';
            displayName = profile['display_name'] ?? '';
            bio = profile['bio'] ?? '';
          });
        } else {
          print('[PROFILE] Profil est null - utilisation des données d\'authentification');
          // Utiliser les données de Supabase Auth si le profil n'est pas accessible
          final displayNameFromAuth = currentUser.userMetadata?['display_name'] as String? ?? 'Utilisateur';
          final usernameFromAuth = currentUser.userMetadata?['username'] as String? ?? currentUser.email?.split('@')[0] ?? 'user';
          
          setState(() {
            username = usernameFromAuth;
            email = currentUser.email ?? '';
            displayName = displayNameFromAuth;
            bio = '';
          });
        }
      } else {
        print('[PROFILE] Utilisateur non connecté, redirection vers login');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }
      // Toujours arrêter le chargement, même si les données sont vides
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('[PROFILE] Erreur lors du chargement du profil: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6FE3E1);
    const Color bgColor = Color(0xFF161622);
    const Color cardColor = Color(0xFF232336);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditMode ? Icons.check : Icons.edit,
              color: primaryColor,
            ),
            onPressed: () {
              setState(() => _isEditMode = !_isEditMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              // TODO: Naviguer vers les paramètres
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Padding pour éviter la barre de nav système
                  // ============ HEADER PROFIL ============
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cardColor,
                          bgColor,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        // Avatar avec badge
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: cardColor,
                                child: const Icon(
                                  Icons.person,
                                  size: 72,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor,
                                  border: Border.all(color: bgColor, width: 3),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: bgColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Nom d'utilisateur
                        Text(
                          username.isNotEmpty ? username : 'Utilisateur',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Email
                        Text(
                          email.isNotEmpty ? email : 'Email non disponible',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Bio
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            bio.isNotEmpty ? bio : 'Aucune bio',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

            // ============ STATISTIQUES ============
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Campagnes', campaignsCount.toString(), primaryColor),
                  _buildStatCard('Personnages', charactersCount.toString(), primaryColor),
                  _buildStatCard('Sessions', sessionsCount.toString(), primaryColor),
                ],
              ),
            ),

            // ============ ONGLETS ============
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: bgColor,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Campagnes'),
                  Tab(text: 'Personnages'),
                  Tab(text: 'Activité'),
                ],
              ),
            ),

            // ============ CONTENU DES ONGLETS ============
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Onglet Campagnes
                  _buildCampaignsTab(),
                  // Onglet Personnages
                  _buildCharactersTab(),
                  // Onglet Activité
                  _buildActivityTab(),
                ],
              ),
            ),

            // ============ BOUTONS D'ACTION ============
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Naviguer vers paramètres
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Modifier le profil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Afficher une confirmation
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF232336),
                              title: const Text(
                                'Déconnexion',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Êtes-vous sûr de vouloir vous déconnecter?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Annuler', style: TextStyle(color: Color(0xFF6FE3E1))),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await _supabaseService.signOut();
                                    if (mounted) {
                                      Navigator.pop(context);
                                      // Utiliser popUntil pour revenir à la racine, puis naviguer vers login
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                      Navigator.of(context).pushReplacementNamed('/login');
                                    }
                                  },
                                  child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Déconnexion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[400],
                        side: BorderSide(color: Colors.red[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
            ),
    );
  }

  // ============ WIDGETS HELPERS ============

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF232336),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCampaignItem(
          'Les Chroniques d\'Eldoria',
          'Fantasy',
          '2 joueurs',
          Icons.castle,
        ),
        const SizedBox(height: 12),
        _buildCampaignItem(
          'Station Omega-7',
          'Sci-Fi',
          '1 joueur',
          Icons.rocket,
        ),
      ],
    );
  }

  Widget _buildCharactersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCharacterItem('Lunaéa', 'Mage', 'Eldoria', Colors.purple),
        const SizedBox(height: 12),
        _buildCharacterItem('Thorn', 'Guerrier', 'Eldoria', Colors.red),
        const SizedBox(height: 12),
        _buildCharacterItem('Iris-7', 'Ingénieur', 'Omega-7', Colors.blue),
      ],
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildActivityItem(
          'Session 1 - La Porte de Brume',
          'Eldoria',
          'Il y a 7 jours',
          Icons.videogame_asset,
        ),
        const SizedBox(height: 12),
        _buildActivityItem(
          'Création du personnage Iris-7',
          'Omega-7',
          'Il y a 3 jours',
          Icons.person_add,
        ),
        const SizedBox(height: 12),
        _buildActivityItem(
          'Rejointe la campagne Eldoria',
          'Eldoria',
          'Il y a 30 jours',
          Icons.group_add,
        ),
      ],
    );
  }

  Widget _buildCampaignItem(
    String title,
    String setting,
    String members,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232336),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6FE3E1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6FE3E1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6FE3E1), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      setting,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      members,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
        ],
      ),
    );
  }

  Widget _buildCharacterItem(
    String name,
    String class_,
    String campaign,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232336),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        class_,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      campaign,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String campaign,
    String date,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232336),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6FE3E1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6FE3E1), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      campaign,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
