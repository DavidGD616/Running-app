abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasUrl => url.isNotEmpty;
  static bool get hasAnonKey => anonKey.isNotEmpty;
  static bool get isConfigured => hasUrl && hasAnonKey;
}
