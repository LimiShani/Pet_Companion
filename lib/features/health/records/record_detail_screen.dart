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
import '../health_strings.dart';
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

    final l10n = context.healthL10n;
    return HealthPage(
      petId: pet.id,
      title: l10n.record,
      actions: [
        if (current != null) CoralHeaderAction(icon: Icons.edit_rounded, tooltip: l10n.editRecord, onPressed: edit),
      ],
      child: current == null
          ? records.isLoading
                ? const HealthLoading()
                : records.hasError
                ? HealthLoadError(
                    title: l10n.loadFailedRecord,
                    error: records.error!,
                    onRetry: () => ref.invalidate(healthRecordsProvider(pet.id)),
                  )
                : EmptyState(icon: Icons.sticky_note_2_rounded, title: l10n.recordGone, message: l10n.recordGoneNote)
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
      if (context.mounted) showHealthSnack(context, context.healthL10n.fileAttached(file.name));
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  Future<void> _markDone(BuildContext context, WidgetRef ref) async {
    final now = ref.read(healthClockProvider)();
    try {
      await ref
          .read(healthRecordsProvider(pet.id).notifier)
          .setDone(record, record.scheduledAt.isAfter(now) ? now : record.scheduledAt);
      if (context.mounted) showHealthSnack(context, context.healthL10n.movedToHistory);
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final given = record.kind.hasNextDue || record.kind == RecordKind.medicine;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final inScheduleTag = Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: HealthTag(l10n.inTheSchedule, highlight: true),
    );
    final rows = <Widget>[
      if (record.isDone)
        LabeledValue(given ? l10n.dateGiven : l10n.fieldDate, format.dateTime(record.when))
      else
        LabeledValue(l10n.plannedFor, format.dateTime(record.scheduledAt), trailing: inScheduleTag),
      if (record.nextDueOn != null)
        LabeledValue(l10n.nextDueFromVet, format.date(record.nextDueOn!), trailing: inSchedule ? inScheduleTag : null),
      if (record.productName.isNotEmpty) LabeledValue(l10n.product, record.productName),
      if (record.clinic.isNotEmpty) LabeledValue(l10n.vetOrClinic, record.clinic),
      if (record.costAmount != null)
        LabeledValue(
          record.isDone ? l10n.cost : l10n.expectedCost,
          format.money(record.costAmount!, record.costCurrency),
          key: const Key('record-cost-row'),
        ),
      if (record.notes.isNotEmpty) LabeledValue(l10n.notes, record.notes),
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
                  TypedText(record.title, style: AppText.petName.copyWith(fontSize: 20)),
                  Text(
                    format.dots([l10n.recordKind(record.kind), pet.name]),
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
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
            label: Text(l10n.markAsDone),
          ),
        ],
        const SizedBox(height: 8),
        HealthSectionTitle(l10n.attachments, count: documents.isEmpty ? null : documents.length),
        if (documents.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Text(l10n.noAttachmentsNote, style: AppText.secondary.copyWith(color: AppColors.brown)),
          ),
        for (final document in documents)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: DocumentRow(document: document),
          ),
        OutlinedButton.icon(
          key: const Key('detail-attach'),
          onPressed: () => _attach(context, ref),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(l10n.addPhotoOrPdf),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('record-share'),
          onPressed: () => shareRecord(context, pet, record),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(l10n.shareThisRecord),
        ),
        const SizedBox(height: 12),
        FinePrint(l10n.deleteInsideEdit),
      ],
    );
  }
}
