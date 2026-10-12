import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart'
    show HealthSheetBody, SheetTitle, kHealthTapTarget;
import '../../../services/community/data/audience.dart';
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../community/community_words.dart';
import '../meetups_state.dart';
import 'partners_view.dart';

/// Opens the board's filters. Every choice applies at once (the ads behind
/// the sheet follow it), so the button only closes the sheet.
Future<void> openPartnersFilters(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HealthSheetBody(child: PartnersFiltersSheet()),
    );

/// Walk or play, the animal (the board's own choice, apart from the
/// Community's), when, and "At my parks", with "Clear all" and "Show N
/// ads". The distance is a chip on the board itself.
class PartnersFiltersSheet extends ConsumerWidget {
  const PartnersFiltersSheet({super.key});

  static const sheetKey = Key('partners-filters-sheet');
  static const clearAllKey = Key('partners-filters-clear-all');
  static const showKey = Key('partners-filters-show');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final community = context.communityL10n;
    final filters = ref.watch(meetupFiltersProvider);
    final scope = ref.watch(meetupAnimalProvider);
    final count = ref.watch(partnersFilterCountProvider);
    final listing = ref.watch(partnersListingProvider);
    final controller = ref.read(meetupFiltersProvider.notifier);

    return Column(
      key: sheetKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        SheetTitle(l10n.filtersTitle),
        _Group(
          title: l10n.filterKind,
          chips: [
            for (final (kind, label) in [
              (null, l10n.kindAll),
              (MeetupKind.walk, l10n.kindWalk),
              (MeetupKind.play, l10n.kindPlay),
            ])
              ChoiceChip(
                key: PartnersView.kindKey(kind),
                label: Text(label),
                selected: filters.kind == kind,
                showCheckmark: false,
                onSelected: (_) => controller.kind(kind),
              ),
          ],
        ),
        _Group(
          title: l10n.filterAnimal,
          chips: [
            for (final option in CommunityScope.values)
              ChoiceChip(
                key: PartnersView.scopeKey(option),
                label: Text(community.scope(option)),
                selected: option == scope,
                showCheckmark: false,
                onSelected: (_) =>
                    ref.read(meetupAnimalProvider.notifier).select(option),
              ),
          ],
        ),
        _Group(
          title: l10n.filterWhen,
          chips: [
            for (final (option, label) in [
              (MeetupWhen.today, l10n.whenToday),
              (MeetupWhen.thisWeek, l10n.whenThisWeek),
              (MeetupWhen.recurring, l10n.whenRecurring),
            ])
              FilterChip(
                key: PartnersView.whenKey(option),
                label: Text(label),
                selected: filters.when == option,
                showCheckmark: false,
                onSelected: (_) => controller.when(option),
              ),
          ],
        ),
        _Group(
          title: l10n.filterWhere,
          chips: [
            FilterChip(
              key: PartnersView.myParksKey,
              avatar: const AppIcon(Icons.star_rounded, size: 18),
              label: Text(l10n.atMyParks),
              selected: filters.atMyParks,
              showCheckmark: false,
              onSelected: (_) => controller.toggleMyParks(),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton(
          key: showKey,
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(kHealthTapTarget),
          ),
          child: Text(switch (listing) {
            AsyncValue(isLoading: false, :final value?) => l10n.filtersShow(
              value.length,
            ),
            _ => l10n.filtersDone,
          }),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: clearAllKey,
          onPressed: count == 0 ? null : () => clearPartnersFilters(ref),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(kHealthTapTarget),
          ),
          child: Text(l10n.filtersClearAll),
        ),
      ],
    );
  }
}

/// A heading and its chips.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppText.label.copyWith(color: AppColors.brown),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: chips),
      ],
    ),
  );
}
