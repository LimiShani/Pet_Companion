import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/feature_ui.dart';
import '../../../presentation/health_widgets.dart'
    show confirmDelete, kHealthTapTarget, showHealthSheet, SheetTitle;
import '../../../services/outdoors/data/park_area.dart';
import '../../../services/outdoors/data/park_launcher.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../outdoors_words.dart';
import '../widgets/park_widgets.dart';
import 'update_details_sheet.dart';
import '../../../widgets/app_tag.dart';

/// The slots another feature (meetups) fills on the park page. Each gets
/// the values `parkId`, `parkName` (with the city) and `parkTags` (the
/// details the park is known to have, as [ParkDetail]s). Empty slots take
/// no room.
abstract final class ParkPageSlots {
  /// "Meetups at this park": the section, under the details.
  static const meetups = 'park-meetups';

  /// "Post a meetup here": a button, beside Navigate and Update details.
  static const postMeetup = 'park-meetup-post';
}

/// Opens a park's page over the current tab (the bottom bar stays).
/// [initial] shows at once while the page fetches the park again.
Future<void> openParkPage(
  BuildContext context,
  String parkId, {
  DogPark? initial,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ParkScreen(parkId: parkId, initial: initial),
  ),
);

class ParkScreen extends ConsumerWidget {
  const ParkScreen({super.key, required this.parkId, this.initial});

  static const screenKey = Key('park-screen');
  static const saveKey = Key('park-save');
  static const navigateKey = Key('park-navigate');
  static const wazeKey = Key('park-navigate-waze');
  static const googleMapsKey = Key('park-navigate-google');
  static const updateKey = Key('park-update-details');
  static Key reviewerKey(ParkStatus status) =>
      Key('park-reviewer-${status.name}');
  static Key detailKey(ParkDetail detail) => Key('park-detail-${detail.name}');

  final String parkId;
  final DogPark? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: ParkCapabilities.view,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final fetched = ref.watch(parkProvider(parkId));
        final park = fetched.hasValue ? fetched.value : initial;
        if (park == null) {
          return Scaffold(
            key: screenKey,
            body: Column(
              children: [
                CoralHeader(
                  title: context.outdoorsL10n.parkDefaultName,
                  showBack: true,
                ),
                Expanded(
                  child: fetched.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: EmptyState(
                            icon: Icons.park_outlined,
                            title: context.outdoorsL10n.parkGone,
                            message: context.outdoorsL10n.osmCredit,
                          ),
                        ),
                ),
              ],
            ),
          );
        }
        return _ParkPage(park: park);
      },
    ),
  );
}

class _ParkPage extends ConsumerWidget {
  const _ParkPage({required this.park});

  final DogPark park;

