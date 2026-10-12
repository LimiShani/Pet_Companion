import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../notifications/push.dart';
import '../../notifications/widgets/notification_settings_card.dart';
import '../../platform/feature_ui.dart';
import '../../widgets/language_choice.dart';
import 'widgets/settings_page.dart';
import 'widgets/week_choice.dart';

/// Settings > Language: the language list and its note.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const screenKey = Key('settings-language-screen');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsPage(
      key: screenKey,
      title: l10n.accountLanguage,
      children: [const LanguageChoice(), SettingsNote(l10n.languageNote)],
    );
  }
}

/// Settings > Week: the first day, the weekdays, the seven day letters,
/// and a note on what follows the week.
class WeekSettingsScreen extends StatelessWidget {
  const WeekSettingsScreen({super.key});

  static const screenKey = Key('settings-week-screen');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsPage(
      key: screenKey,
      title: l10n.settingsWeek,
      children: [const WeekChoice(), SettingsNote(l10n.settingsWeekNote)],
    );
  }
}

/// Settings > Notifications: what rings on this phone, then the
/// community's push choices when push is available.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const screenKey = Key('settings-notifications-screen');

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      key: screenKey,
      title: context.notificationsL10n.sectionTitle,
      children: [
        const NotificationSettingsCard(),
        // The community's push choices, when push is available.
        Consumer(
          builder: (context, ref, _) =>
              ref.watch(pushMessagingProvider) == null
              ? const SizedBox.shrink()
              : featureSlot('community-push-settings', ''),
        ),
      ],
    );
  }
}
