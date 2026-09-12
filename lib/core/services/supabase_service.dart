import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:scriptoria/config/supabase_credentials.dart';
import 'row_change.dart';

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
        print(
            '✓ Variables chargées depuis les variables d\'environnement système');
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
      print(
          '[SUPABASE] Email envoyé: "$cleanEmail" (length: ${cleanEmail.length})');
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
  static const String authCallbackUrl =
      'com.example.scriptoria://reset-callback/';

  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth
          .resetPasswordForEmail(email, redirectTo: authCallbackUrl);
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

      print(
          '[SUPABASE] Récupération du profil pour email: ${currentUser.email}');

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
      final response =
          await _client.from('users').select().eq('username', username);
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
        .update({'visible_to': visibleTo}).eq('id', imageId);
  }

  /// Images publiées dans une room, de la plus récente à la plus ancienne.
  Future<List<Map<String, dynamic>>> getCampaignImages(
      String campaignId) async {
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

  // ============ ACCUEIL ============

  /// Compteurs (membres, images, notes) des campagnes données, indexés par
  /// identifiant de campagne.
  ///
  /// Une seule requête pour toute la liste, via la vue `campaign_overview`.
  /// Celle-ci s'exécute en `security_invoker`, si bien que chacun obtient les
  /// compteurs de ce qu'il a le droit de voir : un joueur ne compte que les
  /// images qui lui sont ouvertes, et jamais les notes du MJ.
  Future<Map<String, Map<String, int>>> getCampaignOverviews(
    List<String> campaignIds,
  ) async {
    if (campaignIds.isEmpty) return {};

    try {
      final rows = await _client
          .from('campaign_overview')
          .select()
          .inFilter('campaign_id', campaignIds);

      return {
        for (final row in rows)
          row['campaign_id'] as String: {
            'members': (row['member_count'] as num?)?.toInt() ?? 0,
            'images': (row['image_count'] as num?)?.toInt() ?? 0,
            'notes': (row['note_count'] as num?)?.toInt() ?? 0,
          },
      };
    } catch (e) {
      return {};
    }
  }

  /// Dernières activités visibles par l'utilisateur, toutes rooms confondues.
  ///
  /// Notes et images sont récupérées séparément puis fusionnées par date. La
  /// RLS fait le tri par rôle sans qu'on ait à le demander : un MJ récupère
  /// ses notes, un joueur n'en reçoit aucune et ne voit que les images qui lui
  /// ont été ouvertes.
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 6}) async {
    try {
      final notes = await _client
          .from('room_notes')
          .select('id, title, updated_at, campaign_id, campaigns(title)')
          .order('updated_at', ascending: false)
          .limit(limit);

      final images = await _client
          .from('images')
          .select('id, url, created_at, campaign_id, campaigns(title)')
          .not('campaign_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit);

      String campaignTitle(Map<String, dynamic> row) =>
          (row['campaigns'] as Map<String, dynamic>?)?['title'] as String? ??
          'Room';

      final activity = <Map<String, dynamic>>[
        for (final note in notes)
          {
            'kind': 'note',
            'id': note['id'],
            'label': note['title'],
            'campaign_id': note['campaign_id'],
            'campaign_title': campaignTitle(note),
            'at': note['updated_at'],
          },
        for (final image in images)
          {
            'kind': 'image',
            'id': image['id'],
            'label': 'Image partagée',
            'url': image['url'],
            'campaign_id': image['campaign_id'],
            'campaign_title': campaignTitle(image),
            'at': image['created_at'],
          },
      ];

      activity.sort(
        (a, b) =>
            (b['at'] as String? ?? '').compareTo(a['at'] as String? ?? ''),
      );

      return activity.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // ============ FIL DE LA ROOM ============

  /// Publications du fil d'une room, de la plus récente à la plus ancienne.
  ///
  /// Le filtrage par destinataire est fait par la RLS : un joueur ne reçoit
  /// que ce qui lui est adressé, sans que cette méthode ait à le savoir.
  Future<List<Map<String, dynamic>>> getRoomPosts(String campaignId) async {
    try {
      return await _client
          .from('room_posts')
          .select()
          .eq('campaign_id', campaignId)
          .order('created_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  /// Publie sur le fil d'une room.
  ///
  /// L'image éventuelle est déposée dans le bucket `images` mais **pas**
  /// enregistrée dans la table du même nom : sans quoi elle apparaîtrait aussi
  /// dans la galerie, où le MJ ne l'a pas mise.
  ///
  /// [visibleTo] suit la convention habituelle : `null` pour tous les membres,
  /// sinon les joueurs destinataires.
  Future<Map<String, dynamic>> createRoomPost({
    required String campaignId,
    required String authorId,
    String? body,
    XFile? image,
    List<String>? visibleTo,
  }) async {
    String? url;
    String? path;

    if (image != null) {
      path =
          '$authorId/post-$campaignId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      url = await uploadImage(
        file: image,
        bucket: galleryBucket,
        fileName: path,
      );
    }

    return await _client
        .from('room_posts')
        .insert({
          'campaign_id': campaignId,
          'author_id': authorId,
          'body': body,
          'image_url': url,
          'image_bucket': image == null ? null : galleryBucket,
          'image_path': path,
          'visible_to': visibleTo,
        })
        .select()
        .single();
  }

  Future<void> updateRoomPostAudience({
    required String postId,
    required List<String>? visibleTo,
  }) async {
    await _client
        .from('room_posts')
        .update({'visible_to': visibleTo}).eq('id', postId);
  }

  /// Supprime une publication, et son image si elle en portait une.
  ///
  /// La ligne part en premier : c'est elle qui fait foi pour l'affichage. Un
  /// fichier qui resterait sans elle n'est qu'un orphelin dans un bucket, là
  /// où une ligne pointant vers un fichier absent afficherait une image
  /// cassée.
  Future<void> deleteRoomPost(Map<String, dynamic> post) async {
    await _client.from('room_posts').delete().eq('id', post['id'] as String);

    final bucket = post['image_bucket'] as String?;
    final path = post['image_path'] as String?;
    if (bucket == null || path == null) return;

    try {
      await deleteImage(bucket: bucket, fileName: path);
    } catch (e) {
      debugPrint('Fichier $path non supprimé du bucket $bucket : $e');
    }
  }

  // ============ NOTES DU MJ ============

  /// Notes d'une room, de la plus récemment modifiée à la plus ancienne.
  ///
  /// Inutile de filtrer sur le rôle ici : la policy `room_notes_select_mj`
  /// renvoie une liste vide à un joueur.
  Future<List<Map<String, dynamic>>> getRoomNotes(String campaignId) async {
    try {
      return await _client
          .from('room_notes')
          .select()
          .eq('campaign_id', campaignId)
          .order('updated_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createRoomNote({
    required String campaignId,
    required String authorId,
    required String title,
    String contentMd = '',
  }) async {
    return await _client
        .from('room_notes')
        .insert({
          'campaign_id': campaignId,
          'author_id': authorId,
          'title': title,
          'content_md': contentMd,
        })
        .select()
        .single();
  }

  /// `updated_at` n'est pas envoyé : un trigger le tient côté base, une date
  /// de modification dépendant du client ne voudrait rien dire.
  Future<void> updateRoomNote({
    required String noteId,
    String? title,
    String? contentMd,
  }) async {
    await _client.from('room_notes').update({
      if (title != null) 'title': title,
      if (contentMd != null) 'content_md': contentMd,
    }).eq('id', noteId);
  }

  Future<void> deleteRoomNote(String noteId) async {
    await _client.from('room_notes').delete().eq('id', noteId);
  }

  // ============ FRISE CHRONOLOGIQUE ============

  /// Évènements de la frise, dans l'ordre voulu par le MJ.
  ///
  /// Aucun filtre sur le rôle ni sur `visible_to` : la policy
  /// `room_timeline_select_member` écarte déjà les évènements qu'un joueur n'a
  /// pas à voir. Refaire le tri ici donnerait une seconde règle à maintenir,
  /// et c'est toujours celle de la base qui ferait foi.
  Future<List<Map<String, dynamic>>> getTimelineEvents(
      String campaignId) async {
    try {
      return await _client
          .from('room_timeline_events')
          .select()
          .eq('campaign_id', campaignId)
          .order('position', ascending: true);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createTimelineEvent({
    required String campaignId,
    required String authorId,
    required String title,
    String dateLabel = '',
    String description = '',
    int position = 0,
    List<String>? visibleTo,
  }) async {
    return await _client
        .from('room_timeline_events')
        .insert({
          'campaign_id': campaignId,
          'author_id': authorId,
          'title': title,
          'date_label': dateLabel,
          'description': description,
          'position': position,
          'visible_to': visibleTo,
        })
        .select()
        .single();
  }

  /// Réécrit tout ce que l'éditeur expose.
  ///
  /// `visible_to` est envoyé même à `null`, contrairement aux champs
  /// optionnels d'`updateRoomNote` : ici `null` est une valeur qui veut dire
  /// « tous les joueurs », pas une absence de changement. L'omettre rendrait
  /// impossible de rouvrir un évènement à la table.
  Future<void> updateTimelineEvent({
    required String eventId,
    required String title,
    required String dateLabel,
    required String description,
    required List<String>? visibleTo,
  }) async {
    await _client.from('room_timeline_events').update({
      'title': title,
      'date_label': dateLabel,
      'description': description,
      'visible_to': visibleTo,
    }).eq('id', eventId);
  }

  /// Applique un nouvel ordre à la frise.
  ///
  /// Seules les lignes dont la position change sont envoyées : réordonner deux
  /// évènements voisins ne doit pas réécrire toute la frise.
  Future<void> updateTimelinePositions(Map<String, int> positionById) async {
    for (final entry in positionById.entries) {
      await _client
          .from('room_timeline_events')
          .update({'position': entry.value}).eq('id', entry.key);
    }
  }

  Future<void> deleteTimelineEvent(String eventId) async {
    await _client.from('room_timeline_events').delete().eq('id', eventId);
  }

  // ============ CHAT DE LA ROOM ============

  /// Nombre de messages chargés à l'ouverture du chat.
  static const int chatHistoryLimit = 100;

  /// Derniers messages de la room, du plus ancien au plus récent.
  ///
  /// Aucun filtre sur les chuchotements ici : la policy
  /// `room_messages_select_audience` ne renvoie à chacun que ce qu'il a le
  /// droit de lire.
  Future<List<Map<String, dynamic>>> getRoomMessages(String campaignId) async {
    try {
      final rows = await _client
          .from('room_messages')
          .select()
          .eq('campaign_id', campaignId)
          .order('created_at', ascending: false)
          .limit(chatHistoryLimit);
      // Demandés du plus récent au plus ancien, pour que la limite garde les
      // derniers ; remis ensuite dans l'ordre de lecture.
      return rows.reversed.toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createRoomMessage({
    required String campaignId,
    required String authorId,
    required String body,
    List<String>? visibleTo,
    String? replyTo,
  }) async {
    return await _client
        .from('room_messages')
        .insert({
          'campaign_id': campaignId,
          'author_id': authorId,
          'body': body,
          'visible_to': visibleTo,
          'reply_to': replyTo,
        })
        .select()
        .single();
  }

  /// Supprime un message.
  ///
  /// La RLS ne lève pas d'erreur quand elle refuse une suppression : elle ne
  /// supprime simplement rien. Les lignes effacées sont donc relues, pour
  /// qu'un refus remonte comme un échec plutôt que comme un faux succès.
  Future<void> deleteRoomMessage(String messageId) async {
    final deleted = await _client
        .from('room_messages')
        .delete()
        .eq('id', messageId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Message introuvable, ou suppression refusée.');
    }
  }

  // ============ SONDAGES ============

  /// Crée un sondage et son message d'un seul tenant, par la fonction
  /// `create_room_poll`. Renvoie le message, comme un envoi ordinaire.
  Future<Map<String, dynamic>> createRoomPoll({
    required String campaignId,
    required String question,
    required List<String> options,
    required bool multiple,
  }) async {
    final message = await _client.rpc('create_room_poll', params: {
      'p_campaign_id': campaignId,
      'p_question': question,
      'p_options': options,
      'p_multiple': multiple,
    });
    return Map<String, dynamic>.from(message as Map);
  }

  /// Sondages portés par les messages [messageIds], avec leurs réponses.
  ///
  /// Les compteurs viennent de la fonction `get_room_polls`, qui ne renvoie
  /// que des totaux, et seulement à qui a voté ou une fois le sondage clos.
  Future<List<Map<String, dynamic>>> getRoomPolls(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return [];
    try {
      final result = await _client.rpc(
        'get_room_polls',
        params: {'p_message_ids': messageIds},
      );
      return (result as List)
          .map((poll) => Map<String, dynamic>.from(poll as Map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Remplace le vote de l'utilisateur : voter à nouveau, c'est changer d'avis.
  Future<void> voteRoomPoll({
    required String pollId,
    required List<String> optionIds,
  }) async {
    await _client.rpc('vote_room_poll', params: {
      'p_poll_id': pollId,
      'p_option_ids': optionIds,
    });
  }

  /// Fige un sondage : réservé à son auteur et au MJ, par la base.
  Future<void> closeRoomPoll(String pollId) async {
    await _client.rpc('close_room_poll', params: {'p_poll_id': pollId});
  }

  // ============ CARTE DES RELATIONS ============

  /// Carte complète : légende, ronds, liens, et les informations que
  /// l'utilisateur a le droit de lire.
  ///
  /// Tout passe par la fonction `get_relation_graph`, qui masque en base le
  /// texte des informations non découvertes et n'en renvoie que le nombre.
  /// Une erreur n'est pas avalée ici : ne pas être membre de la room doit se
  /// voir à l'écran, et non se confondre avec une carte vide.
  Future<Map<String, dynamic>> getRelationGraph(String campaignId) async {
    final graph = await _client.rpc(
      'get_relation_graph',
      params: {'p_campaign_id': campaignId},
    );
    return Map<String, dynamic>.from(graph as Map);
  }

  Future<Map<String, dynamic>> createRelationNode({
    required String campaignId,
    required String label,
    required String kind,
    required double x,
    required double y,
  }) async {
    return await _client
        .from('room_relation_nodes')
        .insert({
          'campaign_id': campaignId,
          'label': label,
          'kind': kind,
          'x': x,
          'y': y,
        })
        .select()
        .single();
  }

  /// Seuls les champs fournis sont écrits : déplacer un rond ne renomme rien.
  Future<void> updateRelationNode({
    required String nodeId,
    String? label,
    String? kind,
    double? x,
    double? y,
  }) async {
    await _client.from('room_relation_nodes').update({
      if (label != null) 'label': label,
      if (kind != null) 'kind': kind,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    }).eq('id', nodeId);
  }

  Future<void> deleteRelationNode(String nodeId) async {
    await _client.from('room_relation_nodes').delete().eq('id', nodeId);
  }

  Future<void> createRelationLink({
    required String campaignId,
    required String fromNodeId,
    required String toNodeId,
    String? categoryId,
    String? label,
  }) async {
    await _client.from('room_relation_links').insert({
      'campaign_id': campaignId,
      'from_node_id': fromNodeId,
      'to_node_id': toNodeId,
      'category_id': categoryId,
      'label': label,
    });
  }

  /// Change la catégorie d'un lien déjà posé, ou la retire avec `null`.
  Future<void> updateRelationLink({
    required String linkId,
    String? categoryId,
  }) async {
    await _client
        .from('room_relation_links')
        .update({'category_id': categoryId}).eq('id', linkId);
  }

  Future<void> deleteRelationLink(String linkId) async {
    await _client.from('room_relation_links').delete().eq('id', linkId);
  }

  Future<Map<String, dynamic>> createRelationCategory({
    required String campaignId,
    required String name,
    required int color,
    required int position,
  }) async {
    return await _client
        .from('room_relation_categories')
        .insert({
          'campaign_id': campaignId,
          'name': name,
          'color': color,
          'position': position,
        })
        .select()
        .single();
  }

  Future<void> deleteRelationCategory(String categoryId) async {
    await _client
        .from('room_relation_categories')
        .delete()
        .eq('id', categoryId);
  }

  Future<void> createRelationFact({
    required String campaignId,
    required String nodeId,
    required String content,
    required int position,
  }) async {
    await _client.from('room_relation_facts').insert({
      'campaign_id': campaignId,
      'node_id': nodeId,
      'content': content,
      'position': position,
    });
  }

  Future<void> updateRelationFact({
    required String factId,
    required String content,
  }) async {
    await _client
        .from('room_relation_facts')
        .update({'content': content}).eq('id', factId);
  }

  Future<void> deleteRelationFact(String factId) async {
    await _client.from('room_relation_facts').delete().eq('id', factId);
  }

  /// Efface toute la carte des relations d'une room.
  ///
  /// Supprimer les ronds emporte leurs liens, leurs informations et les
  /// découvertes des joueurs, par cascade. Les catégories ne dépendent
  /// d'aucun rond : elles sont effacées à part.
  Future<void> clearRelationGraph(String campaignId) async {
    await _client
        .from('room_relation_nodes')
        .delete()
        .eq('campaign_id', campaignId);
    await _client
        .from('room_relation_categories')
        .delete()
        .eq('campaign_id', campaignId);
  }

  /// Fixe d'un seul geste qui a découvert une information.
  ///
  /// Passe par `set_fact_discoverers` plutôt que par des écritures ligne à
  /// ligne : la fonction vérifie que le MJ est bien le MJ, écarte ceux qui ne
  /// sont pas membres de la room, et touche le rond pour que la carte se
  /// rafraîchisse chez tout le monde.
  Future<void> setFactDiscoverers({
    required String factId,
    required List<String> userIds,
  }) async {
    await _client.rpc('set_fact_discoverers', params: {
      'p_fact_id': factId,
      'p_user_ids': userIds,
    });
  }

  // ============ TEMPS RÉEL ============

  /// Insertions, modifications et suppressions sur [table] pour la room
  /// [campaignId], en temps réel.
  ///
  /// Le canal ne s'ouvre qu'à la première écoute et se referme quand elle
  /// s'arrête : un écran qui disparaît ne laisse pas d'abonnement ouvert.
  ///
  /// Les insertions et les modifications sont filtrées sur la room, et la RLS s'y applique : chacun
  /// ne reçoit que les lignes qu'il a le droit de lire. Les suppressions, elles,
  /// ne peuvent pas être filtrées : l'événement ne porte que l'`id` de la ligne
  /// (voir la migration `room_messages_realtime`). Un écran reçoit donc aussi
  /// celles des autres rooms, et ignore les `id` qu'il ne connaît pas.
  Stream<RowChange> watchRoomTable(String table, String campaignId) {
    RealtimeChannel? channel;
    late final StreamController<RowChange> controller;

    void emit(RowChange change) {
      if (!controller.isClosed) controller.add(change);
    }

    controller = StreamController<RowChange>(
      onListen: () {
        // Un nom unique par abonnement : deux écrans ouverts sur la même room
        // ne se disputent pas le même canal.
        final topic =
            '$table:$campaignId:${DateTime.now().microsecondsSinceEpoch}';
        channel = _client
            .channel(topic)
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'campaign_id',
                value: campaignId,
              ),
              callback: (payload) =>
                  emit(RowChange(RowChangeKind.inserted, payload.newRecord)),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'campaign_id',
                value: campaignId,
              ),
              callback: (payload) =>
                  emit(RowChange(RowChangeKind.updated, payload.newRecord)),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: table,
              callback: (payload) =>
                  emit(RowChange(RowChangeKind.deleted, payload.oldRecord)),
            )
            .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            emit(const RowChange(RowChangeKind.resubscribed));
          }
        });
      },
      onCancel: () async {
        final open = channel;
        channel = null;
        if (open != null) await _client.removeChannel(open);
        await controller.close();
      },
    );

    return controller.stream;
  }

  // ============ JOURNAL DES JETS DE DÉS ============

  /// Enregistre un jet dans le journal de la room.
  ///
  /// Un jet marqué [isSecret] n'est lisible que par le MJ ; la policy
  /// `dice_rolls_insert_self` refuse ce drapeau à un joueur, sans quoi
  /// n'importe qui pourrait masquer un résultat qui l'arrange.
  Future<void> addDiceRoll({
    required String campaignId,
    required String userId,
    required int sides,
    required int diceCount,
    required int modifier,
    required List<int> results,
    bool isSecret = false,
  }) async {
    await _client.from('dice_rolls').insert({
      'campaign_id': campaignId,
      'user_id': userId,
      'sides': sides,
      'dice_count': diceCount,
      'modifier': modifier,
      'results': results,
      'is_secret': isSecret,
    });
  }

  /// Jets de la room, du plus récent au plus ancien, avec le nom de leur
  /// auteur.
  ///
  /// La RLS filtre déjà les jets secrets : un joueur n'en reçoit aucun.
  /// Comme pour les membres, le profil demande une seconde requête —
  /// `dice_rolls.user_id` référence `auth.users`, schéma que PostgREST
  /// n'expose pas.
  Future<List<Map<String, dynamic>>> getDiceRolls(
    String campaignId, {
    int limit = 50,
  }) async {
    try {
      final rolls = await _client
          .from('dice_rolls')
          .select()
          .eq('campaign_id', campaignId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (rolls.isEmpty) return [];

      final profiles = await _client
          .from('users')
          .select('id, username, display_name')
          .inFilter(
            'id',
            rolls.map((roll) => roll['user_id'] as String).toSet().toList(),
          );

      final profileById = {
        for (final profile in profiles) profile['id'] as String: profile,
      };

      return rolls.map((roll) {
        final profile = profileById[roll['user_id']];
        return <String, dynamic>{
          ...roll,
          'username': profile?['username'],
          'display_name': profile?['display_name'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Vide le journal d'une room. Réservé au MJ par
  /// `dice_rolls_delete_mj`.
  Future<void> clearDiceRolls(String campaignId) async {
    await _client.from('dice_rolls').delete().eq('campaign_id', campaignId);
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
      final owned =
          await _client.from('campaigns').select().eq('creator_id', userId);

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
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
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
  Future<List<Map<String, dynamic>>> getCampaignMembers(
      String campaignId) async {
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
      final response =
          await _client.from('campaigns').select().eq('id', id).maybeSingle();
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
