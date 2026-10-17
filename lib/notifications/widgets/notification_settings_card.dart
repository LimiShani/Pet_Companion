import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../notifications.dart';

/// The card of the Settings > Notifications page: the master switch, one
/// switch per kind of reminder, quiet hours, and what the phone allows
/// (notifications at all, and Android's "Alarms & reminders" for exact
/// times). Every switch applies at once and is remembered on the phone.
class NotificationSettingsCard extends ConsumerWidget {
  const NotificationSettingsCard({super.key});

  static const masterKey = Key('notifications-master');
  static const quietHoursKey = Key('notifications-quiet-hours');
  static const blockedKey = Key('notifications-blocked');
  static const openSettingsKey = Key('notifications-open-settings');
  static const exactKey = Key('notifications-exact');
  static const exactAllowKey = Key('notifications-exact-allow');
  static const weeklyDayKey = Key('notifications-weekly-day');
  static const weeklyTimeKey = Key('notifications-weekly-time');

  static Key kindKey(NotificationKind kind) =>
      ValueKey('notifications-${kind.name}');

  /// One line on what rings, for the Notifications row of the Settings
  /// page: "Reminders on · quiet hours off", "Reminders off", or "Off on
  /// this phone" when the phone blocks PetLoop's notifications.
  static String summaryOf(
    NotificationsL10n l10n,
    NotificationSettings settings,
    NotificationAccess? access,
  ) {
    if (access != null && !access.allowed) return l10n.summaryBlocked;
    if (!settings.enabled) return l10n.summaryOff;
    return settings.quietHours ? l10n.summaryQuietOn : l10n.summaryQuietOff;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.notificationsL10n;
    final settings = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final access = ref.watch(notificationAccessProvider).value;
    final on = settings.enabled;

    final kinds = [
      (NotificationKind.meal, l10n.meals, null),
      (NotificationKind.walk, l10n.walks, null),
      (NotificationKind.medicine, l10n.medicines, null),
      (NotificationKind.appointment, l10n.appointments, l10n.appointmentsNote),
      (NotificationKind.basket, l10n.basket, l10n.basketNote),
      (NotificationKind.weekly, l10n.weekly, l10n.weeklyNote),
    ];
    final week = ref.watch(weekSettingsProvider);
    final weeklyDay = settings.weeklyDayOr(week.firstDay);
    final weeklyTime = TimeOfDay(
      hour: settings.weeklyMinutes ~/ 60,
      minute: settings.weeklyMinutes % 60,
    );
    final weeklyOn = on && settings.weekly;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (access != null && !access.allowed) ...[
              _Blocked(
                onOpen: () => ref
                    .read(notificationAccessProvider.notifier)
                    .openSettings(),
              ),
              const Divider(height: 17, indent: 16, endIndent: 16),
            ],
            _Switch(
              tileKey: masterKey,
              title: l10n.masterTitle,
              subtitle: [l10n.masterNote, l10n.masterDoneNote],
              value: on,
              onChanged: controller.setEnabled,
              strong: true,
            ),
            const Divider(height: 9, indent: 16, endIndent: 16),
            for (final (kind, title, note) in kinds)
              _Switch(
                tileKey: kindKey(kind),
                title: title,
                subtitle: [?note],
                value: settings.kindOn(kind),
                onChanged: on
                    ? (value) => controller.setKind(kind, value)
                    : null,
              ),
            if (weeklyOn) ...[
              _Choice(
                tileKey: weeklyDayKey,
                title: l10n.weeklyDay,
                value: _weekdayName(context, weeklyDay),
                onTap: () async {
                  final day = await _pickWeekday(
                    context,
                    selected: weeklyDay,
                    firstDay: week.firstDay,
                  );
                  if (day != null) await controller.setWeeklyTime(day: day);
                },
              ),
              _Choice(
                tileKey: weeklyTimeKey,
                title: l10n.weeklyTime,
                value: AppFormat.of(context).timeOfDay(weeklyTime),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: weeklyTime,
                    helpText: l10n.weekly,
                  );
                  if (time != null) {
                    await controller.setWeeklyTime(
                      minutes: time.hour * 60 + time.minute,
                    );
                  }
                },
              ),
            ],
            const Divider(height: 9, indent: 16, endIndent: 16),
            _Switch(
              tileKey: quietHoursKey,
              title: l10n.quietHours,
              subtitle: [l10n.quietHoursMoved, l10n.quietHoursNote],
              value: settings.quietHours,
              onChanged: on ? controller.setQuietHours : null,
            ),
            if (access?.exact != null) ...[
              const Divider(height: 9, indent: 16, endIndent: 16),
              _Exact(
                key: exactKey,
                allowed: access!.exact!,
                onAllow: () =>
                    ref.read(notificationAccessProvider.notifier).allowExact(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

TextStyle get _noteStyle =>
    AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600);

/// The full name of an ISO weekday in the screen's language: "Sunday" /
/// "יום ראשון".
String _weekdayName(BuildContext context, int weekday) {
  final locale = AppFormat.of(context).localeName;
  String? known;
  try {
    known = DateFormat.localeExists(locale) ? locale : null;
  } catch (_) {
    known = null;
  }
  // 1 January 2024 was a Monday.
  return DateFormat.EEEE(known).format(DateTime(2024, 1, weekday));
}

/// Asks for the weekday of the weekly summary, in the order of the week.
Future<int?> _pickWeekday(
  BuildContext context, {
  required int selected,
  required int firstDay,
}) {
  final l10n = context.notificationsL10n;
  final days = [for (var i = 0; i < 7; i++) (firstDay - 1 + i) % 7 + 1];
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.weekly),
      children: [
        for (final day in days)
          ListTile(
            key: ValueKey('notifications-weekly-day-$day'),
            title: Text(_weekdayName(context, day)),
            trailing: day == selected
                ? const Icon(Icons.check_rounded, color: AppColors.ink)
                : null,
            onTap: () => Navigator.of(context).pop(day),
          ),
      ],
    ),
  );
}

