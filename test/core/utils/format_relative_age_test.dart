import 'package:flutter_test/flutter_test.dart';

import 'package:scriptoria/core/utils/format_relative_age.dart';

void main() {
  final maintenant = DateTime.parse('2026-09-10T12:00:00Z');

  String ageDepuis(String iso) => formatRelativeAge(iso, now: maintenant);

  test('les toutes dernières secondes sont « à l\'instant »', () {
    expect(ageDepuis('2026-09-10T11:59:40Z'), "à l'instant");
  });

  test('compte en minutes puis en heures', () {
    expect(ageDepuis('2026-09-10T11:45:00Z'), 'il y a 15 min');
    expect(ageDepuis('2026-09-10T09:00:00Z'), 'il y a 3 h');
  });

  test('nomme la veille plutôt que de compter les jours', () {
    expect(ageDepuis('2026-09-09T11:00:00Z'), 'hier');
  });

  test('compte en jours, puis en mois, puis en années', () {
    expect(ageDepuis('2026-09-01T12:00:00Z'), 'il y a 9 j');
    expect(ageDepuis('2026-06-10T12:00:00Z'), 'il y a 3 mois');
    expect(ageDepuis('2024-09-10T12:00:00Z'), 'il y a 2 ans');
    expect(ageDepuis('2025-09-10T12:00:00Z'), 'il y a 1 an');
  });

  test(
    'une date future ne produit pas « dans 3 minutes » : elle vient d\'une '
    'horloge décalée entre l\'appareil et le serveur',
    () {
      expect(ageDepuis('2026-09-10T12:05:00Z'), "à l'instant");
    },
  );

  test('signale une date absente ou illisible au lieu de la masquer', () {
    expect(formatRelativeAge(null), 'date inconnue');
    expect(formatRelativeAge('pas une date'), 'date inconnue');
  });
}
