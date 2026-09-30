import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../state/pets_provider.dart';
import '../../auth/widgets/account_sheet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pet_selector.dart';

/// Coral header: menu, branding, account avatar and the dog selector.
///
/// Square-bottomed: the hero below it paints the rest of the coral band and
/// its rounded bottom edge.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider);
    final user = ref.watch(authControllerProvider).value;

    return ColoredBox(
      color: AppColors.coral,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu_rounded, size: 26),
                    color: AppColors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pets_rounded, color: AppColors.white, size: 22),
                          const SizedBox(width: 8),
                          Text('Pet Companion', style: AppText.appTitle.copyWith(color: AppColors.white)),
                        ],
                      ),
                    ),
                  ),
                  _AccountAvatar(
                    initial: user?.initial ?? '?',
                    onTap: user == null ? null : () => AccountSheet.show(context, user),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: PetSelector(onAdd: () {})),
                  const SizedBox(width: 8),
                  Text(
                    '${pets.length} ${pets.length == 1 ? 'dog' : 'dogs'}',
                    style: AppText.label.copyWith(color: AppColors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.initial, required this.onTap});

  final String initial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Account',
      child: Material(
        color: AppColors.yellow,
        shape: CircleBorder(side: BorderSide(color: AppColors.white.withValues(alpha: 0.85), width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(initial, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
