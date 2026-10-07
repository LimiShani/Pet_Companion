import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'composition/feature_modules.dart';
import 'platform/feature_module.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/supabase_auth_repository.dart';
import 'config/app_config.dart';
import 'services/pet_records/data/reminder_scheduler.dart';
import 'l10n/l10n.dart';
import 'notifications/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  AuthRepository? supabaseAuth;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    supabaseAuth = SupabaseAuthRepository(Supabase.instance.client);
  } else if (kDebugMode) {
    debugPrint(
      'PetLoop: no SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY given, '
      'using the in-memory auth backend (see README).',
    );
  }

  // The phone's saved choices (language, week layout), read before the
  // first frame so the app opens in the chosen language. When they cannot
  // be read the app still runs and simply does not remember them.
  final settings = await SharedPrefsSettingsStore.load();

  // The phone's notifications (none on the web). The snooze button of iOS
  // is named once, here, in the language the app opens in.
  final language = AppLanguage.fromCode(settings?.read(languageSettingKey));
  final locale = resolveAppLocale(
    language,
    WidgetsBinding.instance.platformDispatcher.locales,
    hebrewFollowsDevice: true,
  );
  final notifications = await FlutterNotificationPlatform.start(
    snoozeLabel: lookupNotificationsL10n(locale).snooze,
  );
  // Push notifications from the community: only with Firebase settings.
  final push = await FirebasePushMessaging.start(
    channelName: lookupNotificationsL10n(locale).communityChannel,
  );

  runApp(
    ProviderScope(
      overrides: [
        featureModulesProvider.overrideWithValue(defaultFeatureModules),
        if (supabaseAuth != null)
          authRepositoryProvider.overrideWithValue(supabaseAuth),
        if (settings != null) settingsStoreProvider.overrideWithValue(settings),
        if (push != null) ...[
          pushMessagingProvider.overrideWithValue(push),
          beforeSignOutProvider.overrideWith(
            (ref) => [
              () async => ref.read(pushRegistrarProvider)?.signingOut(),
            ],
          ),
        ],
        if (notifications != null) ...[
          notificationPlatformProvider.overrideWithValue(notifications),
          notificationSinkProvider.overrideWith(localNotificationSink),
          reminderSchedulerProvider.overrideWith(notificationReminderScheduler),
        ],
      ],
      child: const PetLoopApp(),
    ),
  );
}
