/// Configuration Supabase
/// 
/// À remplir avec vos vraies clés depuis https://app.supabase.com
/// 
/// Étapes:
/// 1. Créer un projet sur supabase.com
/// 2. Aller dans Settings > API
/// 3. Copier l'URL du projet et la clé anon publique
/// 4. Remplacer les valeurs ci-dessous

class SupabaseConfig {
  /// URL de votre projet Supabase
  /// Format: https://YOUR_PROJECT_ID.supabase.co
  static const String projectUrl = 'https://YOUR_PROJECT_ID.supabase.co';

  /// Clé anonyme publique
  /// Trouvable dans Settings > API > Project API keys > anon public
  static const String anonKey = 'YOUR_ANON_KEY';

  /// Buckets de stockage
  static const String avatarsBucket = 'avatars';
  static const String imagesBucket = 'images';
  static const String mapsBucket = 'maps';
}
