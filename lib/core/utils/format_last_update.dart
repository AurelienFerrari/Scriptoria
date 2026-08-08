/// Formate une date ISO 8601 en `dd/mm/yyyy à hh:mm`, ou "Inconnue" si absente/invalide.
String formatLastUpdate(String? iso) {
  if (iso == null) return 'Inconnue';
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return 'Inconnue';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} à ${two(date.hour)}:${two(date.minute)}';
}
