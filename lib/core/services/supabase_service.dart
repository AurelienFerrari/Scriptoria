import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:scriptoria/config/supabase_credentials.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  late SupabaseClient _client;
  late SharedPreferences _prefs;

  Future<void> initialize() async {
    // Récupérer les clés Supabase
    String? supabaseUrl;
    String? supabaseAnonKey;

    // 1. Essayer de charger depuis les variables d'environnement système d'abord
    // (dart:io Platform n'existe pas sur le web, on saute cette étape dans ce cas)
    if (!kIsWeb) {
      supabaseUrl = Platform.environment['SUPABASE_URL'];
      supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];
      if (supabaseUrl != null && supabaseAnonKey != null) {
        print('✓ Variables chargées depuis les variables d\'environnement système');
      }
    }

    // 2. Sinon, essayer de charger depuis .env
    if (supabaseUrl == null || supabaseAnonKey == null) {
      try {
        await dotenv.load(fileName: '.env');
        supabaseUrl = dotenv.env['SUPABASE_URL'];
        supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
        if (supabaseUrl != null && supabaseAnonKey != null) {
          print('✓ Variables chargées depuis .env');
        }
      } catch (e) {
        print('Fichier .env non trouvé');
      }
    }

    // 3. Sinon, utiliser les clés du fichier de configuration
    if (supabaseUrl == null || supabaseAnonKey == null) {
      supabaseUrl = SupabaseCredentials.supabaseUrl;
      supabaseAnonKey = SupabaseCredentials.supabaseAnonKey;
      print('✓ Variables chargées depuis supabase_credentials.dart');
    }

    if (supabaseUrl.contains('YOUR_PROJECT_ID') ||
        supabaseAnonKey.contains('YOUR_ANON_KEY')) {
      throw Exception(
        'Erreur: Variables d\'environnement Supabase non configurées.\n\n'
        'Solutions:\n'
        '1. Remplissez lib/config/supabase_credentials.dart avec vos vraies clés\n'
        '   (Ce fichier est dans .gitignore et ne sera jamais commité)\n\n'
        '2. Ou définissez les variables d\'environnement système:\n'
        '   set SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co\n'
        '   set SUPABASE_ANON_KEY=YOUR_ANON_KEY\n'
        '   flutter run\n\n'
        '3. Ou créez un fichier .env à la racine du projet\n\n'
        'Voir SUPABASE_SETUP.md pour plus de détails.',
      );
    }

    print('Initialisation Supabase avec URL: $supabaseUrl');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    _prefs = await SharedPreferences.getInstance();
  }

  SupabaseClient get client => _client;
  SharedPreferences get prefs => _prefs;

  // ============ AUTHENTIFICATION ============

  /// Créer un compte utilisateur
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      // Nettoyer l'email: trim et convertir en minuscules
      final cleanEmail = email.trim().toLowerCase();
      print('[SUPABASE] Email envoyé: "$cleanEmail" (length: ${cleanEmail.length})');
      print('[SUPABASE] Email original: "$email"');
      
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'username': username,
          'display_name': displayName,
        },
      );

      if (response.user != null) {
        // Créer le profil utilisateur dans la table users
        await createUserProfile(
          userId: response.user!.id,
          email: cleanEmail,
          username: username,
          displayName: displayName,
        );
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Se connecter avec email et mot de passe
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _prefs.setString('user_id', response.user!.id);
        await _prefs.setString('user_email', response.user!.email ?? '');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Se déconnecter
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      await _prefs.remove('user_id');
      await _prefs.remove('user_email');
    } catch (e) {
      rethrow;
    }
  }

  /// Récupérer l'utilisateur actuel
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Vérifier si l'utilisateur est connecté
  bool isUserLoggedIn() {
    return _client.auth.currentUser != null;
  }

  /// Émet un événement à chaque changement d'état d'authentification, y
  /// compris `AuthChangeEvent.passwordRecovery` quand l'utilisateur arrive
  /// via le deep link de réinitialisation de mot de passe (voir main.dart).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// URL de deep link vers laquelle Supabase redirige après confirmation
  /// d'email ou clic sur un lien de réinitialisation de mot de passe.
  /// Doit être enregistrée comme schéma custom côté natif (voir
  /// AndroidManifest.xml / Info.plist) et ajoutée à l'allow-list "Redirect
  /// URLs" du projet Supabase (Authentication > URL Configuration).
  static const String authCallbackUrl = 'com.example.scriptoria://reset-callback/';

  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: authCallbackUrl);
    } catch (e) {
      rethrow;
    }
  }

  /// Mettre à jour le mot de passe
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      rethrow;
    }
  }

  // ============ PROFIL UTILISATEUR ============

  /// Créer le profil utilisateur dans la table users
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String username,
    required String displayName,
  }) async {
    try {
      print('[SUPABASE] Création du profil pour email: $email');
      final userData = {
        'id': userId,
        'email': email,
        'username': username,
        'display_name': displayName,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('[SUPABASE] Données à insérer: $userData');
      await _client.from('users').insert(userData);
      print('[SUPABASE] Profil créé avec succès pour $email');
    } catch (e) {
      print('[SUPABASE] Erreur création profil: $e');
      print('[SUPABASE] Type d\'erreur: ${e.runtimeType}');
    }
  }

  /// Récupérer le profil utilisateur par email
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Récupérer l'utilisateur actuel pour obtenir son email
      final currentUser = _client.auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        print('[SUPABASE] Utilisateur non connecté ou email non disponible');
        return null;
      }
      
      print('[SUPABASE] Récupération du profil pour email: ${currentUser.email}');
      
      // Chercher le profil par email (email est la clé primaire)
      final response = await _client
          .from('users')
          .select()
          .eq('email', currentUser.email!)
          .maybeSingle();
      
      if (response != null) {
        print('[SUPABASE] Profil trouvé pour ${currentUser.email}');
      } else {
        print('[SUPABASE] Aucun profil trouvé pour ${currentUser.email}');
      }
      
      return response;
    } catch (e) {
      print('[SUPABASE] Erreur lors de la récupération du profil: $e');
      print('[SUPABASE] Type d\'erreur: ${e.runtimeType}');
      return null;
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _client.from('users').update(updates).eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Vérifier si un username est disponible
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('username', username);
      return response.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============ STOCKAGE DE FICHIERS ============

  /// Uploader une image vers un bucket de stockage et retourne son URL publique.
  /// `file.readAsBytes()` (XFile de image_picker) fonctionne aussi bien sur le
  /// web que sur mobile/desktop, contrairement à `dart:io.File` qui n'existe
  /// pas sur Flutter Web.
  Future<String?> uploadImage({
    required XFile file,
    required String bucket,
    required String fileName,
  }) async {
    final bytes = await file.readAsBytes();
    await _client.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
    return _client.storage.from(bucket).getPublicUrl(fileName);
  }

  /// Supprimer une image
  Future<void> deleteImage({
    required String bucket,
    required String fileName,
  }) async {
    await _client.storage.from(bucket).remove([fileName]);
  }

  // ============ GALERIE D'UNE ROOM ============

  /// Bucket où sont déposées les images de galerie.
  static const String galleryBucket = 'images';

  /// Publie une image dans la galerie d'une room.
  ///
  /// Deux écritures : le fichier dans Storage, puis la ligne dans `images` qui
  /// le rend découvrable par les membres. Le chemin commence par l'identifiant
  /// de l'utilisateur, ce qu'exige la policy Storage `images_owner_write`.
  ///
  /// La policy `images_insert_own_mj` réserve la publication au MJ ; un joueur
  /// qui contournerait l'interface verrait son insertion refusée.
  /// [visibleTo] désigne les destinataires : `null` pour tous les membres,
  /// liste vide pour personne (l'image est préparée mais pas révélée), sinon
  /// les joueurs autorisés. Une image arrive masquée par défaut, pour qu'une
  /// révélation ne puisse pas fuiter le temps de la restreindre.
  Future<Map<String, dynamic>> addCampaignImage({
    required XFile file,
    required String campaignId,
    required String ownerId,
    List<String>? visibleTo = const [],
  }) async {
    final path =
        '$ownerId/campaign-$campaignId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    final url = await uploadImage(
      file: file,
      bucket: galleryBucket,
      fileName: path,
    );

    return await _client
        .from('images')
        .insert({
          'owner_id': ownerId,
          'campaign_id': campaignId,
          'bucket': galleryBucket,
          'path': path,
          'url': url,
          'visible_to': visibleTo,
        })
        .select()
        .single();
  }

  /// Change les destinataires d'une image déjà publiée.
  ///
  /// Même convention que [addCampaignImage] : `null` ouvre l'image à tous les
  /// membres, une liste vide la masque à tout le monde sauf au MJ.
  Future<void> updateImageVisibility({
    required String imageId,
    required List<String>? visibleTo,
  }) async {
    await _client
        .from('images')
        .update({'visible_to': visibleTo})
        .eq('id', imageId);
  }

  /// Images publiées dans une room, de la plus récente à la plus ancienne.
  Future<List<Map<String, dynamic>>> getCampaignImages(String campaignId) async {
    try {
      return await _client
          .from('images')
          .select()
          .eq('campaign_id', campaignId)
          .order('created_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  /// Retire une image de la galerie d'une room.
  ///
  /// La ligne part en premier : c'est elle qui fait foi pour l'affichage, et
  /// une ligne pointant vers un fichier absent afficherait une image cassée.
  /// L'échec de la suppression du fichier est en revanche toléré — le MJ peut
  /// retirer l'image d'un autre sans posséder son fichier dans Storage. Mieux
  /// vaut un fichier orphelin dans un bucket qu'une galerie qu'on ne peut plus
  /// nettoyer.
  Future<void> removeCampaignImage({
    required String imageId,
    required String bucket,
    required String path,
  }) async {
    await _client.from('images').delete().eq('id', imageId);

    try {
      await deleteImage(bucket: bucket, fileName: path);
    } catch (e) {
      debugPrint('Fichier $path non supprimé du bucket $bucket : $e');
    }
  }

  // ============ REQUÊTES GÉNÉRIQUES ============

  /// Récupérer les campagnes d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserCampaigns(String userId) async {
    try {
      final response = await _client
          .from('campaigns')
          .select()
          .eq('creator_id', userId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      return [];
    }
  }

  /// Récupère les campagnes visibles par un utilisateur : celles qu'il a
  /// créées, plus celles qu'il a rejointes via un code (table
  /// `campaign_members`, alimentée par [joinCampaign]).
  Future<List<Map<String, dynamic>>> getVisibleCampaigns(String userId) async {
    try {
      final owned = await _client
          .from('campaigns')
          .select()
          .eq('creator_id', userId);

      final joinedRows = await _client
          .from('campaign_members')
          .select('campaigns(*)')
          .eq('user_id', userId);
      final joined = joinedRows
          .map((row) => row['campaigns'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>();

      final byId = <String, Map<String, dynamic>>{};
      for (final campaign in [...owned, ...joined]) {
        byId[campaign['id'] as String] = campaign;
      }

      final result = byId.values.toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return result;
    } catch (e) {
      return [];
    }
  }

  /// Enregistre qu'un utilisateur a rejoint une campagne via son code
  /// d'invitation. `ignoreDuplicates` permet de rejoindre à nouveau la même
  /// room sans provoquer d'erreur de contrainte unique.
  Future<void> joinCampaign({
    required String campaignId,
    required String userId,
  }) async {
    await _client.from('campaign_members').upsert(
      {'campaign_id': campaignId, 'user_id': userId},
      onConflict: 'campaign_id,user_id',
      ignoreDuplicates: true,
    );
  }

  /// Rôle d'un utilisateur dans une campagne : `'mj'`, `'player'`, ou `null`
  /// s'il n'en est pas membre.
  ///
  /// Le rattachement du créateur en tant que MJ est assuré par un trigger
  /// côté base (`campaigns_add_creator_as_mj`) : aucune campagne ne peut
  /// exister sans meneur, même si le client échoue entre deux appels.
  Future<String?> getMemberRole({
    required String campaignId,
    required String userId,
  }) async {
    try {
      final row = await _client
          .from('campaign_members')
          .select('role')
          .eq('campaign_id', campaignId)
          .eq('user_id', userId)
          .maybeSingle();
      return row?['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Membres d'une campagne, avec leur rôle et leur profil public.
  ///
  /// Deux requêtes plutôt qu'une imbrication PostgREST : `campaign_members`
  /// référence `auth.users`, schéma que PostgREST n'expose pas, donc
  /// `select('users(...)')` n'aurait aucune relation à suivre. La liste des
  /// membres d'une room reste petite, le coût est négligeable.
  ///
  /// Le profil peut manquer si l'insertion dans `users` a échoué à
  /// l'inscription : les champs sont alors `null`, à l'appelant de prévoir
  /// un libellé de repli.
  Future<List<Map<String, dynamic>>> getCampaignMembers(String campaignId) async {
    try {
      final memberships = await _client
          .from('campaign_members')
          .select('user_id, role, joined_at')
          .eq('campaign_id', campaignId)
          .order('joined_at');

      if (memberships.isEmpty) return [];

      final profiles = await _client
          .from('users')
          .select('id, username, display_name, avatar_url')
          .inFilter(
            'id',
            memberships.map((m) => m['user_id'] as String).toList(),
          );

      final profileById = {
        for (final profile in profiles) profile['id'] as String: profile,
      };

      return memberships.map((membership) {
        final profile = profileById[membership['user_id']];
        return <String, dynamic>{
          'user_id': membership['user_id'],
          'role': membership['role'],
          'joined_at': membership['joined_at'],
          'username': profile?['username'],
          'display_name': profile?['display_name'],
          'avatar_url': profile?['avatar_url'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retire un membre d'une campagne.
  ///
  /// La policy `campaign_members_delete_self_or_mj` fait foi : seul le MJ (ou
  /// le joueur lui-même) y parvient, et la ligne d'un MJ n'est jamais
  /// supprimable — une campagne ne doit pas se retrouver sans meneur.
  Future<void> removeCampaignMember({
    required String campaignId,
    required String userId,
  }) async {
    await _client
        .from('campaign_members')
        .delete()
        .eq('campaign_id', campaignId)
        .eq('user_id', userId);
  }

  /// Met à jour les champs modifiables d'une campagne et renvoie la ligne à
  /// jour. La policy `campaigns_update_own` réserve l'écriture au créateur.
  Future<Map<String, dynamic>?> updateCampaign({
    required String campaignId,
    String? title,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    };

    return await _client
        .from('campaigns')
        .update(payload)
        .eq('id', campaignId)
        .select()
        .maybeSingle();
  }

  /// Crée une campagne (room) et renvoie la ligne créée
  Future<Map<String, dynamic>> createCampaign({
    required String creatorId,
    required String title,
    required String description,
    String? iconUrl,
    required int maxPlayers,
    required String joinCode,
  }) async {
    final response = await _client
        .from('campaigns')
        .insert({
          'creator_id': creatorId,
          'title': title,
          'description': description,
          'icon_url': iconUrl,
          'max_players': maxPlayers,
          'join_code': joinCode,
        })
        .select()
        .single();
    return response;
  }

  /// Récupère une campagne (room) par son id
  Future<Map<String, dynamic>?> getCampaignById(String id) async {
    try {
      final response = await _client
          .from('campaigns')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Supprime une campagne (room). La policy RLS `campaigns_delete_own`
  /// garantit que seul son créateur peut effectivement la supprimer.
  Future<void> deleteCampaign(String campaignId) async {
    await _client.from('campaigns').delete().eq('id', campaignId);
  }

  /// Recherche une campagne par son code d'invitation
  Future<Map<String, dynamic>?> getCampaignByJoinCode(String joinCode) async {
    try {
      final response = await _client
          .from('campaigns')
          .select()
          .eq('join_code', joinCode)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Récupérer les personnages d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserCharacters(String userId) async {
    try {
      final response = await _client
          .from('characters')
          .select()
          .eq('creator_id', userId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      return [];
    }
  }

  /// Récupérer les images accessibles par un utilisateur
  Future<List<Map<String, dynamic>>> getAccessibleImages(String userId) async {
    try {
      final response = await _client.rpc(
        'get_user_accessible_images',
        params: {'p_user_id': userId},
      ) as List;
      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
