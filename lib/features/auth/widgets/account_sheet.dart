import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/petloop_icon.dart';
import '../../settings/settings_routes.dart';
import '../../settings/widgets/menu_entry.dart';

/// Bottom sheet opened from the account avatar: who is signed in, a row
/// that leads to the Settings page (language, week) and a sign-out button.
class AccountSheet extends ConsumerWidget {
  const AccountSheet({super.key, required this.user});

  final AppUser user;

  static const settingsKey = Key('account-settings');

  static Future<void> show(BuildContext context, AppUser user) =>
      showModalBottomSheet<void>(
        context: context,
        // The sheet takes the height of its content and scrolls on a short
        // screen or with large text.
        isScrollControlled: true,
        backgroundColor: AppColors.cream,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.shellRadius),
          ),
        ),
        builder: (_) => AccountSheet(user: user),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          16,
          AppSpacing.screen,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: AppText.cardTitle.copyWith(fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        // An address reads left to right on every screen.
                        textDirection: TextDirection.ltr,
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            MenuEntry(
              key: settingsKey,
              icon: const PetLoopIcon(PetLoopGlyph.settings),
              title: l10n.settingsTitle,
              subtitle: l10n.settingsSummary,
              color: AppColors.white,
              onTap: () {
                // The sheet closes first; the page is then opened by what was
                // taken from its context while it was still there.
                final router = GoRouter.maybeOf(context);
                final navigator = Navigator.of(context, rootNavigator: true);
                Navigator.of(context).pop();
                pushSettings(router: router, navigator: navigator);
              },
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).signOut();
              },
              // The arrow leaves the door towards the end of the line, so it
              // is mirrored on a right-to-left screen.
              icon: const PetLoopIcon(PetLoopGlyph.logout, mirrorInRtl: true),
              label: Text(l10n.accountSignOut),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coralDark,
                side: const BorderSide(color: AppColors.coralDark, width: 2),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                textStyle: AppText.button(15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
