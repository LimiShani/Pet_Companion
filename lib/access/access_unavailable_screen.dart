import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/coral_header.dart';
import '../widgets/empty_state.dart';
import 'access_provider.dart';

class AccessUnavailableScreen extends ConsumerWidget {
  const AccessUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.accessL10n;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          CoralHeader(title: context.l10n.appName),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: l10n.unavailableTitle,
                    message: l10n.unavailableMessage,
                    actionLabel: l10n.retry,
                    onAction: () => ref.read(accessProvider.notifier).refresh(),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.coralDark,
                    ),
                    child: Text(
                      l10n.signOut,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
