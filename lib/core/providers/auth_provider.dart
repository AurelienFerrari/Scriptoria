import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Expose l'état d'authentification à toute l'app et notifie les widgets qui
/// l'écoutent (via Provider) à chaque connexion/déconnexion, au lieu que
/// chaque écran interroge SupabaseService directement de son côté.
class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;

  AuthProvider({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService();

  User? get currentUser => _supabaseService.getCurrentUser();
  bool get isLoggedIn => currentUser != null;

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
}
