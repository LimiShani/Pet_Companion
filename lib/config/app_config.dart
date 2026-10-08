import 'package:flutter/foundation.dart';

/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file=env.json` (see README). Nothing here is secret:
/// the Supabase publishable key is meant to ship in the client, and row
/// level security on the database is what protects the data.
abstract final class AppConfig {
  static const explicitDemo = bool.fromEnvironment('PETLOOP_DEMO');
  static const isDemo = !hasSupabase && (kDebugMode || explicitDemo);
  static void validate() {
    if (!hasSupabase && !isDemo) {
      throw StateError(
        'Release builds require Supabase settings or explicit PETLOOP_DEMO=true.',
      );
    }
    if ((supabaseUrl.isEmpty != supabasePublishableKey.isEmpty)) {
      throw StateError('Both Supabase settings are required.');
    }
  }

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable key (`sb_publishable_...`). A legacy anon
  /// key (a long JWT) works here too.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// True when both Supabase values were provided at build time.
  static const hasSupabase = supabaseUrl != '' && supabasePublishableKey != '';

  /// Firebase Cloud Messaging for push notifications (from the Firebase
  /// console's Android app: `google-services.json`'s current_key,
  /// mobilesdk_app_id, project_id and project_number). Push stays off
  /// without them. None of these is secret.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');

  static const hasFirebase =
      hasSupabase &&
      firebaseApiKey != '' &&
      firebaseAppId != '' &&
      firebaseProjectId != '' &&
      firebaseSenderId != '';

  /// The currency amounts are entered and shown in unless a record carries
  /// its own code (ISO 4217). One place to change it for the whole app.
  static const defaultCurrency = 'ILS';

  /// Where the Terms of Use and the Privacy Policy are published: GitHub
  /// Pages serving `docs/legal` (see docs/legal_pages.md). Another host
  /// is given at build time with `PETLOOP_LEGAL_URL` (no trailing slash).
  static const legalBaseUrl = String.fromEnvironment(
    'PETLOOP_LEGAL_URL',
    defaultValue: 'https://limishani.github.io/Pet_Companion/legal',
  );

  /// The Terms of Use in [languageCode] (`he` has its own page; every
  /// other language gets the English one).
  static Uri termsUrl(String languageCode) => _legalPage('terms', languageCode);

  /// The Privacy Policy in [languageCode].
  static Uri privacyUrl(String languageCode) =>
      _legalPage('privacy', languageCode);

  static Uri _legalPage(String page, String languageCode) => Uri.parse(
    '$legalBaseUrl/$page${languageCode == 'he' ? '.he' : ''}.html',
  );
}
