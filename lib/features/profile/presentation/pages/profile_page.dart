import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/utils/format_relative_age.dart';
import 'package:scriptoria/core/utils/friendly_error.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Profil de l'utilisateur : ce qui le concerne vraiment, et rien d'autre.
///
/// L'écran affichait auparavant trois compteurs restés à zéro et trois onglets
/// de contenu entièrement inventé — des personnages nommés, des campagnes
/// nommées, un historique de sessions qui n'a jamais existé. Rien de tout cela
/// ne venait de la base, et le bouton « Modifier le profil » ne faisait que
/// changer une icône.
///
/// Il porte désormais l'identité réelle, une modification qui enregistre
/// vraiment, et le nombre de rooms — la seule statistique que l'application
/// sait calculer.
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String _username = '';
  String _email = '';
  String _displayName = '';
  String _bio = '';
  String? _avatarUrl;
  String? _createdAt;
  int _roomCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      // Reporté après la frame en cours : appeler le Navigator pendant la
      // construction lève « setState() called during build ».
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final profile = await auth.getUserProfile(currentUser.id);
    final campaigns = await auth.getVisibleCampaigns(currentUser.id);
    if (!mounted) return;

    setState(() {
      // Le profil applicatif peut manquer si son insertion a échoué à
      // l'inscription : on retombe alors sur ce que porte le compte
      // d'authentification, plutôt que d'afficher un écran vide.
      _username = profile?['username'] as String? ??
          currentUser.userMetadata?['username'] as String? ??
          currentUser.email?.split('@').first ??
          '';
      _email = profile?['email'] as String? ?? currentUser.email ?? '';
      _displayName = profile?['display_name'] as String? ??
          currentUser.userMetadata?['display_name'] as String? ??
          '';
      _bio = profile?['bio'] as String? ?? '';
      _avatarUrl = profile?['avatar_url'] as String?;
      _createdAt = profile?['created_at'] as String?;
      _roomCount = campaigns.length;
      _isLoading = false;
    });
  }

  void _startEditing() {
    _displayNameController.text = _displayName;
    _bioController.text = _bio;
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();

    setState(() => _isSaving = true);
    try {
      await auth.updateUserProfile(
        userId: userId,
        displayName: displayName,
        bio: bio,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _displayName = displayName;
      _bio = bio;
      _isEditing = false;
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('Mon profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEditing ? Icons.check : Icons.edit, color: _primaryColor),
              tooltip: _isEditing ? 'Enregistrer' : 'Modifier le profil',
              onPressed: _isSaving ? null : (_isEditing ? _save : _startEditing),
            ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildIdentity(),
                const SizedBox(height: 28),
                if (_isEditing) _buildEditor() else _buildBio(),
                const SizedBox(height: 28),
                _buildFacts(),
              ],
            ),
    );
  }

  Widget _buildIdentity() {
    final avatarUrl = _avatarUrl;
    final initial = (_displayName.isNotEmpty ? _displayName : _username);

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: _cardColor,
          backgroundImage:
              (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(
                  initial.isEmpty ? '?' : initial.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          _displayName.isNotEmpty ? _displayName : _username,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (_username.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '@$_username',
            style: const TextStyle(color: _primaryColor, fontSize: 14),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _email,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBio() {
    if (_bio.trim().isEmpty) {
      return const Text(
        'Aucune bio pour l\'instant.',
        style: TextStyle(color: Colors.white38, fontSize: 14),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _bio,
        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        TextField(
          controller: _displayNameController,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('Nom affiché'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bioController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('Bio'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      alignLabelWithHint: true,
      filled: true,
      fillColor: _cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Les seuls chiffres que l'application sait produire.
  ///
  /// Les compteurs « Personnages » et « Sessions » ont disparu : aucun écran
  /// ne crée de personnage, et la notion de session n'existe nulle part. Ils
  /// affichaient zéro depuis toujours.
  Widget _buildFacts() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFact(
            '$_roomCount',
            _roomCount > 1 ? 'rooms' : 'room',
          ),
          if (_createdAt != null)
            _buildFact(
              formatRelativeAge(_createdAt).replaceFirst('il y a ', ''),
              'sur Scriptoria',
            ),
        ],
      ),
    );
  }

  Widget _buildFact(String value, String label) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$value $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
