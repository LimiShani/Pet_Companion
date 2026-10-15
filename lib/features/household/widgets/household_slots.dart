import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../services/household/state/household_providers.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/petloop_icon.dart';
import '../../settings/widgets/menu_entry.dart';
import '../household_routes.dart';
import '../household_words.dart';
import 'member_avatar.dart';

/// The You page's Household row: the names of the people the account
/// shares its pets with, or an invitation to share them.
class HouseholdMenuEntry extends ConsumerWidget {
  const HouseholdMenuEntry({super.key});

  static const entryKey = Key('you-household');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.householdL10n;
    final me = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final households = ref.watch(householdsProvider).value ?? const [];
    final seen = <String>{};
    final others = [
      for (final household in households)
        for (final member in household.othersThan(me))
          if (seen.add(member.userId)) member,
    ];
    return MenuEntry(
      key: entryKey,
      icon: const PetLoopIcon(PetLoopGlyph.home),
      area: AppArea.care,
      title: l10n.title,
      subtitle: others.isEmpty ? l10n.youRowSolo : namesOf(l10n, others),
      subtitleMaxLines: 2,
      onTap: () => openHousehold(context),
    );
  }
}

/// On a shared pet's photo on Home: the other people who look after it, as
/// small overlapping avatars on a white pill. Nothing for a pet nobody
/// shares. Opens the Household page.
class PetPeopleBadge extends ConsumerWidget {
  const PetPeopleBadge({super.key, required this.petId});

  final String petId;

  static const badgeKey = Key('pet-people-badge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(petCarersProvider(petId));
    if (people.isEmpty) return const SizedBox.shrink();
    final l10n = context.householdL10n;
    return Semantics(
      key: badgeKey,
      button: true,
      label: l10n.heroWithLabel(namesOf(l10n, people)),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openHousehold(context),
        // 44 px of tap area around a 34 px pill.
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E5B4636),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: StackedAvatars(members: people, size: 26),
          ),
        ),
      ),
    );
  }
}
