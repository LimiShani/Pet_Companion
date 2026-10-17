import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/data/file_services.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/plans/plan_calendar.dart';
import '../../../services/pet_records/plans/plan_logic.dart';
import '../../../services/pet_records/plans/plan_providers.dart';
import '../../../services/pet_records/plans/plan_templates.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/area_disc.dart';
import '../../../widgets/primary_button.dart';

/// Opens [pet]'s yearly plan: the owner ticks items, sees each first date
/// and why, adds them to the Schedule, and may share the dates to their
/// own calendar.
Future<void> showYearlyPlan(BuildContext context, Pet pet) =>
    showHealthSheet<void>(context, YearlyPlanSheet(pet: pet));

/// The icon of a plan item.
IconData planItemIcon(PlanTemplateItem item) =>
    item.kind == RecordKind.vaccination
    ? Icons.vaccines_rounded
    : Icons.shield_rounded;

/// The sheet of [pet]'s yearly plan.
class YearlyPlanSheet extends ConsumerStatefulWidget {
  const YearlyPlanSheet({super.key, required this.pet});

  static const sheetKey = Key('yearly-plan-sheet');
  static const addKey = Key('yearly-plan-add');
  static const sourcesKey = Key('yearly-plan-sources');
  static const addedKey = Key('yearly-plan-added');
  static const calendarKey = Key('yearly-plan-calendar');
  static const doneKey = Key('yearly-plan-done');
  static Key itemKey(String key) => ValueKey('yearly-plan-item-$key');
  static Key monthsKey(String key, int months) =>
      ValueKey('yearly-plan-months-$key-$months');

  final Pet pet;

  @override
  ConsumerState<YearlyPlanSheet> createState() => _YearlyPlanSheetState();
}

class _YearlyPlanSheetState extends ConsumerState<YearlyPlanSheet> {
  /// Items the owner unticked (everything not yet planned starts ticked).
  final _unticked = <String>{};

  /// The interval the owner picked, for the items that have a choice.
  final _months = <String, int>{};

  /// The records added, once the owner confirmed.
  List<HealthRecord>? _added;
  bool _saving = false;

  List<PlanProposal> _shown(List<PlanProposal> plan, DateTime today) => [
    for (final p in plan)
      _months[p.item.key] == null
          ? p
          : p.withMonths(_months[p.item.key]!, today: today),
  ];

  bool _ticked(PlanProposal p) =>
      p.planned == null && !_unticked.contains(p.item.key);

  Future<void> _add(List<PlanProposal> chosen) async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(yearlyPlanServiceProvider)
          .apply(widget.pet.id, chosen);
      if (!mounted) return;
      setState(
        () => _added = saved
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
      );
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final added = _added;
    return KeyedSubtree(
      key: YearlyPlanSheet.sheetKey,
      child: added != null
          ? _Added(pet: widget.pet, records: added)
          : _buildPicker(context),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final l10n = context.healthPlanL10n;
    final pet = widget.pet;
    final today = ref.watch(currentDayProvider);
    final value = ref.watch(yearlyPlanProvider(pet.id));
    final canAdd = ref.watch(capabilityProvider('health.records.edit'));
    final title = SheetTitle(
      l10n.planTitle(pet.name),
      subtitle: switch (pet.species) {
        PetSpecies.dog => l10n.planIntroDog,
        PetSpecies.cat => l10n.planIntroCat,
        _ => null,
      },
    );
    if (!hasYearlyPlan(pet)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 16),
          Text(l10n.planNoPlan, style: AppText.body),
        ],
      );
    }
    if (value.hasError && !value.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 16),
          Text(healthErrorOf(context, value.error), style: AppText.body),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: HealthLink(
              context.l10n.commonTryAgain,
              onPressed: () => ref.invalidate(healthRecordsProvider(pet.id)),
            ),
          ),
        ],
      );
    }
    final plan = value.value;
    if (plan == null) {
      return Column(
        children: [
          title,
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }
    final shown = _shown(plan, today);
    final chosen = [
      for (final p in shown)
        if (_ticked(p)) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: 12),
        HealthCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ItemRow(
                  proposal: shown[i],
                  pet: pet,
                  today: today,
                  ticked: _ticked(shown[i]),
                  onTicked: (on) => setState(() {
                    on
                        ? _unticked.remove(shown[i].item.key)
                        : _unticked.add(shown[i].item.key);
                  }),
                  months: _months[shown[i].item.key],
                  onMonths: (m) =>
                      setState(() => _months[shown[i].item.key] = m),
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: HealthLink(
            l10n.planSources,
            key: YearlyPlanSheet.sourcesKey,
            padding: 4,
            onPressed: () => showHealthSheet<void>(
              context,
              _Sources(pet: pet, items: [for (final p in plan) p.item]),
            ),
          ),
        ),
        FinePrint(l10n.planFinePrint, center: false),
        const SizedBox(height: 12),
        PrimaryButton(
          key: YearlyPlanSheet.addKey,
          label: l10n.planAddDates(chosen.length),
          loading: _saving,
          onPressed: chosen.isEmpty || !canAdd || _saving
              ? null
              : () => _add(chosen),
        ),
      ],
    );
  }
}

