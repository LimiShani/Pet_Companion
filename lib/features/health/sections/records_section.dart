import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/empty_state.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../insights/quick_log_sheet.dart';
import '../records/record_detail_screen.dart';
import '../records/record_form_screen.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/schedule_logic.dart';
import '../../../presentation/health_widgets.dart';
import '../widgets/weight_trend.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../issues/issue_page.dart';
import '../issues/issue_widgets.dart';

/// Everything on record, under one search field and one row of chips: the
/// timeline of visits, vaccinations, preventive treatments, procedures,
/// medicine, documents and notes (newest first, grouped by month), then
/// the weight over time and the journal of what the owner noticed. The
/// chip is [historyFilterProvider], so the Overview can open it on one.
class RecordsSection extends ConsumerStatefulWidget {
  const RecordsSection({
    super.key,
    required this.pet,
    required this.data,
    this.onShare,
  });

  final Pet pet;
  final PetHealthData data;

  /// Shares the pet's health summary; `null` leaves the button out.
  final VoidCallback? onShare;

  @override
  ConsumerState<RecordsSection> createState() => _RecordsSectionState();
}

class _RecordsSectionState extends ConsumerState<RecordsSection> {
  final _search = TextEditingController();

  /// The journal's category; every category when `null`.
  String? _category;

