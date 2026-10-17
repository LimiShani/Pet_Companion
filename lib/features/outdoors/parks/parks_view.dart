import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/findvet/data/location_service.dart';
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../platform/feature_ui.dart' show AddTab;
import '../../../widgets/add_sheet.dart' show AddFab;
import '../../../widgets/app_icon.dart';
import '../hazards/hazard_line.dart';
import '../outdoors_words.dart';
import '../review/parks_review_screen.dart';
import '../widgets/park_widgets.dart';
import 'park_area_picker.dart';
import 'park_screen.dart';
import 'suggest_park_screen.dart';

/// Outside > Parks: where to look (until an area is chosen; then it is the
/// chip in the tab's header), one row of filters (the radius, then what is
/// there), "My parks" first, then the area's parks nearest first, and
/// "Missing a park? Suggest a park".
class ParksView extends ConsumerWidget {
  const ParksView({super.key});

  static const listKey = Key('parks-list');
  static const filterRowKey = Key('parks-filter-row');
  static const radiusChipKey = Key('parks-radius-chip');
  static const sampleKey = Key('parks-sample-note');
  static const suggestKey = Key('parks-suggest');
  static const reviewKey = Key('parks-review-entry');
  static const retryKey = Key('parks-retry');
  static const widerKey = Key('parks-wider');
  static const clearFiltersKey = Key('parks-clear-filters');
  static Key filterKey(ParkDetail detail) => Key('parks-filter-${detail.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.outdoorsL10n;
    final state = ref.watch(parksControllerProvider);
    final where = ref.watch(outsideAreaProvider);
    final controller = ref.read(parksControllerProvider.notifier);
    final demo = ref.watch(parksRepositoryProvider).isDemo;
    final reviewer = ref.watch(capabilityProvider(ParkCapabilities.review));
    final canSuggest = ref.watch(capabilityProvider(ParkCapabilities.suggest));
    final area = state.area;
    final listing = ref.watch(parksListingProvider);
    final saved = ref.watch(savedParksProvider).value ?? const <DogPark>[];

    void open(DogPark park) => openParkPage(context, park.id, initial: park);

    final children = <Widget>[
      if (demo) ...[const _SampleNote(), const SizedBox(height: 12)],
      if (reviewer) ...[const _ReviewEntry(), const SizedBox(height: 12)],
      if (area == null) ...[
        ParkAreaPicker(
          locating: where.locating,
          problem: where.problem,
          onNearMe: controller.useMyLocation,
          onOpenSettings: () => ref
              .read(locationServiceProvider)
              .openSettings(
                where.problem == AreaProblem.serviceOff
                    ? LocationOutcome.serviceOff
                    : LocationOutcome.deniedForever,
              ),
          onCity: controller.chooseCity,
        ),
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle(l10n.myParks),
          for (final park in saved)
            _CardGap(
              ParkCard(
                listing: ParkListing(park, saved: true),
                showDistance: false,
                onTap: () => open(park),
              ),
            ),
        ],
      ] else ...[
        _FilterRow(
          area: area,
          onRadius: controller.setRadius,
          selected: state.filters,
          onToggle: controller.toggleFilter,
        ),
        if (area is NearMeArea && area.isApproximate)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, top: 6),
            child: Text(
              l10n.approximateLocation(((area.accuracyM ?? 0) / 1000).ceil()),
              style: AppText.secondary.copyWith(color: AppColors.ink),
            ),
          ),
        const SizedBox(height: 12),
        const HazardLine(),
        ...switch (listing) {
          null || AsyncLoading() => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Semantics(
                label: l10n.searching,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          AsyncError() => [
            _Notice(
              text: l10n.loadFailed,
              action: TextButton(
                key: retryKey,
                onPressed: controller.load,
                child: Text(context.l10n.commonTryAgain),
              ),
            ),
          ],
          AsyncData(:final value) => _results(
            context,
            value,
            area: area,
            filtered: state.filters.isNotEmpty,
            onOpen: open,
            onClearFilters: controller.clearFilters,
            onWider: area.radius == ParkRadius.km25
                ? null
                : () => controller.setRadius(ParkRadius.km25),
          ),
        },
      ],
      if (canSuggest) ...[
        const SizedBox(height: 20),
        _MissingPark(onSuggest: () => openSuggestPark(context)),
      ],
      const SizedBox(height: 16),
      const OsmCredit(),
    ];

    return ListView(
      key: listKey,
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        12,
        AppSpacing.screen,
        // Room for the tab's floating "+" under the last row.
        (AddFab.available(ref, AddTab.outside) ? AppSpacing.fabClearance : 24) +
            MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }

  List<Widget> _results(
    BuildContext context,
    ParksListing listing, {
    required ParkArea area,
    required bool filtered,
    required ValueChanged<DogPark> onOpen,
    required VoidCallback onClearFilters,
    required VoidCallback? onWider,
  }) {
    final l10n = context.outdoorsL10n;
    Widget card(ParkListing item) => _CardGap(
      ParkCard(
        listing: item,
        showDistance: area is NearMeArea && !area.isApproximate,
        onTap: () => onOpen(item.park),
      ),
    );
    return [
      if (listing.saved.isNotEmpty) ...[
        _SectionTitle(l10n.myParks),
        for (final item in listing.saved) card(item),
        const SizedBox(height: 10),
      ],
      if (listing.nearby.isNotEmpty) ...[
        _SectionTitle(l10n.parksInArea),
        for (final item in listing.nearby) card(item),
      ] else if (filtered)
        _Notice(
          text: l10n.noFilterMatch,
          action: TextButton(
            key: clearFiltersKey,
            onPressed: onClearFilters,
            child: Text(l10n.clearFilters),
          ),
        )
      else
        _Notice(
          title: l10n.noParksTitle,
          text: l10n.noParksBody,
          action: onWider == null
              ? null
              : TextButton(
                  key: widerKey,
                  onPressed: onWider,
                  child: Text(l10n.noParksWider),
                ),
        ),
    ];
  }
}