/// The words of where an item's first date comes from.
String planBasisText(
  HealthPlanL10n l10n,
  HealthFormat format,
  PlanProposal p,
) {
  String date(DateTime d) => format.date(d);
  final last = p.lastDone;
  return switch (p.basis) {
    PlanBasis.alreadyPlanned => l10n.planAlreadyPlanned(date(p.due)),
    PlanBasis.lastDone => l10n.planLastTime(date(last!.when)),
    PlanBasis.overdue => l10n.planOverdue(date(last!.when)),
    PlanBasis.noHistory => l10n.planNoHistory,
    PlanBasis.tooYoung =>
      p.item.startAgeWeeks >= 12 && p.item.startAgeWeeks % 4 == 0
          ? l10n.planFromMonths(p.item.startAgeWeeks ~/ 4)
          : l10n.planFromWeeks(p.item.startAgeWeeks),
    PlanBasis.series => () {
      final ages = p.item.series!.ageWeeks.skip(p.ref.dose ?? 0).toList();
      return switch (ages.length) {
        0 => l10n.planSeriesLast,
        1 => l10n.planSeriesOne(ages[0]),
        _ => l10n.planSeriesTwo(ages[0], ages[1]),
      };
    }(),
  };
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.proposal,
    required this.pet,
    required this.today,
    required this.ticked,
    required this.onTicked,
    required this.months,
    required this.onMonths,
  });

  final PlanProposal proposal;
  final Pet pet;
  final DateTime today;
  final bool ticked;
  final ValueChanged<bool> onTicked;
  final int? months;
  final ValueChanged<int> onMonths;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthPlanL10n;
    final format = HealthFormat.of(context);
    final hebrew = context.isRtl;
    final p = proposal;
    final item = p.item;
    final planned = p.planned != null;
    final tag = switch (item.standing) {
      PlanStanding.requiredByLaw => l10n.planRequired,
      PlanStanding.recommended => l10n.planRecommended,
      PlanStanding.common => null,
    };
    final secondary = AppText.secondary.copyWith(color: AppColors.brown);
    return InkWell(
      key: YearlyPlanSheet.itemKey(item.key),
      onTap: planned ? null : () => onTicked(!ticked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Checkbox(
                value: planned || ticked,
                onChanged: planned ? null : (on) => onTicked(on ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        p.title(hebrew: hebrew),
                        style: AppText.cardTitle.copyWith(
                          color: planned ? AppColors.brown : AppColors.ink,
                        ),
                      ),
                      if (tag != null) HealthTag(tag),
                    ],
                  ),
                  if (!planned)
                    Text(
                      isSameDay(p.due, today)
                          ? l10n.planFirstDateToday
                          : l10n.planFirstDate(format.date(p.due)),
                      style: AppText.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  Text(planBasisText(l10n, format, p), style: secondary),
                  if (!planned)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.why.of(hebrew: hebrew), style: secondary),
                    ),
                  if (!planned && item.monthChoices.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in item.monthChoices)
                            ChoiceChip(
                              key: YearlyPlanSheet.monthsKey(item.key, m),
                              label: Text(l10n.planEveryMonths(m)),
                              selected:
                                  (months ?? p.ref.months ?? item.monthChoices.first) == m,
                              onSelected: (_) => onMonths(m),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// After the owner confirmed: the dates added, and "Add to my calendar".
class _Added extends ConsumerWidget {
  const _Added({required this.pet, required this.records});

  final Pet pet;
  final List<HealthRecord> records;

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final l10n = context.healthPlanL10n;
    final text = planCalendar(
      records,
      summary: (r) => stripBidiMarks('${r.title} · ${pet.name}'),
      description: stripBidiMarks(l10n.planFromPlan(pet.name)),
      stamp: DateTime.now().toUtc(),
    );
    final shared = await ref
        .read(fileSharerProvider)
        .share(
          SharedFile(
            name: 'petloop-yearly-plan.ics',
            mimeType: 'text/calendar',
            bytes: utf8.encode(text),
            subject: stripBidiMarks(l10n.planTitle(pet.name)),
          ),
        );
    if (!shared && context.mounted) {
      showHealthSnack(context, context.healthL10n.couldNotOpenShareSheet);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.healthPlanL10n;
    final format = HealthFormat.of(context);
    final today = ref.watch(currentDayProvider);
    return Column(
      key: YearlyPlanSheet.addedKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: AreaDisc(Icons.check_rounded, area: AppArea.health, size: 64),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.planAdded(pet.name),
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.planAddedNote(records.length),
          style: AppText.secondary.copyWith(color: AppColors.brown),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        HealthCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < records.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Expanded(
                        child: TypedText(
                          records[i].title,
                          style: AppText.body.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        format.relativeDay(records[i].scheduledAt, today),
                        style: AppText.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: YearlyPlanSheet.calendarKey,
          onPressed: records.isEmpty ? null : () => _share(context, ref),
          icon: const Icon(Icons.event_rounded),
          label: Text(l10n.planAddToCalendar),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: YearlyPlanSheet.doneKey,
          onPressed: () => Navigator.of(context).maybePop(),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: Text(l10n.planDone),
        ),
        const SizedBox(height: 6),
        FinePrint(l10n.planCalendarNote),
      ],
    );
  }
}

/// "Where this comes from": the sources of the plan's items.
class _Sources extends StatelessWidget {
  const _Sources({required this.pet, required this.items});

  final Pet pet;
  final List<PlanTemplateItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthPlanL10n;
    final sources = <String, PlanSource>{
      for (final item in items)
        for (final s in item.sources) s.title: s,
    }.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(l10n.planSources, subtitle: l10n.planSourcesIntro(pet.name)),
        const SizedBox(height: 12),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sources.length; i++) ...[
                if (i > 0) const Divider(height: 17),
                // Titles of publications, in the language they were written.
                Text(
                  sources[i].title,
                  textDirection: TextDirection.ltr,
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
                if (sources[i].url != null)
                  Text(
                    sources[i].url!,
                    textDirection: TextDirection.ltr,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: Text(context.l10n.commonBack),
        ),
      ],
    );
  }
}
