import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../access/access_provider.dart';
import '../../auth/app_user.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../platform/feature_ui.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/petloop_icon.dart';
import 'admin_tools_screen.dart';
import 'settings_routes.dart';
import 'widgets/delete_account_dialog.dart';
import 'widgets/menu_card.dart';
import 'widgets/menu_entry.dart';

/// The You page, behind the avatar of every header: who is signed in, My
/// pets and Budget, Settings, Community safety and About, the admin tools
/// (for accounts that have any), and Sign out with Delete account under it.
///
/// A full-screen route beside the tabs (no bottom bar), pushed above the
/// tab it was opened from (see `settings_routes.dart`).
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  static const screenKey = Key('you-screen');
  static const myPetsKey = Key('you-my-pets');
  static const budgetKey = Key('you-budget');
  static const settingsKey = Key('you-settings');
  static const safetyKey = Key('you-community-safety');
  static const aboutKey = Key('you-about');
  static const adminKey = Key('you-admin-tools');
  static const signOutKey = Key('you-sign-out');
  static const deleteKey = Key('you-delete-account');

  /// Where the Household module puts its row, under My pets.
  static const householdSlot = 'you-household';

  /// The location of the Community tab's safety page (rules, blocked
  /// members); `CommunityRoutes.safety` is this.
  static const _communitySafety = '/community/safety';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).value;
    final petCount = ref.watch(petsProvider.select((pets) => pets.length));
    final admin = AdminTools.of(ref);

    return Scaffold(
      key: screenKey,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: l10n.youTitle,
            showBack: true,
            bottom: _Account(user: user),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                16,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                MenuCard(
                  children: [
                    if (ref.watch(capabilityProvider('pets.view')))
                      MenuEntry(
                        key: myPetsKey,
                        icon: const PetLoopIcon(PetLoopGlyph.pet),
                        title: l10n.menuMyPets,
                        subtitle: l10n.homePetCount(petCount),
                        subtitleMaxLines: 2,
                        onTap: () =>
                            openFeature<Object>(context, 'my-pets', ''),
                      ),
                    // Only when the module is in the build and allowed: an
                    // empty slot would leave a line in the card.
                    if (ref.watch(capabilityProvider('household.view')) &&
                        canOpenFeature(context, 'household'))
                      featureSlot(householdSlot, ''),
                    if (ref.watch(capabilityProvider('budget.view')))
                      MenuEntry(
                        key: budgetKey,
                        icon: const Icon(Icons.account_balance_wallet_rounded),
                        title: context.budgetL10n.budgetTitle,
                        subtitle: context.budgetL10n.menuBudgetSummary,
                        subtitleMaxLines: 2,
                        onTap: () => openFeature<Object>(context, 'budget', ''),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                MenuCard(
                  children: [
                    MenuEntry(
                      key: settingsKey,
                      icon: const PetLoopIcon(PetLoopGlyph.settings),
                      title: l10n.settingsTitle,
                      subtitle: l10n.settingsSummary,
                      subtitleMaxLines: 2,
                      onTap: () => openSettings(context),
                    ),
                    if (ref.watch(
                      capabilityProvider(
                        'community.feed.view|community.chat.view',
                      ),
                    ))
                      MenuEntry(
                        key: safetyKey,
                        icon: const Icon(Icons.shield_outlined),
                        title: context.communityL10n.safetyTitle,
                        subtitle: l10n.youCommunitySafetySummary,
                        subtitleMaxLines: 2,
                        // Into the Community tab: this page closes with it.
                        onTap: () =>
                            GoRouter.maybeOf(context)?.go(_communitySafety),
                      ),
                    MenuEntry(
                      key: aboutKey,
                      icon: const Icon(Icons.info_outline_rounded),
                      title: l10n.aboutTitle,
                      onTap: () => openAbout(context),
                    ),
                  ],
                ),
                if (admin.any) ...[
                  const SizedBox(height: 12),
                  MenuCard(
                    children: [
                      MenuEntry(
                        key: adminKey,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        title: l10n.youAdminTools,
                        subtitle: l10n.youAdminToolsSummary,
                        subtitleMaxLines: 2,
                        onTap: () => openAdminTools(context),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: signOutKey,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  // The arrow leaves the door towards the end of the line,
                  // so it is mirrored on a right-to-left screen.
                  icon: const PetLoopIcon(
                    PetLoopGlyph.logout,
                    mirrorInRtl: true,
                  ),
                  label: Text(l10n.accountSignOut),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coralDark,
                    side: const BorderSide(
                      color: AppColors.coralDark,
                      width: 2,
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    textStyle: AppText.button(15),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  key: deleteKey,
                  onPressed: () => confirmAndDeleteAccount(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brown,
                    textStyle: AppText.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.accountDelete),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the title, still on the coral: the avatar letter, the name and
/// the e-mail of the signed-in account. Not a button.
class _Account extends StatelessWidget {
  const _Account({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final user = this.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.85),
                width: 2,
              ),
            ),
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  user?.initial ?? '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.email ?? '',
                  // An address reads left to right on every screen.
                  textDirection: TextDirection.ltr,
                  style: AppText.secondary.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
