import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/data/runner_profile_repository.dart';
import '../auth_error_localizer.dart';

const _authRedirectUrl = 'striviq://login-callback';

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
        emailRedirectTo: _authRedirectUrl,
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

  Future<AuthActionFeedback?> signInWithApple({
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      final rawNonce = _client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        state = const AsyncData(null);
        return AuthActionFeedback.error(l10n.authErrorGeneric);
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Apple only sends name on first sign-in — save it if available
      final givenName = credential.givenName;
      final familyName = credential.familyName;
      if (givenName != null || familyName != null) {
        final fullName = [givenName, familyName]
            .where((p) => p != null && p.isNotEmpty)
            .join(' ');
        await _client.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }
      // Best-effort: store Apple authorization code for future account deletion
      try {
        await _client.functions.invoke('store-apple-token', body: {
          'authorizationCode': credential.authorizationCode,
        });
      } catch (e) {
        // Log but don't block login
        // ignore: avoid_print
        print('[AppleSignIn] Failed to store Apple token: $e');
      }
      state = const AsyncData(null);
      return null;
    } on SignInWithAppleAuthorizationException catch (e, stackTrace) {
      state = const AsyncData(null);
      if (e.code == AuthorizationErrorCode.canceled) return null;
      state = AsyncError(e, stackTrace);
      return AuthActionFeedback.error(l10n.authErrorGeneric);
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
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _authRedirectUrl,
      );
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

  Future<AuthActionFeedback?> updatePassword({
    required String newPassword,
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }
    state = const AsyncLoading();
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
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

  Future<AuthActionFeedback?> signOut({required AppLocalizations l10n}) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      await _client.auth.signOut();
      final prefs = ref.read(sharedPreferencesProvider);
      await SharedPreferencesRunnerProfileRepository(prefs).clearProfile();
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

  Future<AuthActionFeedback> deleteAccount({
    required AppLocalizations l10n,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return AuthActionFeedback.error(l10n.authErrorNotConfigured);
    }

    state = const AsyncLoading();
    try {
      // 1. Delete user on server (this is the critical operation)
      final res = await _client.functions.invoke('delete-account');
      if (res.status != 200) {
        // Never surface the raw server error string to the user — it is not
        // localized. Use the localized failure message instead.
        state = const AsyncData(null);
        return AuthActionFeedback.error(l10n.settingsAccountDeleteError);
      }

      // 2. Clear local state — best effort, never block sign-out
      try {
        await _clearAllLocalState();
      } catch (e) {
        // Log but don't block — prefs will be cleared on next launch
        // ignore: avoid_print
        print('[deleteAccount] Local state clear failed: $e');
      }

      // 3. Always sign out to reset auth state — non-critical after deletion
      try {
        await _client.auth.signOut();
      } catch (e) {
        // Account already deleted — signOut failure is non-critical
        // ignore: avoid_print
        print('[deleteAccount] signOut failed after deletion: $e');
      }
      state = const AsyncData(null);
      return AuthActionFeedback.success(l10n.settingsAccountDeleteSuccess);
    } on FunctionException {
      // Edge function returned non-2xx (invoke throws). Never surface the raw
      // server error — show the localized failure message and keep state clean.
      state = const AsyncData(null);
      return AuthActionFeedback.error(l10n.settingsAccountDeleteError);
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(localizeAuthException(l10n, error));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AuthActionFeedback.error(l10n.settingsAccountDeleteError);
    }
  }

  Future<void> _clearAllLocalState() async {
    final prefs = ref.read(sharedPreferencesProvider);

    // Preserve locale so the app stays in the user's chosen language
    final locale = prefs.getString('pref_locale');

    await prefs.clear();

    if (locale != null) {
      await prefs.setString('pref_locale', locale);
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