  /// The journal shows the whole Behaviour group.
  bool _behaviourOnly = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(historyFilterProvider).query;
  }

  @override
  void didUpdateWidget(RecordsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.id != widget.pet.id) {
      _category = null;
      _behaviourOnly = false;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    final filter = ref.watch(historyFilterProvider);
    // The filter is also changed from outside: the Overview's rows, or
    // another pet being selected.
    ref.listen(historyFilterProvider, (_, next) {
      if (next.query != _search.text) _search.text = next.query;
    });
    final controller = ref.read(historyFilterProvider.notifier);
    final l10n = context.healthL10n;
    final settings = SpeciesSettings.of(pet.species);

    final history = historyRecords(data.records);
    final timeline = filter.view == RecordsView.timeline;
    final weight = filter.view == RecordsView.weight;
    final journal = filter.view == RecordsView.journal;

    // Only kinds that exist in the history get a chip, in the species' order.
    final kinds = [
      for (final kind in settings.recordKinds)
        if (kind != RecordKind.document &&
            (history.any((r) => r.kind == kind) || filter.kind == kind))
          kind,
    ];
    // A chip per followed problem (3b): open ones, and ones resolved in
    // the last 90 days. Its chip shows the problem's entries instead.
    final issueChips = recordsIssues(
      ref.watch(issueDigestsProvider(pet.id)).value ?? const [],
      ref.watch(currentDayProvider),
    );
    final issueId = ref.watch(recordsIssueProvider);
    IssueDigest? issue;
    for (final d in issueChips) {
      if (d.issue.id == issueId) issue = d;
    }
    final noIssue = issue == null;
    void pick(VoidCallback show) {
      ref.read(recordsIssueProvider.notifier).clear();
      show();
    }

    final timelineAll =
        noIssue && timeline && filter.kind == null && !filter.documentsOnly;

    final List<Widget> body;
    final Widget header;
    if (issue != null) {
      header = _HeaderRow(
        count: l10n.issueEntryCount(issue.entries.length),
        onShare: widget.onShare,
      );
      body = [
        for (final entry in issue.entries.reversed) ...[
          IssueEntryCard(
            entry: entry,
            photos: issue.photosOf(entry.id),
            settings: settings,
            onTap: () => showQuickLog(context, pet, observation: entry),
          ),
          const SizedBox(height: 8),
        ],
        Center(
          child: HealthLink(
            l10n.issueOpenPage,
            key: const Key('records-issue-open'),
            icon: issueIcon,
            onPressed: () => IssuePage.open(context, pet, issue!.issue.id),
          ),
        ),
      ];
    } else if (weight) {
      final weights = weightEntries(data.observations);
      header = _HeaderRow(
        count: weights.isEmpty ? null : l10n.weighIns(weights.length),
        onShare: widget.onShare,
      );
      body = [
        _WeightCard(
          pet: pet,
          weights: weights,
          visits: [
            for (final r in history)
              if (r.kind == RecordKind.checkup) r.when,
          ],
          grams: settings.weightInGrams,
        ),
      ];
    } else if (journal) {
      final (journalHeader, journalBody) = _journal(
        context,
        filter,
        settings,
      );
      header = journalHeader;
      body = journalBody;
    } else {
      final files = <String, int>{};
      for (final d in data.documents) {
        files[d.recordId] = (files[d.recordId] ?? 0) + 1;
      }
      final shown = [
        for (final r in history)
          // The search also finds a record by what the screen calls its kind.
          if (filter.matches(
            r,
            hasFiles: files.containsKey(r.id),
            kindName: l10n.recordKind(r.kind),
          ))
            r,
      ];
      header = _HeaderRow(
        count: history.isEmpty
            ? null
            : filter.isEmpty
            ? l10n.recordsCount(history.length)
            : l10n.recordsShown(shown.length, history.length),
        onShare: widget.onShare,
      );
      body = [
        if (history.isEmpty)
          EmptyState(
            icon: Icons.history_rounded,
            title: l10n.historyEmpty,
            message: l10n.historyEmptyNote(pet.name),
            actionLabel: l10n.addARecord,
            onAction: () => openRecordForm(context, pet),
          )
        else if (shown.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: l10n.nothingMatches,
            message: l10n.nothingMatchesNote,
            actionLabel: l10n.showAllRecords,
            onAction: () {
              _search.clear();
              controller.clear();
            },
          )
        else
          ..._timeline(context, shown, files),
      ];
    }

    // Nothing to search for a pet with nothing on record, nor on the chart.
    final searchable =
        !weight && (history.isNotEmpty || data.observations.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (searchable) ...[
          TextField(
            key: const Key('history-search'),
            controller: _search,
            onChanged: controller.search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchRecords(pet.name),
              prefixIcon: const AppIcon(
                Icons.search_rounded,
                color: AppColors.brown,
              ),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        controller.search('');
                      },
                      tooltip: l10n.clearSearch,
                      icon: const AppIcon(Icons.close_rounded),
                      color: AppColors.brown,
                    ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SingleChildScrollView(
          key: const Key('records-chips'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                chipKey: const Key('filter-all'),
                label: l10n.filterAll,
                selected: timelineAll,
                onSelected: () => pick(controller.showAll),
              ),
              for (final kind in kinds)
                _FilterChip(
                  chipKey: ValueKey('filter-${kind.name}'),
                  label: l10n.recordKinds(kind),
                  selected: noIssue && timeline && filter.kind == kind,
                  onSelected: () => pick(() => controller.showKind(kind)),
                ),
              _FilterChip(
                chipKey: const Key('filter-documents'),
                label: l10n.documents,
                selected: noIssue && timeline && filter.documentsOnly,
                onSelected: () => pick(controller.showDocuments),
              ),
              _FilterChip(
                chipKey: const Key('filter-weight'),
                label: l10n.weight,
                selected: noIssue && weight,
                onSelected: () => pick(controller.showWeight),
              ),
              _FilterChip(
                chipKey: const Key('filter-journal'),
                label: l10n.recordsJournal,
                selected: noIssue && journal,
                onSelected: () => pick(controller.showJournal),
              ),
              for (final d in issueChips)
                _FilterChip(
                  chipKey: ValueKey('filter-issue-${d.issue.id}'),
                  label: d.issue.title,
                  selected: issue?.issue.id == d.issue.id,
                  onSelected: () =>
                      ref.read(recordsIssueProvider.notifier).show(d.issue.id),
                ),
            ],
          ),
        ),
        header,
        ...body,
      ],
    );
  }

  /// The journal: its count line with the Category menu chip, and the
  /// entries, newest first.
  (Widget, List<Widget>) _journal(
    BuildContext context,
    HistoryFilter filter,
    SpeciesSettings settings,
  ) {
    final pet = widget.pet;
    final l10n = context.healthL10n;
    final all = [...widget.data.observations]
      ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    if (all.isEmpty) {
      return (
        _HeaderRow(count: null, onShare: widget.onShare),
        [
          EmptyState(
            icon: Icons.insights_rounded,
            title: l10n.insightsEmpty,
            message: l10n.insightsEmptyNote(pet.name),
            actionLabel: l10n.openQuickLog,
            onAction: () => showQuickLog(context, pet),
          ),
        ],
      );
    }

    // A menu entry for every category that has an entry, in the species'
    // order.
    final present = {for (final o in all) o.category};
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
    final words = filter.query.trim().toLowerCase();
    bool searched(Observation o) {
      if (words.isEmpty) return true;
      final text = [
        o.note,
        l10n.quickLogCategory(settings.category(o.category)),
      ].join(' | ').toLowerCase();
      return words.split(RegExp(r'\s+')).every(text.contains);
    }

    final shown = [
      for (final o in all)
        if ((behaviourOnly
                ? isBehaviour(o.category)
                : selected == null || o.category == selected) &&
            searched(o))
          o,
    ];
    final narrowed = behaviourOnly || selected != null || words.isNotEmpty;

    final menu = _CategoryMenu(
      label: behaviourOnly
          ? l10n.quickLogGroup(QuickLogGroup.behaviour)
          : selected == null
          ? l10n.recordsCategory
          : l10n.quickLogCategory(settings.category(selected)),
      selected: behaviourOnly || selected != null,
      entries: [
        _CategoryEntry(
          const Key('journal-all'),
          l10n.filterAll,
          selected == null && !behaviourOnly,
          () => setState(() {
            _category = null;
            _behaviourOnly = false;
          }),
        ),
        // The whole Behaviour group at once, once there is an entry.
        if (hasBehaviour)
          _CategoryEntry(
            const Key('journal-behaviour-group'),
            l10n.quickLogGroup(QuickLogGroup.behaviour),
            behaviourOnly,
            () => setState(() {
              _category = null;
              _behaviourOnly = true;
            }),
          ),
        for (final c in categories)
          _CategoryEntry(
            ValueKey('journal-${c.key}'),
            l10n.quickLogCategory(c),
            selected == c.key,
            () => setState(() {
              _category = c.key;
              _behaviourOnly = false;
            }),
          ),
      ],
    );

    return (
      _HeaderRow(
        count: narrowed
            ? l10n.recordsEntriesShown(shown.length, all.length)
            : l10n.recordsEntries(all.length),
        onShare: widget.onShare,
        leading: menu,
      ),
      [
        if (shown.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: l10n.nothingMatches,
            message: l10n.nothingMatchesNote,
            actionLabel: l10n.filterAll,
            onAction: () {
              _search.clear();
              ref.read(historyFilterProvider.notifier).search('');
              setState(() {
                _category = null;
                _behaviourOnly = false;
              });
            },
          )
        else
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

  List<Widget> _timeline(
    BuildContext context,
    List<HealthRecord> records,
    Map<String, int> files,
  ) {
    final widgets = <Widget>[];
    DateTime? month;
    for (final record in records) {
      final when = record.when;
      if (month == null ||
          month.year != when.year ||
          month.month != when.month) {
        month = DateTime(when.year, when.month);
        widgets.add(
          Padding(
            padding: EdgeInsetsDirectional.only(
              top: widgets.isEmpty ? 0 : 10,
              bottom: 8,
              start: 2,
            ),
            child: Text(
              HealthFormat.of(context).month(month),
              style: AppText.label.copyWith(color: AppColors.brown),
            ),
          ),
        );
      }
      widgets
        ..add(
          _RecordCard(
            record: record,
            files: files[record.id] ?? 0,
            onTap: () => openRecordDetail(context, widget.pet, record),
          ),
        )
        ..add(const SizedBox(height: 8));
    }
    return widgets;
  }
}

/// The line under the chips: what is shown, then "Share" and the view's
/// own action. [leading] goes first (the journal's Category menu), at most
/// half the line, so the count keeps room on a small phone.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.count,
    required this.onShare,
    this.leading,
  });

  final String? count;
  final VoidCallback? onShare;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (leading != null) ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: leading,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: count == null
                ? const SizedBox(height: kHealthTapTarget)
                : Text(
                    count!,
                    key: const Key('history-count'),
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
          ),
          if (onShare != null)
            HealthLink(
              context.l10n.commonShare,
              key: const Key('records-share'),
              padding: 4,
              onPressed: onShare,
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

/// One entry of the journal's Category menu.
class _CategoryEntry {
  const _CategoryEntry(this.key, this.label, this.selected, this.onSelected);

  final Key key;
  final String label;
  final bool selected;
  final VoidCallback onSelected;
}

/// The journal's one filter: a chip that opens the list of categories. It
/// reads "Category" until one is chosen, then the category.
class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({
    required this.label,
    required this.selected,
    required this.entries,
  });

  static const chipKey = Key('journal-category');

  final String label;
  final bool selected;
  final List<_CategoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      key: chipKey,
      tooltip: context.healthL10n.recordsCategory,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      onSelected: (index) => entries[index].onSelected(),
      itemBuilder: (context) => [
        for (var i = 0; i < entries.length; i++)
          PopupMenuItem(
            key: entries[i].key,
            value: i,
            child: Text(
              entries[i].label,
              style: AppText.body.copyWith(
                color: AppColors.ink,
                fontWeight: entries[i].selected
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
      ],
      // Drawn as one of the chips; the menu takes the tap.
      child: IgnorePointer(
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const AppIcon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.ink,
              ),
            ],
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) {},
        ),
      ),
    );
  }
}

