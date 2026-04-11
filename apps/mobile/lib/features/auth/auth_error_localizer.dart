import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

String localizeAuthException(AppLocalizations l10n, AuthException exception) {
  final code = exception.code?.toLowerCase();
  final message = exception.message.toLowerCase();

  if (code == 'invalid_credentials' || message.contains('invalid login')) {
    return l10n.authErrorInvalidCredentials;
  }

  if (code == 'email_exists' ||
      code == 'user_already_exists' ||
      message.contains('already registered') ||
      message.contains('already been registered') ||
      message.contains('user already registered')) {
    return l10n.authErrorEmailAlreadyRegistered;
  }

  if (code == 'weak_password' ||
      message.contains('password should be at least') ||
      message.contains('password is too weak')) {
    return l10n.authErrorWeakPassword;
  }

  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return l10n.authErrorEmailNotConfirmed;
  }

  if (code == 'validation_failed' ||
      code == 'invalid_email' ||
      message.contains('invalid email')) {
    return l10n.authErrorInvalidEmail;
  }

  if (code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      code == 'rate_limit_exceeded' ||
      message.contains('rate limit')) {
    return l10n.authErrorTooManyRequests;
  }

  if (code == 'network_request_failed' ||
      message.contains('failed host lookup') ||
      message.contains('network')) {
    return l10n.authErrorNetwork;
  }

  return l10n.authErrorGeneric;
}
