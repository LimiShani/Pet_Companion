import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../insights/quick_log_sheet.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/schedule_logic.dart';
import '../../../presentation/health_widgets.dart';
import '../widgets/weight_trend.dart';

/// Weight over time with vet visits marked under the line, and the journal
/// of what the owner noticed. A record of observations, never a diagnosis.
class InsightsSection extends StatefulWidget {
  const InsightsSection({super.key, required this.pet, required this.data});

  final Pet pet;
  final PetHealthData data;

  @override
  State<InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends State<InsightsSection> {
  /// The journal's category filter; every category when `null`.
  String? _category;

  /// The journal shows the whole Behaviour group.
  bool _behaviourOnly = false;

  @override
  void didUpdateWidget(InsightsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.id != widget.pet.id) {
      _category = null;
      _behaviourOnly = false;
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final pet = widget.pet;
    final data = widget.data;
    final settings = SpeciesSettings.of(pet.species);
    final l10n = context.healthL10n;

    if (data.observations.isEmpty) {
      return EmptyState(
        icon: Icons.insights_rounded,
        title: l10n.insightsEmpty,
        message: l10n.insightsEmptyNote(pet.name),
        actionLabel: l10n.openQuickLog,
        onAction: () => showQuickLog(context, pet),
      );
    }

    final journal = [...data.observations]
      ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    // A chip for every category that has an entry, in the species' order.
    final present = {for (final o in journal) o.category};
    final categories = [
      for (final c in settings.quickLog)
        if (present.contains(c.key)) c,
      for (final key in present)
        if (!settings.quickLog.any((c) => c.key == key)) settings.category(key),
    ];
    bool isBehaviour(String key) =>
        settings.category(key).group == QuickLogGroup.behaviour;
    final hasBehaviour = present.any(isBehaviour);
    final behaviourOnly = _behaviourOnly && hasBehaviour;
    final selected = !behaviourOnly && present.contains(_category)
        ? _category
        : null;
    final shown = [
      for (final o in journal)
        if (behaviourOnly
            ? isBehaviour(o.category)
            : selected == null || o.category == selected)
          o,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeightCard(
          pet: pet,
          weights: weightEntries(data.observations),
          visits: [
            for (final r in historyRecords(data.records))
              if (r.kind == RecordKind.checkup) r.when,
          ],
          grams: settings.weightInGrams,
        ),
        const SizedBox(height: 16),
        HealthSectionTitle(l10n.observations, count: journal.length),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryChip(
                chipKey: const Key('journal-all'),
                label: l10n.filterAll,
                selected: selected == null && !behaviourOnly,
                onSelected: () => setState(() {
                  _category = null;
                  _behaviourOnly = false;
                }),
              ),
              // The whole Behaviour group at once, once there is an entry.
              if (hasBehaviour)
                _CategoryChip(
                  chipKey: const Key('journal-behaviour-group'),
                  label: l10n.quickLogGroup(QuickLogGroup.behaviour),
                  selected: behaviourOnly,
                  onSelected: () => setState(() {
                    _category = null;
                    _behaviourOnly = true;
                  }),
                ),
              for (final c in categories)
                _CategoryChip(
                  chipKey: ValueKey('journal-${c.key}'),
                  label: l10n.quickLogCategory(c),
                  selected: selected == c.key,
                  onSelected: () => setState(() {
                    _category = c.key;
                    _behaviourOnly = false;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final observation in shown) ...[
          _ObservationCard(
            observation: observation,
            category: settings.category(observation.category),
            grams: settings.weightInGrams,
            onTap: () => showQuickLog(context, pet, observation: observation),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        FinePrint(l10n.insightsFinePrint),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        key: chipKey,
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.pet,
    required this.weights,
    required this.visits,
    required this.grams,
  });

  final Pet pet;

  /// Oldest first.
  final List<Observation> weights;

  /// When the pet was at the vet, to mark under the line.
  final List<DateTime> visits;
  final bool grams;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final header = Row(
      children: [
        Expanded(child: Text(l10n.weight, style: AppText.cardTitle)),
        HealthLink(
          l10n.logWeight,
          key: const Key('log-weight'),
          icon: Icons.add_rounded,
          onPressed: () =>
              showQuickLog(context, pet, category: Observation.weightCategory),
        ),
      ],
    );
    const padding = EdgeInsetsDirectional.only(
      start: 16,
      end: 12,
      top: 6,
      bottom: 14,
    );

    if (weights.isEmpty) {
      return HealthCard(
        key: const Key('insights-weight'),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Text(
              l10n.noWeightYet,
              style: AppText.secondary.copyWith(color: AppColors.brown),
            ),
          ],
        ),
      );
    }

    final latest = weights.last;
    final first = weights.first;
    final previous = weights.length > 1 ? weights[weights.length - 2] : null;
    var highest = first.value!;
    var lowest = first.value!;
    for (final w in weights) {
      if (w.value! > highest) highest = w.value!;
      if (w.value! < lowest) lowest = w.value!;
    }
    // Only the visits inside the period the line covers are drawn.
    final marked = [
      for (final visit in visits)
        if (!visit.isBefore(first.observedAt) &&
            !visit.isAfter(latest.observedAt))
          visit,
    ];
    String plain(double kg) => format.weightNumber(kg, grams: grams);
    final summary = format.dots([
      if (previous != null)
        format.weightChangeSince(
          previous.value!,
          latest.value!,
          previous.observedAt,
          grams: grams,
        ),
      if (weights.length > 1) l10n.weightHighest(plain(highest)),
      if (weights.length > 1) l10n.weightLowest(plain(lowest)),
    ]);
    final small = AppText.label.copyWith(
      color: AppColors.brown,
      fontWeight: FontWeight.w600,
    );

    return HealthCard(
      key: const Key('insights-weight'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Text.rich(
            TextSpan(
              text: format.weightNumber(latest.value!, grams: grams),
              style: AppText.metric,
              children: [
                TextSpan(
                  text: ' ${format.weightUnit(grams: grams)}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text(
            format.dots([
              format.date(latest.observedAt),
              l10n.weighIns(weights.length),
            ]),
            style: AppText.secondary.copyWith(color: AppColors.brown),
          ),
          const SizedBox(height: 10),
          WeightTrendChart(
            points: [
              for (final w in weights) TrendPoint(w.observedAt, w.value!),
            ],
            events: marked,
            semanticsLabel: l10n.weightTrendSemantics(
              format.weight(first.value!, grams: grams),
              format.date(first.observedAt),
              format.weight(latest.value!, grams: grams),
              format.date(latest.observedAt),
            ),
          ),
          const SizedBox(height: 4),
          // The dates under the chart: the first on the left and the latest
          // on the right, as the line runs, in every language.
          _ChartDates(
            first: format.date(first.observedAt),
            latest: weights.length > 1 ? format.date(latest.observedAt) : '',
            legend: marked.isEmpty ? null : l10n.vetVisitMarker,
            style: small,
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              key: const Key('weight-summary'),
              style: AppText.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// The row under the weight chart: the first date, the legend of the vet
/// visits, and the latest date. The dates sit under the ends of the line,
/// which runs left to right in every language; the legend reads in the
/// language of the screen.
class _ChartDates extends StatelessWidget {
  const _ChartDates({
    required this.first,
    required this.latest,
    required this.legend,
    required this.style,
  });

  final String first;
  final String latest;
  final String? legend;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final screen = Directionality.of(context);
    final text = legend;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(child: Text(first, style: style)),
          if (text != null)
            Flexible(
              child: Directionality(
                textDirection: screen,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drawn, not typed: the app font has no diamond glyph.
                    Transform.rotate(
                      angle: 0.7853981633974483,
                      child: Container(width: 7, height: 7, color: style.color),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        text,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Text(latest, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// One entry of the journal.
class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.observation,
    required this.category,
    required this.grams,
    required this.onTap,
  });

  final Observation observation;
  final QuickLogCategory category;
  final bool grams;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final value = observation.value;
    final level = observation.level;
    final answer = observation.isWeight && value != null
        ? format.weight(value, grams: grams)
        : level == null
        ? l10n.noted
        : l10n.level(level);
    return HealthCard(
      key: ValueKey('observation-${observation.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconDisc(category.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.dots([l10n.quickLogCategory(category), answer]),
                  style: AppText.cardTitle,
                ),
                Text(
                  format.dots([
                    format.date(observation.observedAt),
                    observation.note,
                  ]),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
