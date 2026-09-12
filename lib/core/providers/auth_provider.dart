import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/row_change.dart';

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

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) {
    return _supabaseService.updateUserProfile(
      userId: userId,
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
    );
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

  Future<void> joinCampaign(
      {required String campaignId, required String userId}) {
    return _supabaseService.joinCampaign(
        campaignId: campaignId, userId: userId);
  }

  Future<String?> getMemberRole(
      {required String campaignId, required String userId}) {
    return _supabaseService.getMemberRole(
        campaignId: campaignId, userId: userId);
  }

  Future<List<Map<String, dynamic>>> getCampaignMembers(String campaignId) {
    return _supabaseService.getCampaignMembers(campaignId);
  }

  Future<void> removeCampaignMember(
      {required String campaignId, required String userId}) {
    return _supabaseService.removeCampaignMember(
        campaignId: campaignId, userId: userId);
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

  Future<List<Map<String, dynamic>>> getRoomPosts(String campaignId) {
    return _supabaseService.getRoomPosts(campaignId);
  }

  Future<Map<String, dynamic>> createRoomPost({
    required String campaignId,
    required String authorId,
    String? body,
    XFile? image,
    List<String>? visibleTo,
  }) {
    return _supabaseService.createRoomPost(
      campaignId: campaignId,
      authorId: authorId,
      body: body,
      image: image,
      visibleTo: visibleTo,
    );
  }

  Future<void> updateRoomPostAudience({
    required String postId,
    required List<String>? visibleTo,
  }) {
    return _supabaseService.updateRoomPostAudience(
      postId: postId,
      visibleTo: visibleTo,
    );
  }

  Future<void> deleteRoomPost(Map<String, dynamic> post) {
    return _supabaseService.deleteRoomPost(post);
  }

  Future<Map<String, Map<String, int>>> getCampaignOverviews(
      List<String> campaignIds) {
    return _supabaseService.getCampaignOverviews(campaignIds);
  }

  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 6}) {
    return _supabaseService.getRecentActivity(limit: limit);
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

  Future<List<Map<String, dynamic>>> getTimelineEvents(String campaignId) {
    return _supabaseService.getTimelineEvents(campaignId);
  }

  Future<Map<String, dynamic>> createTimelineEvent({
    required String campaignId,
    required String authorId,
    required String title,
    String dateLabel = '',
    String description = '',
    int position = 0,
    List<String>? visibleTo,
  }) {
    return _supabaseService.createTimelineEvent(
      campaignId: campaignId,
      authorId: authorId,
      title: title,
      dateLabel: dateLabel,
      description: description,
      position: position,
      visibleTo: visibleTo,
    );
  }

  Future<void> updateTimelineEvent({
    required String eventId,
    required String title,
    required String dateLabel,
    required String description,
    required List<String>? visibleTo,
  }) {
    return _supabaseService.updateTimelineEvent(
      eventId: eventId,
      title: title,
      dateLabel: dateLabel,
      description: description,
      visibleTo: visibleTo,
    );
  }

  Future<void> updateTimelinePositions(Map<String, int> positionById) {
    return _supabaseService.updateTimelinePositions(positionById);
  }

  Future<void> deleteTimelineEvent(String eventId) {
    return _supabaseService.deleteTimelineEvent(eventId);
  }

  Future<List<Map<String, dynamic>>> getRoomMessages(String campaignId) {
    return _supabaseService.getRoomMessages(campaignId);
  }

  Future<Map<String, dynamic>> createRoomMessage({
    required String campaignId,
    required String authorId,
    required String body,
    List<String>? visibleTo,
    String? replyTo,
  }) {
    return _supabaseService.createRoomMessage(
      campaignId: campaignId,
      authorId: authorId,
      body: body,
      visibleTo: visibleTo,
      replyTo: replyTo,
    );
  }

  Future<void> deleteRoomMessage(String messageId) {
    return _supabaseService.deleteRoomMessage(messageId);
  }

  Future<Map<String, dynamic>> createRoomPoll({
    required String campaignId,
    required String question,
    required List<String> options,
    required bool multiple,
  }) {
    return _supabaseService.createRoomPoll(
      campaignId: campaignId,
      question: question,
      options: options,
      multiple: multiple,
    );
  }

  Future<List<Map<String, dynamic>>> getRoomPolls(List<String> messageIds) {
    return _supabaseService.getRoomPolls(messageIds);
  }

  Future<void> voteRoomPoll({
    required String pollId,
    required List<String> optionIds,
  }) {
    return _supabaseService.voteRoomPoll(pollId: pollId, optionIds: optionIds);
  }

  Future<void> closeRoomPoll(String pollId) {
    return _supabaseService.closeRoomPoll(pollId);
  }

  Future<Map<String, dynamic>> getRelationGraph(String campaignId) {
    return _supabaseService.getRelationGraph(campaignId);
  }

  Future<Map<String, dynamic>> createRelationNode({
    required String campaignId,
    required String label,
    required String kind,
    required double x,
    required double y,
    String? categoryId,
  }) {
    return _supabaseService.createRelationNode(
      campaignId: campaignId,
      label: label,
      kind: kind,
      x: x,
      y: y,
      categoryId: categoryId,
    );
  }

  Future<void> updateRelationNode({
    required String nodeId,
    String? label,
    String? kind,
    double? x,
    double? y,
  }) {
    return _supabaseService.updateRelationNode(
      nodeId: nodeId,
      label: label,
      kind: kind,
      x: x,
      y: y,
    );
  }

  Future<void> setRelationNodeCategory({
    required String nodeId,
    String? categoryId,
  }) {
    return _supabaseService.setRelationNodeCategory(
      nodeId: nodeId,
      categoryId: categoryId,
    );
  }

  Future<void> deleteRelationNode(String nodeId) {
    return _supabaseService.deleteRelationNode(nodeId);
  }

  Future<void> createRelationLink({
    required String campaignId,
    required String fromNodeId,
    required String toNodeId,
    String? categoryId,
    String? label,
  }) {
    return _supabaseService.createRelationLink(
      campaignId: campaignId,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      categoryId: categoryId,
      label: label,
    );
  }

  Future<void> updateRelationLink({
    required String linkId,
    String? categoryId,
  }) {
    return _supabaseService.updateRelationLink(
      linkId: linkId,
      categoryId: categoryId,
    );
  }

  Future<void> deleteRelationLink(String linkId) {
    return _supabaseService.deleteRelationLink(linkId);
  }

  Future<Map<String, dynamic>> createRelationCategory({
    required String campaignId,
    required String name,
    required int color,
    required int position,
  }) {
    return _supabaseService.createRelationCategory(
      campaignId: campaignId,
      name: name,
      color: color,
      position: position,
    );
  }

  Future<void> deleteRelationCategory(String categoryId) {
    return _supabaseService.deleteRelationCategory(categoryId);
  }

  Future<void> createRelationFact({
    required String campaignId,
    required String nodeId,
    required String content,
    required int position,
  }) {
    return _supabaseService.createRelationFact(
      campaignId: campaignId,
      nodeId: nodeId,
      content: content,
      position: position,
    );
  }

  Future<void> updateRelationFact({
    required String factId,
    required String content,
  }) {
    return _supabaseService.updateRelationFact(
      factId: factId,
      content: content,
    );
  }

  Future<void> deleteRelationFact(String factId) {
    return _supabaseService.deleteRelationFact(factId);
  }

  Future<void> clearRelationGraph(String campaignId) {
    return _supabaseService.clearRelationGraph(campaignId);
  }

  Future<void> setFactDiscoverers({
    required String factId,
    required List<String> userIds,
  }) {
    return _supabaseService.setFactDiscoverers(
      factId: factId,
      userIds: userIds,
    );
  }

  /// Changements en temps réel sur une table de la room : voir
  /// [SupabaseService.watchRoomTable].
  Stream<RowChange> watchRoomTable(String table, String campaignId) {
    return _supabaseService.watchRoomTable(table, campaignId);
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

  Future<List<Map<String, dynamic>>> getDiceRolls(String campaignId,
      {int limit = 50}) {
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
    return _supabaseService.uploadImage(
        file: file, bucket: bucket, fileName: fileName);
  }
}
