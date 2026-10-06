import '../../access/access_provider.dart';
import '../../access/access_admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/petloop_icon.dart';
import '../../platform/feature_ui.dart';
import '../../services/findvet/state/find_vet_providers.dart'
    show vetIsAdminProvider;

import 'settings_routes.dart';
import 'widgets/menu_entry.dart';

/// The app's side menu, opened by the three-bars button at the top of Home:
/// who is signed in, My pets, Budget, Settings, and Sign out alone at the
/// bottom.
///
/// It is the drawer of the tabs' scaffold, so it slides in from the
/// button's side (the left in English, the right in Hebrew), covers the
/// bottom bar, and closes on a tap outside, a swipe back towards its edge,
/// the phone's back button, or after choosing an entry.
class AppSideMenu extends ConsumerWidget {
  const AppSideMenu({super.key});

  static const menuKey = Key('side-menu');
  static const findVetKey = Key('side-menu-find-vet');
  static const directoryReviewKey = Key('side-menu-directory-review');
  static const myPetsKey = Key('side-menu-my-pets');
  static const budgetKey = Key('side-menu-budget');
  static const settingsKey = Key('side-menu-settings');
  static const signOutKey = Key('side-menu-sign-out');

  static const _width = 304.0;

  /// Opens the menu of the scaffold around [context]. Nothing happens where
  /// there is none (a widget pumped on its own in a test).
  static void open(BuildContext context) =>
      Scaffold.maybeOf(context)?.openDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).value;
    final petCount = ref.watch(petsProvider.select((pets) => pets.length));
    final reviewer =
        ref.watch(capabilityProvider('findvet.admin')) &&
        (ref.watch(vetIsAdminProvider).value ?? false);

    void close() => Scaffold.maybeOf(context)?.closeDrawer();

    return Drawer(
      key: menuKey,
      width: _width,
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          end: Radius.circular(AppSpacing.shellRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Account(user: user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              children: [
                if (ref.watch(capabilityProvider('findvet.search')))
                  MenuEntry(
                    key: findVetKey,
                    icon: const Icon(Icons.local_hospital_rounded),
                    title: context.findVetL10n.findVetTitle,
                    subtitle: context.findVetL10n.findVetMenuSubtitle,
                    onTap: () {
                      close();
                      openFeature<Object>(context, 'find-vet', '');
                    },
                  ),
                const SizedBox(height: 4),
                if (ref.watch(capabilityProvider('pets.view')))
                  MenuEntry(
                    key: myPetsKey,
                    icon: const PetLoopIcon(PetLoopGlyph.pet),
                    title: l10n.menuMyPets,
                    subtitle: l10n.homePetCount(petCount),
                    onTap: () {
                      close();
                      openFeature<Object>(context, 'my-pets', '');
                    },
                  ),
                const SizedBox(height: 4),
                if (ref.watch(capabilityProvider('budget.view')))
                  MenuEntry(
                    key: budgetKey,
                    icon: const Icon(Icons.account_balance_wallet_rounded),
                    title: context.budgetL10n.budgetTitle,
                    subtitle: context.budgetL10n.menuBudgetSummary,
                    onTap: () {
                      close();
                      openFeature<Object>(context, 'budget', '');
                    },
                  ),
                const SizedBox(height: 4),
                MenuEntry(
                  key: settingsKey,
                  icon: const PetLoopIcon(PetLoopGlyph.settings),
                  title: l10n.settingsTitle,
                  subtitle: l10n.settingsSummary,
                  onTap: () {
                    close();
                    openSettings(context);
                  },
                ),
                if (ref.watch(capabilityProvider('access.admin')))
                  MenuEntry(
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    title: Localizations.localeOf(context).languageCode == 'he'
                        ? 'הרשאות לתכונות'
                        : 'Feature access',
                    onTap: () {
                      close();
                      openAccessAdministration(context);
                    },
                  ),
                if (ref.watch(capabilityProvider('basket.view')))
                  MenuEntry(
                    icon: const Icon(Icons.shopping_basket_outlined),
                    title: context.budgetL10n.myBasket,
                    onTap: () {
                      close();
                      openFeature<Object>(context, 'basket', '');
                    },
                  ),
                if (reviewer) ...[
                  const SizedBox(height: 4),
                  MenuEntry(
                    key: directoryReviewKey,
                    icon: const Icon(Icons.fact_check_outlined),
                    title: context.findVetL10n.adminTitle,
                    subtitle: context.findVetL10n.adminMenuSubtitle,
                    onTap: () {
                      close();
                      openFeature<Object>(context, 'directory-review', '');
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: OutlinedButton.icon(
                key: signOutKey,
                onPressed: () {
                  close();
                  ref.read(authControllerProvider.notifier).signOut();
                },
                // Mirrored on a right-to-left screen, as in the account sheet.
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
            ),
          ),
        ],
      ),
    );
  }
}

/// The coral top of the menu: the avatar letter, the name and the e-mail
/// of the signed-in account. Not a button.
class _Account extends StatelessWidget {
  const _Account({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final user = this.user;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadiusDirectional.only(
          bottomEnd: Radius.circular(AppSpacing.shellRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
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
        ),
      ),
    );
  }
}
