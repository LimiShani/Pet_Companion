import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../notification_platform.dart';

/// Explains what PetLoop reminds about, then shows the phone's own
/// permission prompt. On Android, when notifications are allowed but
/// "Alarms & reminders" is not, a second step offers that too.
///
/// [notificationsAllowed]: the phone already allows notifications, so the
/// sheet starts at the second step. Completes when the sheet is closed.
Future<void> showNotificationPermissionSheet(
  BuildContext context, {
  required NotificationPlatform platform,
  bool notificationsAllowed = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => NotificationPermissionSheet(platform: platform, startWithExact: notificationsAllowed),
  );
}

class NotificationPermissionSheet extends StatefulWidget {
  const NotificationPermissionSheet({super.key, required this.platform, this.startWithExact = false});

  static const sheetKey = Key('notification-permission-sheet');
  static const allowKey = Key('notification-permission-allow');
  static const laterKey = Key('notification-permission-later');
  static const exactKey = Key('notification-permission-exact');

  final NotificationPlatform platform;
  final bool startWithExact;

  @override
  State<NotificationPermissionSheet> createState() => _NotificationPermissionSheetState();
}

class _NotificationPermissionSheetState extends State<NotificationPermissionSheet> {
  late bool _exactStep = widget.startWithExact;
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    var nextStep = false;
    try {
      await widget.platform.requestPermission();
      // What the phone allows now, rather than the prompt's answer: on a
      // real run that answer once came back "not allowed" right after
      // "Allow", and the sheet closed before the "on the minute" step.
      final access = await widget.platform.access();
      nextStep = access.allowed && access.exact == false;
    } catch (_) {
      // Nothing to add: Settings shows what the phone allows.
    }
    if (!mounted) return;
    if (nextStep) {
      setState(() {
        _busy = false;
        _exactStep = true;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _allowExact() async {
    setState(() => _busy = true);
    try {
      await widget.platform.requestExactAlarms();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.notificationsL10n;
    return SingleChildScrollView(
      key: NotificationPermissionSheet.sheetKey,
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
              child: Icon(
                _exactStep ? Icons.alarm_rounded : Icons.notifications_active_rounded,
                color: AppColors.ink,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(_exactStep ? l10n.askExactTitle : l10n.askTitle, style: AppText.petName, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          if (_exactStep) ...[
            Text(l10n.exactNote, style: AppText.body.copyWith(color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(l10n.exactMissing, style: AppText.body.copyWith(color: AppColors.brown)),
          ] else ...[
            Text(l10n.askIntro, style: AppText.body.copyWith(color: AppColors.ink)),
            const SizedBox(height: 10),
            _Point(icon: Icons.restaurant_rounded, color: AppColors.yellow, text: l10n.askMeals),
            _Point(icon: Icons.medication_rounded, color: AppColors.sage, text: l10n.askMedicines),
            _Point(icon: Icons.event_rounded, color: AppColors.peach, text: l10n.askAppointments),
            const SizedBox(height: 8),
            Text(
              l10n.askFoot,
              style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            key: _exactStep ? NotificationPermissionSheet.exactKey : NotificationPermissionSheet.allowKey,
            label: _exactStep ? l10n.askExactAllow : l10n.askAllow,
            loading: _busy,
            onPressed: _exactStep ? _allowExact : _allow,
          ),
          const SizedBox(height: 6),
          TextButton(
            key: NotificationPermissionSheet.laterKey,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(l10n.askLater),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.ink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.body.copyWith(color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}
