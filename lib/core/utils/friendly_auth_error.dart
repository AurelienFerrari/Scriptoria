import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduit une erreur Supabase Auth en message compréhensible pour l'utilisateur,
/// au lieu d'afficher le code/statusCode brut de l'API (ex: "invalid_credentials").
String friendlyAuthErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Email ou mot de passe incorrect.';
      case 'email_not_confirmed':
        return 'Merci de confirmer votre email avant de vous connecter (vérifiez votre boîte de réception).';
      case 'user_already_exists':
      case 'email_exists':
        return 'Un compte existe déjà avec cet email.';
      case 'weak_password':
        return 'Mot de passe trop faible.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'user_not_found':
        return 'Aucun compte ne correspond à cet email.';
      case 'signup_disabled':
        return 'Les inscriptions sont désactivées pour le moment.';
      case 'user_banned':
        return 'Ce compte a été suspendu.';
    }
    // Code non reconnu : le message Supabase reste plus lisible qu'un toString() brut.
    return error.message;
  }

  return 'Une erreur est survenue. Vérifiez votre connexion internet et réessayez.';
}
