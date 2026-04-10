import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../auth_error_localizer.dart';

class AuthActionFeedback {
  const AuthActionFeedback.error(this.message) : isError = true;

  const AuthActionFeedback.success(this.message) : isError = false;

  final String message;
  final bool isError;
}

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  SupabaseClient get _client => ref.read(supabaseClientProvider);

  Future<AuthActionFeedback?> signUp({
    required String email,
    required String password,
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      state = const AsyncData(null);
      if (response.session == null) {
        return AuthActionFeedback.success(
          l10n.authSuccessCheckEmailForConfirmation,
        );
      }
      return null;
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(localizeAuthException(l10n, error));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(l10n.authErrorGeneric);
    }
  }

  Future<AuthActionFeedback?> signInWithPassword({
    required String email,
    required String password,
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      state = const AsyncData(null);
      return null;
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(localizeAuthException(l10n, error));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(l10n.authErrorGeneric);
    }
  }

  Future<AuthActionFeedback?> signInWithGoogle({
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      final googleSignIn = GoogleSignIn(
        clientId: SupabaseConfig.googleIosClientId.isEmpty
            ? null
            : SupabaseConfig.googleIosClientId,
        serverClientId: SupabaseConfig.googleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncData(null);
        return null;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) {
        state = const AsyncData(null);
        return AuthActionFeedback.error(l10n.authErrorGeneric);
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      state = const AsyncData(null);
      return null;
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(localizeAuthException(l10n, error));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(l10n.authErrorGeneric);
    }
  }

  Future<AuthActionFeedback> resetPasswordForEmail({
    required String email,
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      await _client.auth.resetPasswordForEmail(email);
      state = const AsyncData(null);
      return AuthActionFeedback.success(l10n.authSuccessPasswordResetSent);
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(localizeAuthException(l10n, error));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(l10n.authErrorGeneric);
    }
  }

  Future<AuthActionFeedback?> signOut({required AppLocalizations l10n}) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      await _client.auth.signOut();
      state = const AsyncData(null);
      return null;
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(localizeAuthException(l10n, error));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(l10n.authErrorGeneric);
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
