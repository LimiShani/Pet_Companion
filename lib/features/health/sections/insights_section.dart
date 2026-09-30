import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../insights/quick_log_sheet.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';
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

  @override
  void didUpdateWidget(InsightsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.id != widget.pet.id) _category = null;
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final data = widget.data;
    final settings = SpeciesSettings.of(pet.species);

    if (data.observations.isEmpty) {
      return EmptyState(
        icon: Icons.insights_rounded,
        title: 'Nothing logged yet',
        message: 'Weight, appetite, energy and anything else you notice about ${pet.name} will build a picture here.',
        actionLabel: 'Open the Quick log',
        onAction: () => showQuickLog(context, pet),
      );
    }

    final journal = [...data.observations]..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    // A chip for every category that has an entry, in the species' order.
    final present = {for (final o in journal) o.category};
    final categories = [
      for (final c in settings.quickLog)
        if (present.contains(c.key)) c,
      for (final key in present)
        if (!settings.quickLog.any((c) => c.key == key)) settings.category(key),
    ];
    final selected = present.contains(_category) ? _category : null;
    final shown = [
      for (final o in journal)
        if (selected == null || o.category == selected) o,
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
        HealthSectionTitle('Observations', count: journal.length),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryChip(
                chipKey: const Key('journal-all'),
                label: 'All',
                selected: selected == null,
                onSelected: () => setState(() => _category = null),
              ),
              for (final c in categories)
                _CategoryChip(
                  chipKey: ValueKey('journal-${c.key}'),
                  label: c.label,
                  selected: selected == c.key,
                  onSelected: () => setState(() => _category = c.key),
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
        const FinePrint('What you noticed, in your own words. The app does not interpret it.'),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.chipKey, required this.label, required this.selected, required this.onSelected});

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
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
  const _WeightCard({required this.pet, required this.weights, required this.visits, required this.grams});

  final Pet pet;

  /// Oldest first.
  final List<Observation> weights;

  /// When the pet was at the vet, to mark under the line.
  final List<DateTime> visits;
  final bool grams;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        const Expanded(child: Text('Weight', style: AppText.cardTitle)),
        HealthLink(
          'Log weight',
          key: const Key('log-weight'),
          icon: Icons.add_rounded,
          onPressed: () => showQuickLog(context, pet, category: Observation.weightCategory),
        ),
      ],
    );
    const padding = EdgeInsetsDirectional.only(start: 16, end: 12, top: 6, bottom: 14);

    if (weights.isEmpty) {
      return HealthCard(
        key: const Key('insights-weight'),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Text('No weight logged yet.', style: AppText.secondary.copyWith(color: AppColors.brown)),
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
        if (!visit.isBefore(first.observedAt) && !visit.isAfter(latest.observedAt)) visit,
    ];
    final shown = formatWeight(latest.value!, grams: grams).split(' ');
    String plain(double kg) => formatWeight(kg, grams: grams).split(' ').first;
    final summary = [
      if (previous != null)
        '${formatWeightChange(previous.value!, latest.value!, grams: grams)} since ${formatDate(previous.observedAt)}',
      if (weights.length > 1) 'highest ${plain(highest)}',
      if (weights.length > 1) 'lowest ${plain(lowest)}',
    ].join(' · ');
    final small = AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600);

    return HealthCard(
      key: const Key('insights-weight'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Text.rich(
            TextSpan(
              text: shown.first,
              style: AppText.metric,
              children: [
                TextSpan(
                  text: ' ${shown.last}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text(
            '${formatDate(latest.observedAt)} · ${weights.length == 1 ? '1 weigh-in' : '${weights.length} weigh-ins'}',
            style: AppText.secondary.copyWith(color: AppColors.brown),
          ),
          const SizedBox(height: 10),
          WeightTrendChart(
            points: [for (final w in weights) TrendPoint(w.observedAt, w.value!)],
            events: marked,
            semanticsLabel:
                'Weight trend from ${formatWeight(first.value!, grams: grams)} on ${formatDate(first.observedAt)} '
                'to ${formatWeight(latest.value!, grams: grams)} on ${formatDate(latest.observedAt)}',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(formatDate(first.observedAt), style: small)),
              if (marked.isNotEmpty)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drawn, not typed: the app font has no diamond glyph.
                      Transform.rotate(
                        angle: 0.7853981633974483,
                        child: Container(width: 7, height: 7, color: small.color),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('vet visit', style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Text(
                  weights.length > 1 ? formatDate(latest.observedAt) : '',
                  style: small,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(summary, key: const Key('weight-summary'), style: AppText.secondary),
          ],
        ],
      ),
    );
  }
}

/// One entry of the journal.
class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.observation, required this.category, required this.grams, required this.onTap});

  final Observation observation;
  final QuickLogCategory category;
  final bool grams;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = observation.value;
    final answer = observation.isWeight && value != null
        ? formatWeight(value, grams: grams)
        : observation.level?.label ?? 'Noted';
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
                Text('${category.label} · $answer', style: AppText.cardTitle),
                Text(
                  [formatDate(observation.observedAt), if (observation.note.isNotEmpty) observation.note].join(' · '),
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
