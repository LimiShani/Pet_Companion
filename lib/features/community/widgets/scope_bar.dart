import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../community_words.dart';
import '../data/audience.dart';

/// What a section with a [ScopeBar] lists.
enum ScopeBarSubject { rooms, guides }

/// The Dogs · Cats · Everything chips at the top of the Chat and Guides
/// sections, with a line saying what is shown and why.
///
/// The choice starts on the selected pet's kind; Everything is always one
/// tap away.
class ScopeBar extends ConsumerWidget {
  const ScopeBar({super.key, required this.what});

  /// What the section lists: the caption names it.
  final ScopeBarSubject what;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final scope = ref.watch(communityScopeProvider);
    final pet = ref.watch(selectedPetProvider);
    final matched =
        scope != CommunityScope.everything && scope == CommunityScope.forSpecies(pet.species) && pet.name.isNotEmpty;
    final matchedPet = matched ? l10n.inLine(pet.name) : null;
    final caption = switch (what) {
      ScopeBarSubject.rooms => l10n.roomsCaption(scope, matchedPet: matchedPet),
      ScopeBarSubject.guides => l10n.guidesCaption(scope, matchedPet: matchedPet),
    };

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
                  label: Text(l10n.scope(option)),
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
