import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/community/data/audience.dart';
import '../../../services/findvet/data/location_service.dart';
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../platform/feature_ui.dart' show AddTab;
import '../../../widgets/add_sheet.dart' show AddFab;
import '../../../widgets/empty_state.dart';
import '../../outdoors/outdoors.dart'
    show HazardLine, ParkRadiusChip, areaHazardsProvider, shownHazardsProvider;
import '../meetup_actions.dart';
import '../meetups_state.dart';
import 'going_now.dart';
import 'meetup_card.dart';
import 'meetups_area_picker.dart';
import 'partners_filters_sheet.dart';

/// Outside > Partners: until Outside has an area (the profile's city by
/// default), where to look; then one row ("Filters", the distance, "My
/// ads") and the open ads around, the soonest first ("going out now" ads
/// at the top, under the "Going out soon?" card and the hazard line). The
/// area is the chip
/// in the tab's header; a new ad is "Plan a walk or play date" in the tab's
/// Add sheet (its "+").
class PartnersView extends ConsumerWidget {
  const PartnersView({super.key});

  static const listKey = Key('partners-list');
  static const controlRowKey = Key('partners-controls');
  static const radiusChipKey = Key('partners-radius-chip');
  static const myAdsKey = Key('partners-my-ads');
  static const sampleKey = Key('partners-sample-note');
  static const retryKey = Key('partners-retry');
  static const widerKey = Key('partners-wider');
  static const clearFiltersKey = Key('partners-clear-filters');
  static const myParksKey = Key('partners-filter-my-parks');
  static const filtersKey = Key('partners-filters');
  static Key radiusKey(ParkRadius radius) =>
      Key('partners-radius-${radius.name}');
  static Key kindKey(MeetupKind? kind) =>
      Key('partners-kind-${kind?.name ?? 'all'}');
  static Key whenKey(MeetupWhen when) => Key('partners-when-${when.name}');
  static Key scopeKey(CommunityScope scope) =>
      Key('partners-scope-${scope.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final state = ref.watch(meetupsAreaProvider);
    final controller = ref.read(meetupsAreaProvider.notifier);
    final area = state.area;
    final outsideArea = ref.watch(outsideAreaProvider.select((s) => s.area));
    final demo = ref.watch(meetupsRepositoryProvider).isDemo;
    final plus = AddFab.available(ref, AddTab.outside);
    final listing = ref.watch(partnersListingProvider);
    final filters = ref.watch(meetupFiltersProvider);
    final scope = ref.watch(meetupAnimalProvider);
    final filterCount = ref.watch(partnersFilterCountProvider);

    final children = <Widget>[
      if (demo) ...[
        Text(
          l10n.sampleAds,
          key: sampleKey,
          style: AppText.label.copyWith(color: AppColors.brown),
        ),
        const SizedBox(height: 6),
      ],
      if (area == null && state.resolving)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (area == null)
        MeetupsAreaPicker(
          locating: state.locating,
          problem: state.problem,
          onNearMe: controller.useMyLocation,
          onOpenSettings: () => ref
              .read(locationServiceProvider)
              .openSettings(
                state.problem == AreaProblem.serviceOff
                    ? LocationOutcome.serviceOff
                    : LocationOutcome.deniedForever,
              ),
          onCity: controller.chooseCity,
        )
      else ...[
        // "Going out soon?", then the hazard line, above the board.
        const GoingOutCard(),
        const SizedBox(height: 12),
        const HazardLine(),
        _ControlRow(
          count: filterCount,
          area: outsideArea ?? CityArea(area.city, radius: area.radius),
          onRadius: controller.setRadius,
        ),
        const SizedBox(height: 12),
        ...switch (listing) {
          AsyncValue(:final value?) when value.isNotEmpty => [
            for (final item in value)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MeetupCard(
                  meetup: item.meetup,
                  distanceM: item.distanceM,
                ),
              ),
          ],
          AsyncValue(hasValue: true) => [
            _Empty(
              filtered: !filters.isEmpty || scope != CommunityScope.everything,
              canWiden: area.radius != ParkRadius.km25,
            ),
          ],
          AsyncValue(hasError: true) => [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: l10n.loadFailed,
              message: '',
              actionLabel: context.l10n.commonTryAgain,
              onAction: () => ref.invalidate(areaMeetupsProvider),
            ),
          ],
          _ => [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    ];

    return MeetupsKeeper(
      also: [parkFavoritesProvider, areaHazardsProvider, shownHazardsProvider],
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(meetupsRevisionProvider.notifier).bump();
          await ref.read(areaMeetupsProvider.future);
        },
        child: ListView(
          key: listKey,
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            // Room for the tab's floating "+" under the last ad.
            (plus ? 88 : 24) + MediaQuery.paddingOf(context).bottom,
          ),
          children: children,
        ),
      ),
    );
  }
}

/// One row: "Filters · 2" (opens the sheet), "Up to 10 km ▾" (Outside's
/// radius) and, at the end, "My ads (2)".
class _ControlRow extends ConsumerWidget {
  const _ControlRow({
    required this.count,
    required this.area,
    required this.onRadius,
  });

  /// How many of the sheet's filters differ from where the board starts.
  final int count;
  final ParkArea area;
  final ValueChanged<ParkRadius> onRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final mine = ref.watch(myMeetupsProvider).value ?? const <Meetup>[];
    // The chips scroll sideways when a big font leaves them too little
    // room; "My ads" keeps the end.
    return Row(
      key: PartnersView.controlRowKey,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: l10n.filtersLabel(count),
                  onTap: () => openPartnersFilters(context),
                  excludeSemantics: true,
                  child: ActionChip(
                    key: PartnersView.filtersKey,
                    backgroundColor: count == 0
                        ? AppColors.white
                        : AppColors.yellow,
                    // Snug, so the row fits a 320 px phone.
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    labelPadding: const EdgeInsetsDirectional.only(
                      start: 4,
                      end: 6,
                    ),
                    avatar: const AppIcon(Icons.filter_list_rounded, size: 18),
                    label: Text(
                      count == 0 ? l10n.filters : l10n.filtersCount(count),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => openPartnersFilters(context),
                  ),
                ),
                const SizedBox(width: 8),
                ParkRadiusChip(
                  key: PartnersView.radiusChipKey,
                  area: area,
                  onRadius: onRadius,
                  optionKey: PartnersView.radiusKey,
                ),
              ],
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: TextButton(
            key: PartnersView.myAdsKey,
            onPressed: () => openMyMeetups(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              mine.isEmpty ? l10n.myAds : l10n.myAdsCount(mine.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.filtered, required this.canWiden});

  final bool filtered;
  final bool canWiden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: Icons.directions_walk_rounded,
          title: filtered ? l10n.emptyFiltered : l10n.emptyTitle,
          message: filtered ? '' : l10n.emptyBody,
        ),
        if (filtered)
          TextButton(
            key: PartnersView.clearFiltersKey,
            onPressed: () {
              ref.read(meetupFiltersProvider.notifier).clear();
              ref
                  .read(meetupAnimalProvider.notifier)
                  .select(CommunityScope.everything);
            },
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            child: Text(l10n.clearFilters),
          ),
        if (canWiden)
          OutlinedButton(
            key: PartnersView.widerKey,
            onPressed: () => ref
                .read(meetupsAreaProvider.notifier)
                .setRadius(ParkRadius.km25),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            child: Text(l10n.lookFurther),
          ),
      ],
    );
  }
}
