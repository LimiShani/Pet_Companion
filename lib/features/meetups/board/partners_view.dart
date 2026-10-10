import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
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
import '../../../widgets/empty_state.dart';
import '../../community/community_words.dart';
import '../../outdoors/outdoors.dart' show ParkAreaBar;
import '../meetup_actions.dart';
import '../meetups_state.dart';
import 'meetup_card.dart';
import 'meetups_area_picker.dart';

/// Community > Outside > Partners: the area (the profile's city by
/// default), the safety line, "New ad" and "My ads", the filters, and the
/// open ads around, the soonest first.
class PartnersView extends ConsumerWidget {
  const PartnersView({super.key});

  static const listKey = Key('partners-list');
  static const safetyKey = Key('partners-safety');
  static const newAdKey = Key('partners-new-ad');
  static const myAdsKey = Key('partners-my-ads');
  static const sampleKey = Key('partners-sample-note');
  static const retryKey = Key('partners-retry');
  static const widerKey = Key('partners-wider');
  static const clearFiltersKey = Key('partners-clear-filters');
  static const myParksKey = Key('partners-filter-my-parks');
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
    final demo = ref.watch(meetupsRepositoryProvider).isDemo;
    final canPost = ref.watch(capabilityProvider(MeetupCapabilities.post));
    final mine = ref.watch(myMeetupsProvider).value ?? const <Meetup>[];
    final listing = ref.watch(partnersListingProvider);
    final filters = ref.watch(meetupFiltersProvider);
    final scope = ref.watch(communityScopeProvider);

    final children = <Widget>[
      if (demo) ...[
        Text(
          l10n.sampleAds,
          key: sampleKey,
          style: AppText.label.copyWith(color: AppColors.brown),
        ),
        const SizedBox(height: 8),
      ],
      const _SafetyStrip(),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canPost)
            FilledButton.icon(
              key: newAdKey,
              onPressed: () => openMeetupForm(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, kHealthTapTarget),
              ),
              icon: const AppIcon(Icons.add_rounded),
              label: Text(l10n.newAd),
            ),
          OutlinedButton.icon(
            key: myAdsKey,
            onPressed: () => openMyMeetups(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.campaign_outlined),
            label: Text(
              mine.isEmpty ? l10n.myAds : l10n.myAdsCount(mine.length),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
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
        ParkAreaBar(
          area: CityArea(area.city, radius: area.radius),
          onChange: controller.changeArea,
          onRadius: controller.setRadius,
        ),
        const SizedBox(height: 12),
        _Filters(filters: filters, scope: scope),
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
      also: [parkFavoritesProvider],
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(meetupsRevisionProvider.notifier).bump();
          await ref.read(areaMeetupsProvider.future);
        },
        child: ListView(
          key: listKey,
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            14,
            AppSpacing.screen,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: children,
        ),
      ),
    );
  }
}

/// "Meet in a public place and don't share a home address."
class _SafetyStrip extends StatelessWidget {
  const _SafetyStrip();

  @override
  Widget build(BuildContext context) => Container(
    key: PartnersView.safetyKey,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.sage.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
    ),
    child: Row(
      children: [
        const AppIcon(Icons.shield_outlined, size: 20, color: AppColors.ink),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.meetupsL10n.safetyStrip,
            style: AppText.body.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.filters, required this.scope});

  final MeetupFilters filters;
  final CommunityScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final community = context.communityL10n;
    final controller = ref.read(meetupFiltersProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
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
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in CommunityScope.values)
              ChoiceChip(
                key: PartnersView.scopeKey(option),
                label: Text(community.scope(option)),
                selected: option == scope,
                showCheckmark: false,
                onSelected: (_) =>
                    ref.read(communityScopeProvider.notifier).select(option),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
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
                  .read(communityScopeProvider.notifier)
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
