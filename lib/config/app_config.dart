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

  /// The currency amounts are entered and shown in unless a record carries
  /// its own code (ISO 4217). One place to change it for the whole app.
  static const defaultCurrency = 'ILS';
}
