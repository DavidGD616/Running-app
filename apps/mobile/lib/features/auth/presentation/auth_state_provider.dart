import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return Stream.value(null);
  }

  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((authState) {
    return authState.session?.user;
  });
});

final passwordRecoveryProvider = StreamProvider<bool>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return Stream.value(false);
  }

  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((authState) {
    return authState.event == AuthChangeEvent.passwordRecovery;
  });
});

final currentUserProvider = Provider<User?>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return null;
  }

  final client = ref.watch(supabaseClientProvider);
  final authState = ref.watch(authStateProvider);
  return authState.asData?.value ?? client.auth.currentUser;
});