class _CardGap extends StatelessWidget {
  const _CardGap(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: child);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
        child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
      ),
    );
  }
}

/// One row that scrolls sideways: "Up to 10 km ▾", a divider, then the
/// details a park must have.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.area,
    required this.onRadius,
    required this.selected,
    required this.onToggle,
  });

  final ParkArea area;
  final ValueChanged<ParkRadius> onRadius;
  final Set<ParkDetail> selected;
  final ValueChanged<ParkDetail> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    return SingleChildScrollView(
      key: ParksView.filterRowKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ParkRadiusChip(
            key: ParksView.radiusChipKey,
            area: area,
            onRadius: onRadius,
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.brown.withValues(alpha: 0.3),
          ),
          Semantics(
            label: l10n.filtersLabel,
            child: Row(
              children: [
                for (final detail in ParkDetail.filters)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      key: ParksView.filterKey(detail),
                      avatar: AppIcon(parkDetailIcon(detail), size: 16),
                      label: Text(l10n.detail(detail)),
                      selected: selected.contains(detail),
                      showCheckmark: false,
                      onSelected: (_) => onToggle(detail),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.title, this.action});

  final String? title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppText.cardTitle),
            const SizedBox(height: 4),
          ],
          Text(text, style: AppText.body.copyWith(color: AppColors.brown)),
          ?action,
        ],
      ),
    );
  }
}

class _MissingPark extends StatelessWidget {
  const _MissingPark({required this.onSuggest});

  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            l10n.missingPark,
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          TextButton.icon(
            key: ParksView.suggestKey,
            onPressed: onSuggest,
            style: TextButton.styleFrom(
              minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.add_location_alt_rounded, size: 20),
            label: Text(l10n.suggestPark),
          ),
        ],
      ),
    );
  }
}

class _SampleNote extends StatelessWidget {
  const _SampleNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ParksView.sampleKey,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Text(context.outdoorsL10n.sampleData, style: AppText.body),
    );
  }
}

/// For park reviewers: how many suggestions wait, and the way to them.
class _ReviewEntry extends ConsumerWidget {
  const _ReviewEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.outdoorsL10n;
    final count = ref.watch(parkReviewQueueProvider).value?.count ?? 0;
    return OutlinedButton.icon(
      key: ParksView.reviewKey,
      onPressed: () => openParksReview(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kHealthTapTarget),
        alignment: AlignmentDirectional.centerStart,
      ),
      icon: const AppIcon(Icons.fact_check_rounded),
      label: Text(
        count == 0 ? l10n.reviewEntryEmpty : l10n.reviewEntry(count),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
