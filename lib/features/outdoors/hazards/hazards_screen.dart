import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/feature_ui.dart' show AddTab;
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/outdoors/data/hazard_models.dart';
import '../../../services/outdoors/state/hazards_providers.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/add_sheet.dart' show AddFab;
import '../../../widgets/app_tag.dart';
import '../../../widgets/area_disc.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../outdoors_words.dart';
import 'hazard_line.dart';
import 'report_hazard_sheet.dart';

/// The hazard list, over the Outside tab (its bottom bar stays).
Future<void> openHazards(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const HazardsScreen()));

/// "Hazards near you": the current reports around Outside's area, newest
/// first, each with "Still there" / "Not there any more" (one's own: its
/// tag and Delete). No map and no author names.
class HazardsScreen extends ConsumerWidget {
  const HazardsScreen({super.key});

  static const screenKey = Key('hazards-screen');
  static const emptyKey = Key('hazards-empty');
  static Key cardKey(String id) => Key('hazard-card-$id');
  static Key stillKey(String id) => Key('hazard-still-$id');
  static Key goneKey(String id) => Key('hazard-gone-$id');
  static Key deleteKey(String id) => Key('hazard-delete-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: HazardCapabilities.view,
    builder: (context) => Consumer(builder: (context, ref, _) => _build(context, ref)),
  );

  Widget _build(BuildContext context, WidgetRef ref) {
    final l10n = context.outdoorsL10n;
    final reports = ref.watch(areaHazardsProvider);
    final now = ref.watch(hazardsClockProvider)();
    final canPost = ref.watch(capabilityProvider(HazardCapabilities.post));
    final plus = AddFab.available(ref, AddTab.outside);
    final shown = [
      for (final report in reports.value ?? const <HazardReport>[])
        if (report.expiresAt.isAfter(now) && (!report.hidden || report.mine)) report,
    ];

    return Scaffold(
      key: screenKey,
      floatingActionButton: plus
          ? AddFab(
              tab: AddTab.outside,
              title: l10n.addToOutside,
              petId: ref.watch(selectedPetProvider).id,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.hazardsTitle, showBack: true),
          Expanded(
            child: switch (reports) {
              AsyncValue(hasValue: true) => RefreshIndicator(
                onRefresh: () async {
                  ref.read(hazardsRevisionProvider.notifier).bump();
                  await ref.read(areaHazardsProvider.future);
                },
                child: ListView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screen,
                    14,
                    AppSpacing.screen,
                    (plus ? AppSpacing.fabClearance : 24) +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (shown.isEmpty)
                      EmptyState(
                        key: emptyKey,
                        icon: Icons.check_circle_outline_rounded,
                        title: l10n.hazardsEmpty,
                        message: '',
                        actionLabel: canPost ? l10n.addReportHazard : null,
                        onAction: canPost ? () => openReportHazard(context) : null,
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
                        child: Text(
                          l10n.hazardsLead,
                          style: AppText.secondary.copyWith(color: AppColors.brown),
                        ),
                      ),
                      for (final report in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                          child: HazardCard(report: report, now: now),
                        ),
                    ],
                  ],
                ),
              ),
              AsyncValue(hasError: true) => EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.hazardsLoadFailed,
                message: '',
                actionLabel: context.l10n.commonTryAgain,
                onAction: () => ref.invalidate(areaHazardsProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

/// One report: what, where, how long ago, the note, and the votes (or, on
/// one's own, Delete).
class HazardCard extends ConsumerStatefulWidget {
  const HazardCard({super.key, required this.report, required this.now});

  final HazardReport report;
  final DateTime now;

  @override
  ConsumerState<HazardCard> createState() => _HazardCardState();
}

class _HazardCardState extends ConsumerState<HazardCard> {
  var _busy = false;

  Future<void> _vote(bool gone) async {
    final l10n = context.outdoorsL10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final shown = await ref
          .read(hazardsControllerProvider.notifier)
          .vote(widget.report.id, gone: gone);
      if (!shown) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.hazardHidden)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.hazardFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = context.outdoorsL10n;
    final app = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.hazardDeleteTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(app.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(app.commonDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(hazardsControllerProvider.notifier).delete(widget.report.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.hazardFailed)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final report = widget.report;
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, kHealthTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );
    OutlinedButton vote(Key key, String label, bool gone) => OutlinedButton(
      key: key,
      onPressed: _busy ? null : () => _vote(gone),
      style: report.myVote == gone
          ? style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(AppColors.yellow),
              foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
              side: const WidgetStatePropertyAll(BorderSide(color: AppColors.yellow)),
            )
          : style,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    return Material(
      key: HazardsScreen.cardKey(report.id),
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AreaDisc(hazardIcon(report.kind), area: AppArea.community),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.hazardKind(report.kind),
                        style: AppText.cardTitle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${l10n.hazardPlace(report, language)} · '
                        '${l10n.hazardAge(context, report.createdAt, widget.now)}',
                        style: AppText.secondary.copyWith(color: AppColors.brown),
                      ),
                    ],
                  ),
                ),
                if (report.mine) ...[
                  const SizedBox(width: 8),
                  AppTag(l10n.hazardYours, tone: AppTagTone.peach),
                ],
              ],
            ),
            if (report.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                report.note,
                textDirection: directionOfText(
                  report.note,
                  fallback: Directionality.of(context),
                ),
                style: AppText.body.copyWith(color: AppColors.ink),
              ),
            ],
            const SizedBox(height: 10),
            if (report.mine)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  key: HazardsScreen.deleteKey(report.id),
                  onPressed: _busy ? null : _delete,
                  style: style,
                  child: Text(context.l10n.commonDelete),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  vote(HazardsScreen.stillKey(report.id), l10n.hazardStillThere, false),
                  vote(HazardsScreen.goneKey(report.id), l10n.hazardGone, true),
                ],
              ),
            if (report.stillCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.hazardStillCount(report.stillCount),
                style: AppText.secondary.copyWith(color: AppColors.brown),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
