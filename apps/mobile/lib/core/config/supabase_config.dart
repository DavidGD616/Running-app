abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get hasUrl => url.isNotEmpty;
  static bool get hasAnonKey => anonKey.isNotEmpty;
  static bool get isConfigured => hasUrl && hasAnonKey;
}
