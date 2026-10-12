import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/audience.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../community_words.dart';

/// The animal the Feed, Chat and Guides sections show ("Dogs ▾"), as one
/// chip that opens a menu of Dogs, Cats and Everything.
///
/// The choice is one for the three sections ([communityScopeProvider]): it
/// starts on the selected pet's kind, and Everything is always in the menu.
class ScopeMenuChip extends ConsumerWidget {
  const ScopeMenuChip({super.key});

  static const chipKey = Key('scope-menu');

  /// The key of an item of the open menu: `scope-dogs`, `scope-cats`,
  /// `scope-everything`.
  static Key itemKey(CommunityScope scope) => ValueKey('scope-${scope.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final scope = ref.watch(communityScopeProvider);
    TextStyle itemStyle(bool on) => AppText.body.copyWith(
      color: AppColors.ink,
      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
    );

    return PopupMenuButton<CommunityScope>(
      key: chipKey,
      tooltip: l10n.scopeMenuTooltip,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      onSelected: (option) =>
          ref.read(communityScopeProvider.notifier).select(option),
      itemBuilder: (context) => [
        for (final option in CommunityScope.values)
          PopupMenuItem(
            key: itemKey(option),
            value: option,
            child: Text(l10n.scope(option), style: itemStyle(option == scope)),
          ),
      ],
      // Drawn as a chosen ChoiceChip (the Store's "For dogs" chip), so it
      // sits in a row of chips as one of them.
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
        decoration: const ShapeDecoration(
          color: AppColors.yellow,
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.scope(scope),
              style: AppText.secondary.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 2),
            const AppIcon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}

/// The one filter row of the Feed and Guides sections: the animal menu
/// chip, a thin divider, then the section's own [chips] (kinds of post,
/// categories), scrolling sideways together.
class ScopeFilterRow extends StatelessWidget {
  const ScopeFilterRow({super.key, required this.chips});

  final List<Widget> chips;

  static const dividerKey = Key('scope-divider');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        children: [
          const ScopeMenuChip(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              key: dividerKey,
              width: 1,
              height: 24,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          for (final (index, chip) in chips.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            chip,
          ],
        ],
      ),
    );
  }
}