  Future<void> _toggleSave(BuildContext context, WidgetRef ref) async {
    final l10n = context.outdoorsL10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(parkFavoritesProvider.notifier)
          .toggle(park.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              saved ? l10n.savedToMyParks : l10n.removedFromMyParks,
            ),
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  /// A reviewer closes, reopens or removes the park from its page.
  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    ParkStatus status,
  ) async {
    final l10n = context.outdoorsL10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (status == ParkStatus.removed) {
      final sure = await confirmDelete(
        context,
        title: l10n.removePark,
        message: l10n.removeConfirm,
        confirmLabel: l10n.removePark,
      );
      if (!sure) return;
    }
    try {
      await ref.read(parksRepositoryProvider).setParkStatus(park.id, status);
      ref.invalidate(parkProvider(park.id));
      ref.invalidate(parkReviewQueueProvider);
      await ref.read(parksControllerProvider.notifier).refresh();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.reviewDone)));
      if (status == ParkStatus.removed) navigator.maybePop();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.reviewFailed)));
    }
  }

  Future<void> _navigate(BuildContext context, WidgetRef ref) async {
    final l10n = context.outdoorsL10n;
    final messenger = ScaffoldMessenger.of(context);
    final app = await showHealthSheet<NavigationApp>(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          SheetTitle(l10n.navigateWith),
          const SizedBox(height: 14),
          for (final (app, key, label) in [
            (NavigationApp.waze, ParkScreen.wazeKey, l10n.waze),
            (NavigationApp.googleMaps, ParkScreen.googleMapsKey, l10n.googleMaps),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Builder(
                builder: (sheet) => OutlinedButton.icon(
                  key: key,
                  onPressed: () => Navigator.of(sheet).pop(app),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(kHealthTapTarget),
                  ),
                  icon: const AppIcon(Icons.navigation_rounded),
                  label: Text(label),
                ),
              ),
            ),
        ],
      ),
    );
    if (app == null) return;
    final opened = await ref
        .read(parkLauncherProvider)
        .navigate(app, park.point);
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.navigateFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final saved =
        ref.watch(parkFavoritesProvider).value?.contains(park.id) ?? false;
    final area = ref.watch(parksControllerProvider.select((s) => s.area));
    final city = localityName(park.localityCode, language);
    final distance = area is NearMeArea && !area.isApproximate
        ? l10n.distance(area.point.distanceTo(park.point), language)
        : null;
    final subtitle = [?city, ?distance].join(' · ');
    final canSuggest = ref.watch(capabilityProvider(ParkCapabilities.suggest));
    final reviewer = ref.watch(capabilityProvider(ParkCapabilities.review));
    final slotValues = <String, Object?>{
      'parkId': park.id,
      'parkName': l10n.parkFullName(park, language),
      'parkTags': park.has,
    };

    return Scaffold(
      key: ParkScreen.screenKey,
      body: Column(
        children: [
          CoralHeader(
            title: l10n.parkTitle(park, language),
            showBack: true,
            actions: [
              CoralHeaderAction(
                key: ParkScreen.saveKey,
                icon: saved ? Icons.star_rounded : Icons.star_border_rounded,
                tooltip: saved ? l10n.removeFromMyParks : l10n.saveToMyParks,
                onPressed: () => _toggleSave(context, ref),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                14,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: AppText.body.copyWith(
                      color: AppColors.brown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (park.isClosed) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppTag(
                      l10n.closedLabel,
                      tone: AppTagTone.yellow,
                      icon: Icons.construction_rounded,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: ParkScreen.navigateKey,
                      onPressed: () => _navigate(context, ref),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, kHealthTapTarget),
                      ),
                      icon: const AppIcon(Icons.navigation_rounded),
                      label: Text(l10n.navigate),
                    ),
                    if (canSuggest)
                      OutlinedButton.icon(
                        key: ParkScreen.updateKey,
                        onPressed: () => openUpdateDetails(context, park),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, kHealthTapTarget),
                        ),
                        icon: const AppIcon(Icons.edit_note_rounded),
                        label: Text(l10n.updateDetails),
                      ),
                    featureSlot(ParkPageSlots.postMeetup, '', slotValues),
                  ],
                ),
                const SizedBox(height: 20),
                _Details(park: park),
                if (park.openingHours case final hours?) ...[
                  const SizedBox(height: 14),
                  Text(
                    l10n.openingHours,
                    style: AppText.label.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hours,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: AppText.body,
                  ),
                ],
                if (canSuggest &&
                    ParkDetail.values.any(
                      (d) => park.answer(d) == ParkAnswer.unknown,
                    )) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.unknownNote,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ],
                featureSlot(ParkPageSlots.meetups, '', slotValues),
                if (reviewer) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n.reviewerTools,
                    style: AppText.label.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (status, label) in [
                        park.isClosed
                            ? (ParkStatus.active, l10n.reopenPark)
                            : (ParkStatus.closed, l10n.markClosed),
                        (ParkStatus.removed, l10n.removePark),
                      ])
                        OutlinedButton(
                          key: ParkScreen.reviewerKey(status),
                          onPressed: () => _setStatus(context, ref, status),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, kHealthTapTarget),
                          ),
                          child: Text(label),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (park.source == ParkSource.member) ...[
                  Text(
                    l10n.memberPark,
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 4),
                ],
                const OsmCredit(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "What's there": the six details, each yes, no or not known.
class _Details extends StatelessWidget {
  const _Details({required this.park});

  final DogPark park;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              header: true,
              child: Text(l10n.whatsThere, style: AppText.cardTitle),
            ),
          ),
          for (final detail in ParkDetail.values)
            _DetailRow(
              key: ParkScreen.detailKey(detail),
              detail: detail,
              answer: park.answer(detail),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({super.key, required this.detail, required this.answer});

  final ParkDetail detail;
  final ParkAnswer answer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final (IconData icon, Color color) = switch (answer) {
      ParkAnswer.yes => (Icons.check_circle_rounded, AppColors.sage),
      ParkAnswer.no => (Icons.cancel_rounded, AppColors.coralDark),
      ParkAnswer.unknown => (Icons.help_outline_rounded, AppColors.brown),
    };
    return MergeSemantics(
      child: Semantics(
        label: l10n.detailAnswer(l10n.detail(detail), l10n.answer(answer)),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              AppIcon(parkDetailIcon(detail), size: 20, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.detail(detail),
                  style: AppText.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppIcon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.answer(answer),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
