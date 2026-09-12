import 'package:mocktail/mocktail.dart';

import 'package:scriptoria/core/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

/// Neutralise les requêtes que `HomePage` déclenche à son montage.
///
/// L'accueil charge les campagnes, leurs compteurs et l'activité récente.
/// Beaucoup de tests y atterrissent sans que l'accueil soit leur sujet — après
/// une suppression de room, une réinitialisation de mot de passe, une
/// résolution de route — et échoueraient sur un appel non simulé.
///
/// À appeler en début de `setUp` : un test qui veut des campagnes précises
/// redéclare simplement `getVisibleCampaigns` ensuite.
void stubHomeScreen(MockSupabaseService service) {
  when(() => service.getVisibleCampaigns(any())).thenAnswer((_) async => []);
  when(() => service.getCampaignOverviews(any())).thenAnswer((_) async => {});
  when(() => service.getRecentActivity(limit: any(named: 'limit')))
      .thenAnswer((_) async => []);
}

/// Neutralise les requêtes que les écrans d'une room déclenchent à leur
/// montage : fil, galerie, membres, notes, frise, journal des jets, chat, et
/// leurs abonnements en temps réel.
///
/// Même logique que [stubHomeScreen] : un test qui traverse une room sans
/// qu'elle soit son sujet — création, adhésion, navigation entre onglets —
/// échouerait sur le premier appel non simulé. Un test qui s'intéresse à l'un
/// de ces contenus redéclare simplement la méthode concernée ensuite.
void stubRoomScreens(MockSupabaseService service) {
  when(() => service.getRoomPosts(any())).thenAnswer((_) async => []);
  when(() => service.getCampaignImages(any())).thenAnswer((_) async => []);
  when(() => service.getCampaignMembers(any())).thenAnswer((_) async => []);
  when(() => service.getRoomNotes(any())).thenAnswer((_) async => []);
  when(() => service.getTimelineEvents(any())).thenAnswer((_) async => []);
  when(() => service.getRoomMessages(any())).thenAnswer((_) async => []);
  when(() => service.getRoomPolls(any())).thenAnswer((_) async => []);
  // Carte des relations : vide, et vue par un joueur.
  when(() => service.getRelationGraph(any())).thenAnswer(
    (_) async => {
      'is_mj': false,
      'categories': <Map<String, dynamic>>[],
      'nodes': <Map<String, dynamic>>[],
      'links': <Map<String, dynamic>>[],
    },
  );
  // Aucun changement en temps réel : un test qui en veut fournit son propre
  // flux, qu'il pilote.
  when(() => service.watchRoomTable(any(), any()))
      .thenAnswer((_) => const Stream.empty());
  when(() => service.getDiceRolls(any(), limit: any(named: 'limit')))
      .thenAnswer((_) async => []);
}
