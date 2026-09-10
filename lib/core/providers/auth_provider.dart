import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Expose l'état d'authentification à toute l'app et notifie les widgets qui
/// l'écoutent (via Provider) à chaque connexion/déconnexion, au lieu que
/// chaque écran interroge SupabaseService directement de son côté.
class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;

  AuthProvider({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService();

  User? get currentUser => _supabaseService.getCurrentUser();
  bool get isLoggedIn => currentUser != null;
  Stream<AuthState> get onAuthStateChange => _supabaseService.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabaseService.signIn(
      email: email,
      password: password,
    );
    notifyListeners();
    return response;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final response = await _supabaseService.signUp(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );
    notifyListeners();
    return response;
  }

  Future<void> signOut() async {
    await _supabaseService.signOut();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) {
    return _supabaseService.getUserProfile(userId);
  }

  Future<void> resetPassword(String email) {
    return _supabaseService.resetPassword(email);
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _supabaseService.updatePassword(newPassword);
  }

  Future<Map<String, dynamic>> createCampaign({
    required String creatorId,
    required String title,
    required String description,
    String? iconUrl,
    required int maxPlayers,
    required String joinCode,
  }) {
    return _supabaseService.createCampaign(
      creatorId: creatorId,
      title: title,
      description: description,
      iconUrl: iconUrl,
      maxPlayers: maxPlayers,
      joinCode: joinCode,
    );
  }

  Future<Map<String, dynamic>?> getCampaignByJoinCode(String joinCode) {
    return _supabaseService.getCampaignByJoinCode(joinCode);
  }

  Future<Map<String, dynamic>?> getCampaignById(String id) {
    return _supabaseService.getCampaignById(id);
  }

  Future<void> deleteCampaign(String campaignId) {
    return _supabaseService.deleteCampaign(campaignId);
  }

  Future<List<Map<String, dynamic>>> getVisibleCampaigns(String userId) {
    return _supabaseService.getVisibleCampaigns(userId);
  }

  Future<void> joinCampaign({required String campaignId, required String userId}) {
    return _supabaseService.joinCampaign(campaignId: campaignId, userId: userId);
  }

  Future<String?> getMemberRole({required String campaignId, required String userId}) {
    return _supabaseService.getMemberRole(campaignId: campaignId, userId: userId);
  }

  Future<List<Map<String, dynamic>>> getCampaignMembers(String campaignId) {
    return _supabaseService.getCampaignMembers(campaignId);
  }

  Future<void> removeCampaignMember({required String campaignId, required String userId}) {
    return _supabaseService.removeCampaignMember(campaignId: campaignId, userId: userId);
  }

  Future<Map<String, dynamic>?> updateCampaign({
    required String campaignId,
    String? title,
    String? description,
  }) {
    return _supabaseService.updateCampaign(
      campaignId: campaignId,
      title: title,
      description: description,
    );
  }

  Future<Map<String, dynamic>> addCampaignImage({
    required XFile file,
    required String campaignId,
    required String ownerId,
    List<String>? visibleTo = const [],
  }) {
    return _supabaseService.addCampaignImage(
      file: file,
      campaignId: campaignId,
      ownerId: ownerId,
      visibleTo: visibleTo,
    );
  }

  Future<List<Map<String, dynamic>>> getRoomNotes(String campaignId) {
    return _supabaseService.getRoomNotes(campaignId);
  }

  Future<Map<String, dynamic>> createRoomNote({
    required String campaignId,
    required String authorId,
    required String title,
    String contentMd = '',
  }) {
    return _supabaseService.createRoomNote(
      campaignId: campaignId,
      authorId: authorId,
      title: title,
      contentMd: contentMd,
    );
  }

  Future<void> updateRoomNote({
    required String noteId,
    String? title,
    String? contentMd,
  }) {
    return _supabaseService.updateRoomNote(
      noteId: noteId,
      title: title,
      contentMd: contentMd,
    );
  }

  Future<void> deleteRoomNote(String noteId) {
    return _supabaseService.deleteRoomNote(noteId);
  }

  Future<void> addDiceRoll({
    required String campaignId,
    required String userId,
    required int sides,
    required int diceCount,
    required int modifier,
    required List<int> results,
    bool isSecret = false,
  }) {
    return _supabaseService.addDiceRoll(
      campaignId: campaignId,
      userId: userId,
      sides: sides,
      diceCount: diceCount,
      modifier: modifier,
      results: results,
      isSecret: isSecret,
    );
  }

  Future<List<Map<String, dynamic>>> getDiceRolls(String campaignId, {int limit = 50}) {
    return _supabaseService.getDiceRolls(campaignId, limit: limit);
  }

  Future<void> clearDiceRolls(String campaignId) {
    return _supabaseService.clearDiceRolls(campaignId);
  }

  Future<void> updateImageVisibility({
    required String imageId,
    required List<String>? visibleTo,
  }) {
    return _supabaseService.updateImageVisibility(
      imageId: imageId,
      visibleTo: visibleTo,
    );
  }

  Future<List<Map<String, dynamic>>> getCampaignImages(String campaignId) {
    return _supabaseService.getCampaignImages(campaignId);
  }

  Future<void> removeCampaignImage({
    required String imageId,
    required String bucket,
    required String path,
  }) {
    return _supabaseService.removeCampaignImage(
      imageId: imageId,
      bucket: bucket,
      path: path,
    );
  }

  Future<String?> uploadImage({
    required XFile file,
    required String bucket,
    required String fileName,
  }) {
    return _supabaseService.uploadImage(file: file, bucket: bucket, fileName: fileName);
  }
}
