import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/audience.dart';

/// The Dogs · Cats · Everything chips at the top of the Chat and Guides
/// sections, with a line saying what is shown and why.
///
/// The choice starts on the selected pet's kind; Everything is always one
/// tap away.
class ScopeBar extends ConsumerWidget {
  const ScopeBar({super.key, required this.what});

  /// What the section lists, as in "all [what]": "rooms" or "guides".
  final String what;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(communityScopeProvider);
    final pet = ref.watch(selectedPetProvider);
    final matched =
        scope != CommunityScope.everything && scope == CommunityScope.forSpecies(pet.species) && pet.name.isNotEmpty;
    final caption = matched
        ? 'Matched to ${pet.name}. Tap Everything to see all $what.'
        : 'Showing $what for ${scope.noun}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Row(
            children: [
              for (final option in CommunityScope.values) ...[
                if (option != CommunityScope.values.first) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('scope-${option.name}'),
                  label: Text(option.label),
                  selected: option == scope,
                  showCheckmark: false,
                  onSelected: (_) => ref.read(communityScopeProvider.notifier).select(option),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen + 4, 4, AppSpacing.screen + 4, 0),
          child: Text(caption, style: AppText.label.copyWith(color: AppColors.brown)),
        ),
      ],
    );
  }
}
