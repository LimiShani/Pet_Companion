import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/supabase_auth_repository.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthRepository? supabaseAuth;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
    supabaseAuth = SupabaseAuthRepository(Supabase.instance.client);
  } else if (kDebugMode) {
    debugPrint('Pet Companion: no SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY given, '
        'using the in-memory auth backend (see README).');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (supabaseAuth != null) authRepositoryProvider.overrideWithValue(supabaseAuth),
      ],
      child: const PetCompanionApp(),
    ),
  );
}
