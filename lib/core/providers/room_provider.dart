import 'package:flutter/foundation.dart';

import 'auth_provider.dart';

/// Rôle de l'utilisateur courant dans une room.
enum RoomRole {
  /// Maître du jeu : il crée et met à jour les contenus de la room.
  mj,

  /// Joueur : il consulte les contenus partagés par le MJ.
  player,

  /// L'utilisateur n'est pas membre de cette room.
  none,
}

/// Convertit la valeur stockée en base (`campaign_members.role`) en [RoomRole].
RoomRole roomRoleFromString(String? value) {
  switch (value) {
    case 'mj':
      return RoomRole.mj;
    case 'player':
      return RoomRole.player;
    default:
      return RoomRole.none;
  }
}

/// Contexte d'une room : la campagne chargée une seule fois, et le rôle de
/// l'utilisateur courant dedans.
///
/// Chaque écran de la room a besoin de savoir qui le regarde (le MJ voit ses
/// notes et les boutons d'édition, le joueur non). Résoudre le rôle
/// indépendamment dans chaque page multiplierait les requêtes et les risques
/// d'incohérence : [RoomShell] monte donc un seul [RoomProvider] et le
/// distribue à tout l'arbre.
///
/// Ce provider ne porte que la décision d'affichage. La règle d'accès qui fait
/// foi est la RLS Supabase (`is_campaign_member`, `is_campaign_mj`) : masquer
/// un bouton n'a jamais empêché personne d'appeler l'API.
class RoomProvider extends ChangeNotifier {
  final AuthProvider _auth;
  final String roomId;

  RoomProvider({required AuthProvider auth, required this.roomId}) : _auth = auth;

  bool _isLoading = true;
  Map<String, dynamic>? _campaign;
  RoomRole _role = RoomRole.none;

  bool get isLoading => _isLoading;

  /// Ligne `campaigns` correspondante, ou `null` si la room n'existe pas
  /// (ou plus).
  Map<String, dynamic>? get campaign => _campaign;

  RoomRole get role => _role;
  bool get isMj => _role == RoomRole.mj;
  bool get isMember => _role != RoomRole.none;
  bool get exists => _campaign != null;

  String get title => _campaign?['title'] as String? ?? 'Room';
  String get description => _campaign?['description'] as String? ?? '';
  String? get iconUrl => _campaign?['icon_url'] as String?;
  String? get joinCode => _campaign?['join_code'] as String?;

  /// Date à afficher comme « dernière mise à jour » : `updated_at` s'il existe,
  /// sinon la date de création.
  String? get lastUpdateRaw =>
      (_campaign?['updated_at'] ?? _campaign?['created_at']) as String?;

  /// Charge la campagne puis le rôle de l'utilisateur courant.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final campaign = await _auth.getCampaignById(roomId);
    final userId = _auth.currentUser?.id;

    var role = RoomRole.none;
    if (campaign != null && userId != null) {
      role = roomRoleFromString(
        await _auth.getMemberRole(campaignId: roomId, userId: userId),
      );

      // Filet de sécurité : sur une base où la migration des rôles n'a pas
      // encore été appliquée, `campaign_members` peut ne contenir aucune ligne
      // pour le créateur. Sans ce repli, le MJ serait enfermé hors de sa
      // propre room.
      if (role == RoomRole.none && campaign['creator_id'] == userId) {
        role = RoomRole.mj;
      }
    }

    _campaign = campaign;
    _role = role;
    _isLoading = false;
    notifyListeners();
  }

  /// Recharge la campagne et le rôle, par exemple après un renommage ou
  /// l'arrivée d'un joueur.
  Future<void> refresh() => load();
}
