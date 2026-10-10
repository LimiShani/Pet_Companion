import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/findvet/regions/region.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../outdoors_words.dart';
import '../widgets/park_widgets.dart';

/// The park reviewers' page: members' suggestions (new parks, details) and
/// the parks that vanished from OpenStreetMap. Every decision is checked
/// on the server.
Future<void> openParksReview(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const ParksReviewScreen()));

class ParksReviewScreen extends ConsumerStatefulWidget {
  const ParksReviewScreen({super.key});

  static const screenKey = Key('parks-review');
  static Key approveKey(String id) => Key('parks-review-approve-$id');
  static Key rejectKey(String id) => Key('parks-review-reject-$id');
  static Key mapKey(String id) => Key('parks-review-map-$id');
  static Key statusKey(String parkId, ParkStatus status) =>
      Key('parks-review-${status.name}-$parkId');

  @override
  ConsumerState<ParksReviewScreen> createState() => _ParksReviewScreenState();
}

class _ParksReviewScreenState extends ConsumerState<ParksReviewScreen> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    final l10n = context.outdoorsL10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(parkReviewQueueProvider);
      await ref.read(parksControllerProvider.notifier).refresh();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.reviewDone)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.reviewFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: ParkCapabilities.review,
    builder: (context) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final queue = ref.watch(parkReviewQueueProvider);
    final repository = ref.read(parksRepositoryProvider);
    final launcher = ref.read(parkLauncherProvider);

    Widget body;
    if (queue.isLoading && !queue.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (queue.hasError && !queue.hasValue) {
      body = Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.reviewFailed,
          message: l10n.loadFailed,
          actionLabel: context.l10n.commonTryAgain,
          onAction: () => ref.invalidate(parkReviewQueueProvider),
        ),
      );
    } else {
      final value = queue.value!;
      body = value.count == 0
          ? Center(
              child: EmptyState(
                icon: Icons.fact_check_outlined,
                title: l10n.reviewEmpty,
                message: l10n.osmCredit,
              ),
            )
          : ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                14,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                for (final s in value.suggestions)
                  _SuggestionCard(
                    suggestion: s,
                    busy: _busy,
                    onMap: (point) => launcher.showOnMap(point),
                    onDecide: (approve) => _act(
                      () => repository.decide(s.id, approve: approve),
                    ),
                  ),
                for (final park in value.parks)
                  _VanishedCard(
                    park: park,
                    busy: _busy,
                    onMap: () => launcher.showOnMap(park.point),
                    onStatus: (status) =>
                        _act(() => repository.setParkStatus(park.id, status)),
                  ),
              ],
            );
    }

    return Scaffold(
      key: ParksReviewScreen.screenKey,
      body: Column(
        children: [
          CoralHeader(title: l10n.reviewTitle, showBack: true),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.busy,
    required this.onMap,
    required this.onDecide,
  });

  final ParkSuggestion suggestion;
  final bool busy;
  final ValueChanged<GeoPoint> onMap;
  final ValueChanged<bool> onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final s = suggestion;
    final park = s.park;
    final point = s.point ?? park?.point;
    final when = DateFormat('dd.MM.yy HH:mm').format(s.createdAt.toLocal());
    final city = localityName(s.localityCode, language);
    final lines = <String>[
      if (s.kind == SuggestionKind.newPark) ...[
        if (s.name != null) s.name!,
        if (s.location == SuggestedLocation.device) l10n.reviewFromPhone,
        if (s.location == SuggestedLocation.locality && city != null)
          l10n.reviewFromCity(city),
        if (s.placeNote != null) l10n.reviewPlace(s.placeNote!),
        for (final entry in s.changes.entries)
          l10n.detailAnswer(l10n.detail(entry.key), l10n.answer(entry.value)),
      ] else ...[
        if (park != null) l10n.parkFullName(park, language),
        for (final entry in s.changes.entries)
          l10n.reviewChange(
            l10n.detail(entry.key),
            l10n.answer(park?.answer(entry.key) ?? ParkAnswer.unknown),
            l10n.answer(entry.value),
          ),
        if (s.closed == true) l10n.reviewClosed,
        if (s.closed == false) l10n.reviewReopened,
      ],
    ];
    return _Card(
      children: [
        Row(
          children: [
            AppIcon(
              s.kind == SuggestionKind.newPark
                  ? Icons.add_location_alt_rounded
                  : Icons.edit_note_rounded,
              color: AppColors.coralDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.kind == SuggestionKind.newPark
                    ? l10n.reviewNewPark
                    : l10n.reviewDetails,
                style: AppText.cardTitle,
              ),
            ),
            Text(
              when,
              textDirection: TextDirection.ltr,
              style: AppText.secondary.copyWith(color: AppColors.brown),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: AppText.body),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: ParksReviewScreen.approveKey(s.id),
              onPressed: busy ? null : () => onDecide(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, kHealthTapTarget),
              ),
              child: Text(l10n.approve),
            ),
            OutlinedButton(
              key: ParksReviewScreen.rejectKey(s.id),
              onPressed: busy ? null : () => onDecide(false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, kHealthTapTarget),
              ),
              child: Text(l10n.reject),
            ),
            if (point != null)
              TextButton.icon(
                key: ParksReviewScreen.mapKey(s.id),
                onPressed: () => onMap(point),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, kHealthTapTarget),
                ),
                icon: const AppIcon(Icons.map_rounded, size: 20),
                label: Text(l10n.showOnMap),
              ),
          ],
        ),
      ],
    );
  }
}

class _VanishedCard extends StatelessWidget {
  const _VanishedCard({
    required this.park,
    required this.busy,
    required this.onMap,
    required this.onStatus,
  });

  final DogPark park;
  final bool busy;
  final VoidCallback onMap;
  final ValueChanged<ParkStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    return _Card(
      children: [
        Row(
          children: [
            const AppIcon(Icons.wrong_location_rounded, color: AppColors.coralDark),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.reviewVanished, style: AppText.cardTitle)),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.parkFullName(park, language), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(l10n.reviewVanishedBody, style: AppText.body.copyWith(color: AppColors.brown)),
        const SizedBox(height: 6),
        ParkTags(park),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (status, label) in [
              (ParkStatus.active, l10n.keepPark),
              (ParkStatus.closed, l10n.markClosed),
              (ParkStatus.removed, l10n.removePark),
            ])
              OutlinedButton(
                key: ParksReviewScreen.statusKey(park.id, status),
                onPressed: busy ? null : () => onStatus(status),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, kHealthTapTarget),
                ),
                child: Text(label),
              ),
            TextButton.icon(
              onPressed: onMap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, kHealthTapTarget),
              ),
              icon: const AppIcon(Icons.map_rounded, size: 20),
              label: Text(l10n.showOnMap),
            ),
          ],
        ),
      ],
    );
  }
}
