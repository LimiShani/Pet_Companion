import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../platform/feature_ui.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/insights/insight_rules.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/area_disc.dart';

/// The insight's sentence in the screen's language.
String insightText(HealthPlanL10n l10n, HealthInsight insight, String pet) =>
    switch (insight.kind) {
      InsightKind.shorterWalks => l10n.insightShorterWalks(pet),
      InsightKind.weightUp => l10n.insightWeightUp(pet, insight.percent),
      InsightKind.weightDown => l10n.insightWeightDown(pet, insight.percent),
      InsightKind.appetiteLess => l10n.insightAppetiteLess(pet, insight.count),
    };

/// One line at the top of the Health Overview: a calm sentence about
/// [pet] from what the owner logged, and one link to where it comes from
/// (the activity page, the weight, the journal). At most one a week.
class HealthInsightLine extends ConsumerWidget {
  const HealthInsightLine({
    super.key,
    required this.pet,
    required this.insight,
  });

  static const lineKey = Key('overview-insight');
  static const linkKey = Key('overview-insight-link');

  final Pet pet;
  final HealthInsight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.healthPlanL10n;
    final activity = canOpenFeature(context, 'activity');
    void records(void Function(HistoryFilterController filter) show) {
      show(ref.read(historyFilterProvider.notifier));
      ref.read(healthSectionProvider.notifier).show(HealthSection.records);
    }

    final (String label, VoidCallback? open) = switch (insight.target) {
      InsightTarget.activity => (
        l10n.insightSeeWalks,
        activity ? () => openFeature<Object>(context, 'activity', pet.id) : null,
      ),
      InsightTarget.weight => (
        l10n.insightSeeWeight,
        () => records((f) => f.showWeight()),
      ),
      InsightTarget.journal => (
        l10n.insightSeeJournal,
        () => records((f) => f.showJournal()),
      ),
    };

    return HealthCard(
      key: lineKey,
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 8,
        top: 12,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AreaDisc(Icons.insights_rounded, area: AppArea.health),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightText(l10n, insight, pet.name),
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
                if (open != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HealthLink(
                      label,
                      key: linkKey,
                      onPressed: open,
                      padding: 0,
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
