import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/empty_state.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../records/record_detail_screen.dart';
import '../records/record_form_screen.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';

/// One timeline of everything that happened: visits, vaccinations,
/// preventive treatments, procedures, medicine, documents and notes, newest
/// first and grouped by month, with a search field and filter chips.
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({super.key, required this.pet, required this.data});

  final Pet pet;
  final PetHealthData data;

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(historyFilterProvider).query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final data = widget.data;
    final filter = ref.watch(historyFilterProvider);
    // The filter is also changed from outside: the Overview's shortcuts, or
    // another pet being selected.
    ref.listen(historyFilterProvider, (_, next) {
      if (next.query != _search.text) _search.text = next.query;
    });
    final controller = ref.read(historyFilterProvider.notifier);
    final l10n = context.healthL10n;

    final history = historyRecords(data.records);
    final files = <String, int>{};
    for (final d in data.documents) {
      files[d.recordId] = (files[d.recordId] ?? 0) + 1;
    }
    final shown = [
      for (final r in history)
        // The search also finds a record by what the screen calls its kind.
        if (filter.matches(r, hasFiles: files.containsKey(r.id), kindName: l10n.recordKind(r.kind))) r,
    ];

    if (history.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: l10n.historyEmpty,
        message: l10n.historyEmptyNote(pet.name),
        actionLabel: l10n.addARecord,
        onAction: () => openRecordForm(context, pet),
      );
    }

    // Only kinds that exist in the history get a chip, in the species' order.
    final kinds = [
      for (final kind in SpeciesSettings.of(pet.species).recordKinds)
        if (kind != RecordKind.document && (history.any((r) => r.kind == kind) || filter.kind == kind)) kind,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('history-search'),
          controller: _search,
          onChanged: controller.search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchRecords(pet.name),
            prefixIcon: const AppIcon(Icons.search_rounded, color: AppColors.brown),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                chipKey: const Key('filter-all'),
                label: l10n.filterAll,
                selected: filter.kind == null && !filter.documentsOnly,
                onSelected: controller.showAll,
              ),
              for (final kind in kinds)
                _FilterChip(
                  chipKey: ValueKey('filter-${kind.name}'),
                  label: l10n.recordKinds(kind),
                  selected: filter.kind == kind,
                  onSelected: () => controller.showKind(kind),
                ),
              _FilterChip(
                chipKey: const Key('filter-documents'),
                label: l10n.documents,
                selected: filter.documentsOnly,
                onSelected: controller.showDocuments,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                filter.isEmpty ? l10n.recordsCount(history.length) : l10n.recordsShown(shown.length, history.length),
                key: const Key('history-count'),
                style: AppText.secondary.copyWith(color: AppColors.brown),
              ),
            ),
            HealthLink(l10n.addRecord, icon: Icons.add_rounded, onPressed: () => openRecordForm(context, pet)),
          ],
        ),
        if (shown.isEmpty)
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
      ],
    );
  }

  List<Widget> _timeline(BuildContext context, List<HealthRecord> records, Map<String, int> files) {
    final widgets = <Widget>[];
    DateTime? month;
    for (final record in records) {
      final when = record.when;
      if (month == null || month.year != when.year || month.month != when.month) {
        month = DateTime(when.year, when.month);
        widgets.add(
          Padding(
            padding: EdgeInsetsDirectional.only(top: widgets.isEmpty ? 0 : 10, bottom: 8, start: 2),
            child: Text(HealthFormat.of(context).month(month), style: AppText.label.copyWith(color: AppColors.brown)),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.chipKey, required this.label, required this.selected, required this.onSelected});

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

/// One record in the timeline.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.files, required this.onTap});

  final HealthRecord record;
  final int files;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final line = format.dots([l10n.recordKind(record.kind), format.date(record.when), record.clinic]);
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
                Text(line, style: AppText.secondary.copyWith(color: AppColors.brown)),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: TypedText(note, style: AppText.secondary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (due != null || files > 0 || cost != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (due != null) HealthTag(l10n.nextDue(format.date(due)), icon: Icons.event_repeat_rounded),
                        if (cost != null)
                          Semantics(
                            label: l10n.costSemantics(format.money(cost, record.costCurrency)),
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
                            child: HealthTag('$files', icon: Icons.attach_file_rounded),
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
