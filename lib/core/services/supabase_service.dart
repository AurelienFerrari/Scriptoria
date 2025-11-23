import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:scriptoria/config/supabase_credentials.dart';
import 'package:crypto/crypto.dart';

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
    supabaseUrl = Platform.environment['SUPABASE_URL'];
    supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];
    if (supabaseUrl != null && supabaseAnonKey != null) {
      print('✓ Variables chargées depuis les variables d\'environnement système');
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

    if (supabaseUrl == null || supabaseAnonKey == null || 
        supabaseUrl.contains('YOUR_PROJECT_ID') || 
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
          password: password,
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

  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
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
    String? password,
  }) async {
    try {
      print('[SUPABASE] Création du profil pour email: $email');
      final userData = {
        'email': email,
        'username': username,
        'display_name': displayName,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Ajouter le hash du mot de passe s'il est fourni
      if (password != null && password.isNotEmpty) {
        userData['password_hash'] = sha256.convert(password.codeUnits).toString();
      }

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

  /// Uploader une image
  Future<String?> uploadImage({
    required String filePath,
    required String bucket,
    required String fileName,
  }) async {
    try {
      final file = await _readFile(filePath);
      await _client.storage.from(bucket).uploadBinary(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _client.storage.from(bucket).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Supprimer une image
  Future<void> deleteImage({
    required String bucket,
    required String fileName,
  }) async {
    try {
      await _client.storage.from(bucket).remove([fileName]);
    } catch (e) {
      rethrow;
    }
  }

  /// Lire un fichier (helper) - Retourne Uint8List
  Future<Uint8List> _readFile(String filePath) async {
    // À implémenter selon votre système de fichiers
    // Exemple avec dart:io:
    // import 'dart:io';
    // final file = File(filePath);
    // return await file.readAsBytes();
    throw UnimplementedError('Implémenter la lecture de fichier');
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
