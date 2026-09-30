import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../share/share_actions.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'attachments.dart';
import 'record_form_screen.dart';

/// Opens one record over the whole app.
Future<void> openRecordDetail(BuildContext context, Pet pet, HealthRecord record) =>
    pushHealthPage<void>(context, RecordDetailScreen(pet: pet, recordId: record.id));

/// Everything about one record: when, the next due date, the product, the
/// vet, the notes and the attached photos and PDFs. Edit (and, inside it,
/// delete) is behind the pencil.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.pet, required this.recordId});

  final Pet pet;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(healthRecordsProvider(pet.id));
    final documents = ref.watch(healthDocumentsProvider(pet.id));
    HealthRecord? record;
    for (final r in records.value ?? const <HealthRecord>[]) {
      if (r.id == recordId) record = r;
    }
    final current = record;

    Future<void> edit() async {
      final before = current;
      if (before == null) return;
      await openRecordForm(context, pet, record: before);
      if (!context.mounted) return;
      // Deleted in the form: there is nothing left to show here.
      final left = ref.read(healthRecordsProvider(pet.id)).value ?? const <HealthRecord>[];
      if (!left.any((r) => r.id == recordId)) Navigator.of(context).pop();
    }

    return HealthPage(
      petId: pet.id,
      title: 'Record',
      actions: [
        if (current != null) CoralHeaderAction(icon: Icons.edit_rounded, tooltip: 'Edit record', onPressed: edit),
      ],
      child: current == null
          ? records.isLoading
                ? const HealthLoading()
                : records.hasError
                ? HealthLoadError(
                    title: context.healthL10n.loadFailedRecord,
                    error: records.error!,
                    onRetry: () => ref.invalidate(healthRecordsProvider(pet.id)),
                  )
                : const EmptyState(
                    icon: Icons.sticky_note_2_rounded,
                    title: 'This record is gone',
                    message: 'It was deleted.',
                  )
          : _Detail(
              pet: pet,
              record: current,
              documents: [
                for (final d in documents.value ?? const <HealthDocument>[])
                  if (d.recordId == recordId) d,
              ],
              inSchedule: (records.value ?? const <HealthRecord>[]).any((r) => r.followUpOf == recordId && !r.isDone),
            ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.pet, required this.record, required this.documents, required this.inSchedule});

  final Pet pet;
  final HealthRecord record;
  final List<HealthDocument> documents;

  /// The record's next due date has an upcoming item in the Schedule.
  final bool inSchedule;

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final file = await pickAttachment(context);
    if (file == null) return;
    try {
      await ref.read(healthDocumentsProvider(pet.id).notifier).add(record.id, file);
      if (context.mounted) showHealthSnack(context, '${file.name} is attached.');
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  Future<void> _markDone(BuildContext context, WidgetRef ref) async {
    final now = ref.read(healthClockProvider)();
    try {
      await ref
          .read(healthRecordsProvider(pet.id).notifier)
          .setDone(record, record.scheduledAt.isAfter(now) ? now : record.scheduledAt);
      if (context.mounted) showHealthSnack(context, 'Moved to the History.');
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final given = record.kind.hasNextDue || record.kind == RecordKind.medicine;
    final rows = <Widget>[
      if (record.isDone)
        LabeledValue(given ? 'Date given' : 'Date', formatDateTime(record.when))
      else
        LabeledValue(
          'Planned for',
          formatDateTime(record.scheduledAt),
          trailing: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: HealthTag('In the Schedule', highlight: true),
          ),
        ),
      if (record.nextDueOn != null)
        LabeledValue(
          'Next due (from the vet)',
          formatDate(record.nextDueOn!),
          trailing: inSchedule
              ? const Padding(padding: EdgeInsets.only(top: 4), child: HealthTag('In the Schedule', highlight: true))
              : null,
        ),
      if (record.productName.isNotEmpty) LabeledValue('Product', record.productName),
      if (record.clinic.isNotEmpty) LabeledValue('Vet or clinic', record.clinic),
      if (record.costAmount != null)
        LabeledValue(
          record.isDone ? 'Cost' : 'Expected cost',
          formatMoney(record.costAmount!, record.costCurrency),
          key: const Key('record-cost-row'),
        ),
      if (record.notes.isNotEmpty) LabeledValue('Notes', record.notes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconDisc(recordKindIcon(record.kind), size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title, style: AppText.petName.copyWith(fontSize: 20)),
                  Text('${record.kind.label} · ${pet.name}', style: AppText.secondary.copyWith(color: AppColors.brown)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        HealthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1), rows[i]],
            ],
          ),
        ),
        if (!record.isDone) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('record-mark-done'),
            onPressed: () => _markDone(context, ref),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Mark as done'),
          ),
        ],
        const SizedBox(height: 8),
        HealthSectionTitle('Attachments', count: documents.isEmpty ? null : documents.length),
        if (documents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No photos or PDFs yet. A photo opens full screen; a PDF opens in the phone\'s viewer.',
              style: AppText.secondary.copyWith(color: AppColors.brown),
            ),
          ),
        for (final document in documents)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DocumentRow(document: document),
          ),
        OutlinedButton.icon(
          key: const Key('detail-attach'),
          onPressed: () => _attach(context, ref),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.attach_file_rounded),
          label: const Text('Add a photo or PDF'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('record-share'),
          onPressed: () => shareRecord(context, pet, record),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share this record'),
        ),
        const SizedBox(height: 12),
        const FinePrint('Delete is inside Edit, and always asks first.'),
      ],
    );
  }
}