/// One record in the timeline.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.files,
    required this.onTap,
  });

  final HealthRecord record;
  final int files;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final line = format.dots([
      l10n.recordKind(record.kind),
      format.date(record.when),
      record.clinic,
    ]);
    final note = record.notes.trim().split('\n').first;
    final due = record.nextDueOn;
    final cost = record.costAmount;

    return HealthCard(
      key: ValueKey('record-${record.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconDisc(recordKindIcon(record.kind)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypedText(record.title, style: AppText.cardTitle),
                Text(
                  line,
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: TypedText(
                      note,
                      style: AppText.secondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (due != null || files > 0 || cost != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (due != null)
                          HealthTag(
                            l10n.nextDue(format.date(due)),
                            icon: Icons.event_repeat_rounded,
                          ),
                        if (cost != null)
                          Semantics(
                            label: l10n.costSemantics(
                              format.money(cost, record.costCurrency),
                            ),
                            excludeSemantics: true,
                            child: HealthTag(
                              format.money(cost, record.costCurrency),
                              key: ValueKey('cost-${record.id}'),
                            ),
                          ),
                        if (files > 0)
                          Semantics(
                            label: l10n.attachmentsCount(files),
                            excludeSemantics: true,
                            child: HealthTag(
                              '$files',
                              icon: Icons.attach_file_rounded,
                            ),
                          ),
                      ],
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

/// The weight over time, with the vet visits marked under the line, and
/// "Log weight".
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
  Widget build(BuildContext context) {
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
  Widget build(BuildContext context) {
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
  Widget build(BuildContext context) {
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