/// A row that shows a choice and changes it on a tap.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.tileKey,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final Key tileKey;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      onTap: onTap,
      minTileHeight: 44,
      contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
      title: Text(title, style: AppText.body.copyWith(color: AppColors.ink)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          value,
          style: AppText.body.copyWith(
            color: AppColors.coralDark,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.tileKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.strong = false,
  });

  final Key tileKey;
  final String title;
  final List<String> subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: tileKey,
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 10),
      title: Text(
        title,
        style: strong
            ? AppText.cardTitle
            : AppText.body.copyWith(color: AppColors.ink),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in subtitle) Text(line, style: _noteStyle),
              ],
            ),
    );
  }
}

/// The phone does not let PetLoop show notifications.
class _Blocked extends StatelessWidget {
  const _Blocked({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.notificationsL10n;
    return Padding(
      key: NotificationSettingsCard.blockedKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 10, top: 2),
                child: Icon(
                  Icons.notifications_off_rounded,
                  color: AppColors.coralDark,
                  size: 22,
                ),
              ),
              Expanded(
                child: Text(l10n.blockedTitle, style: AppText.cardTitle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.blockedNote, style: _noteStyle),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              key: NotificationSettingsCard.openSettingsKey,
              onPressed: onOpen,
              child: Text(l10n.openPhoneSettings),
            ),
          ),
        ],
      ),
    );
  }
}

/// Android's "Alarms & reminders": whether reminders arrive on the minute.
class _Exact extends StatelessWidget {
  const _Exact({super.key, required this.allowed, required this.onAllow});

  final bool allowed;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.notificationsL10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.exactTitle,
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
              ),
              if (allowed) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.sage,
                  size: 20,
                ),
                const SizedBox(width: 6),
                // Only as wide as it needs, so it sits at the end of the row.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    l10n.exactAllowed,
                    style: _noteStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.exactNote, style: _noteStyle),
          if (!allowed) ...[
            const SizedBox(height: 4),
            Text(l10n.exactMissing, style: _noteStyle),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                key: NotificationSettingsCard.exactAllowKey,
                onPressed: onAllow,
                child: Text(l10n.exactAllow),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
