import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:scriptoria/core/utils/friendly_auth_error.dart';

void main() {
  group('friendlyAuthErrorMessage', () {
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
        expect(friendlyAuthErrorMessage(error), expected);
      });
    });

    test('retombe sur le message Supabase pour un code non reconnu', () {
      final error = AuthException('Un message spécifique', code: 'un_code_inconnu');
      expect(friendlyAuthErrorMessage(error), 'Un message spécifique');
    });

    test('retombe sur le message Supabase quand code est null', () {
      final error = AuthException('Erreur sans code');
      expect(friendlyAuthErrorMessage(error), 'Erreur sans code');
    });

    test('retourne un message générique pour une exception non-AuthException', () {
      expect(
        friendlyAuthErrorMessage(Exception('erreur réseau quelconque')),
        'Une erreur est survenue. Vérifiez votre connexion internet et réessayez.',
      );
    });
  });
}
