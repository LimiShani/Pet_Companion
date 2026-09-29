import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet opened from the account avatar: who is signed in, and a
/// sign-out button.
class AccountSheet extends ConsumerWidget {
  const AccountSheet({super.key, required this.user});

  final AppUser user;

  static Future<void> show(BuildContext context, AppUser user) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.cream,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.shellRadius)),
        ),
        builder: (_) => AccountSheet(user: user),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
                  child: Center(
                    child: Text(user.initial, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: AppText.cardTitle.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(user.email, style: AppText.secondary.copyWith(color: AppColors.brown), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coralDark,
                side: const BorderSide(color: AppColors.coralDark, width: 2),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
