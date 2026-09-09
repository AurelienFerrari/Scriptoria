import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduit une erreur Supabase en message compréhensible, au lieu d'afficher
/// le code brut de l'API (ex : `invalid_credentials`).
///
/// Chaque famille d'erreur a sa branche. Le point important est la branche par
/// défaut : elle ne doit **jamais** affirmer une cause qu'on n'a pas
/// constatée. Une version précédente répondait « Vérifiez votre connexion
/// internet » à toute erreur non authentifiée — y compris une erreur de base
/// de données — ce qui a envoyé un diagnostic dans le mur (bogue B23).
String friendlyErrorMessage(Object error) {
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
    // Code non reconnu : le message Supabase reste plus lisible qu'un
    // toString() brut.
    return error.message;
  }

  if (error is PostgrestException) {
    switch (error.code) {
      // Refus de la Row Level Security.
      case '42501':
        return "Vous n'avez pas les droits nécessaires pour cette action.";
      // Violation de contrainte d'unicité.
      case '23505':
        return 'Cet élément existe déjà.';
      // Violation de clé étrangère.
      case '23503':
        return "L'élément lié n'existe plus.";
    }
    return error.message;
  }

  if (error is StorageException) {
    return error.message;
  }

  // Cause inconnue : on le dit, plutôt que d'inventer une explication. Le
  // détail part dans les logs (et donc dans Crashlytics via la console) pour
  // rester diagnosticable.
  debugPrint('Erreur non typée remontée à l\'utilisateur : ${error.runtimeType} — $error');
  return 'Une erreur inattendue est survenue. Réessayez.';
}
