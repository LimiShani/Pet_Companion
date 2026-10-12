import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../notifications/notifications.dart';
import '../../notifications/widgets/notification_settings_card.dart';
import '../../widgets/petloop_icon.dart';
import 'settings_routes.dart';
import 'widgets/menu_card.dart';
import 'widgets/menu_entry.dart';
import 'widgets/settings_page.dart';
import 'widgets/week_choice.dart';

/// The Settings page: three rows, the app's language, the week layout and
/// the notifications, each with the current choice under its name. Each
/// row opens a short page with its controls (`LanguageSettingsScreen`,
/// `WeekSettingsScreen`, `NotificationSettingsScreen`); every choice
/// applies at once and is remembered on the phone (see `SettingsStore`).
/// The legal pages and the credits are on the About page (`AboutScreen`).
///
/// Opened from the You page with `openSettings`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const screenKey = Key('settings-screen');
  static const languageKey = Key('settings-language');
  static const weekKey = Key('settings-week');
  static const notificationsKey = Key('settings-notifications');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifications = context.notificationsL10n;

    return SettingsPage(
      key: screenKey,
      title: l10n.settingsTitle,
      children: [
        // A choice can take two lines under its name on a small phone.
        MenuCard(
          children: [
            MenuEntry(
              key: languageKey,
              subtitleMaxLines: 2,
              icon: const Icon(Icons.translate_rounded),
              title: l10n.accountLanguage,
              subtitle: _languageSummary(l10n, ref),
              onTap: () => openLanguageSettings(context),
            ),
            MenuEntry(
              key: weekKey,
              subtitleMaxLines: 2,
              icon: const PetLoopIcon(PetLoopGlyph.calendar),
              title: l10n.settingsWeek,
              subtitle: WeekChoice.summaryOf(
                context,
                ref.watch(weekSettingsProvider),
              ),
              onTap: () => openWeekSettings(context),
            ),
            MenuEntry(
              key: notificationsKey,
              subtitleMaxLines: 2,
              icon: const PetLoopIcon(PetLoopGlyph.reminder),
              title: notifications.sectionTitle,
              subtitle: NotificationSettingsCard.summaryOf(
                notifications,
                ref.watch(notificationSettingsProvider),
                ref.watch(notificationAccessProvider).value,
              ),
              onTap: () => openNotificationSettings(context),
            ),
          ],
        ),
        SettingsNote(l10n.settingsSavedNote),
      ],
    );
  }

  /// "Follow the phone · English" while the app follows the phone, else
  /// the chosen language in its own letters.
  static String _languageSummary(AppL10n l10n, WidgetRef ref) {
    final chosen = ref.watch(appLanguageProvider);
    if (chosen == AppLanguage.system &&
        ref.watch(hebrewFollowsDeviceProvider)) {
      final phone = resolveAppLocale(
        AppLanguage.system,
        ref.watch(deviceLocalesProvider),
        hebrewFollowsDevice: true,
      );
      return l10n.settingsLanguageFollowing(nativeLanguageName(phone));
    }
    return nativeLanguageName(ref.watch(appLocaleProvider));
  }
}
