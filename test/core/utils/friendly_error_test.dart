import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/utils/friendly_error.dart';

void main() {
  group('friendlyErrorMessage', () {
    final cases = <String, String>{
      'invalid_credentials': 'Email ou mot de passe incorrect.',
      'email_not_confirmed':
          'Merci de confirmer votre email avant de vous connecter (vérifiez votre boîte de réception).',
      'user_already_exists': 'Un compte existe déjà avec cet email.',
      'email_exists': 'Un compte existe déjà avec cet email.',
      'weak_password': 'Mot de passe trop faible.',
      'over_email_send_rate_limit': 'Trop de tentatives. Réessayez dans quelques minutes.',
      'over_request_rate_limit': 'Trop de tentatives. Réessayez dans quelques minutes.',
      'user_not_found': 'Aucun compte ne correspond à cet email.',
      'signup_disabled': 'Les inscriptions sont désactivées pour le moment.',
      'user_banned': 'Ce compte a été suspendu.',
    };

    cases.forEach((code, expected) {
      test('traduit le code "$code"', () {
        final error = AuthException('message brut Supabase', code: code);
        expect(friendlyErrorMessage(error), expected);
      });
    });

    test('retombe sur le message Supabase pour un code non reconnu', () {
      final error = AuthException('Un message spécifique', code: 'un_code_inconnu');
      expect(friendlyErrorMessage(error), 'Un message spécifique');
    });

    test('retombe sur le message Supabase quand code est null', () {
      final error = AuthException('Erreur sans code');
      expect(friendlyErrorMessage(error), 'Erreur sans code');
    });

    test('traduit un refus de la Row Level Security', () {
      final error = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
      expect(
        friendlyErrorMessage(error),
        "Vous n'avez pas les droits nécessaires pour cette action.",
      );
    });

    test('traduit une violation de contrainte d\'unicité', () {
      final error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
      expect(friendlyErrorMessage(error), 'Cet élément existe déjà.');
    });

    test('retombe sur le message Postgrest pour un code non reconnu', () {
      final error = PostgrestException(message: 'colonne inconnue', code: '42703');
      expect(friendlyErrorMessage(error), 'colonne inconnue');
    });

    test(
      'ne prétend pas connaître la cause d\'une erreur non typée : une erreur '
      'de base de données avait été rapportée comme un problème de connexion '
      'internet (bogue B23)',
      () {
        final message = friendlyErrorMessage(Exception('cause inconnue'));

        expect(message, 'Une erreur inattendue est survenue. Réessayez.');
        expect(message, isNot(contains('connexion internet')));
      },
    );
  });
}
