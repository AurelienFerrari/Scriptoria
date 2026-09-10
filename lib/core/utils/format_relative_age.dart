/// Ancienneté en clair : « il y a 2 min », « hier », « il y a 3 j ».
///
/// Préférée à une date complète partout où l'on situe un événement récent :
/// à une table de jeu, « il y a 2 min » se lit d'un coup d'œil là où
/// « 10/09/2026 à 14:32 » demande un calcul.
///
/// Renvoie « date inconnue » plutôt que de masquer une valeur absente : une
/// ligne sans repère temporel doit se voir.
String formatRelativeAge(String? iso, {DateTime? now}) {
  if (iso == null) return 'date inconnue';

  final moment = DateTime.tryParse(iso)?.toLocal();
  if (moment == null) return 'date inconnue';

  final elapsed = (now ?? DateTime.now()).difference(moment);

  // Une date future vient d'une horloge décalée entre l'appareil et le
  // serveur. « dans 3 minutes » sur un événement passé serait déroutant.
  if (elapsed.isNegative) return "à l'instant";

  if (elapsed.inMinutes < 1) return "à l'instant";
  if (elapsed.inMinutes < 60) return 'il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
  if (elapsed.inDays == 1) return 'hier';
  if (elapsed.inDays < 30) return 'il y a ${elapsed.inDays} j';
  if (elapsed.inDays < 365) return 'il y a ${elapsed.inDays ~/ 30} mois';
  return 'il y a ${elapsed.inDays ~/ 365} an${elapsed.inDays ~/ 365 > 1 ? 's' : ''}';
}
