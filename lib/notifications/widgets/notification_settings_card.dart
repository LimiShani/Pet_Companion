import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../notifications.dart';

/// The Notifications section of the Settings page: the master switch, one
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

  static Key kindKey(NotificationKind kind) =>
      ValueKey('notifications-${kind.name}');

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
    ];

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
              subtitle: [l10n.masterNote],
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
