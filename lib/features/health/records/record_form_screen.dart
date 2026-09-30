import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../models/pet.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'attachments.dart';

/// Opens the add / edit record page over the whole app. Returns the saved
/// record, or `null` when the owner went back or deleted it.
///
/// [kind] preselects the kind of a new record. [planned] starts a new
/// record on tomorrow morning, which saves it as an upcoming item.
Future<HealthRecord?> openRecordForm(
  BuildContext context,
  Pet pet, {
  HealthRecord? record,
  RecordKind? kind,
  bool planned = false,
}) => pushHealthPage<HealthRecord>(context, RecordFormScreen(pet: pet, record: record, kind: kind, planned: planned));

/// One form for every kind of record; the fields follow the kind. Only the
/// title is required. A date that is still ahead saves the record as an
/// upcoming item in the Schedule; any other date puts it in the History.
class RecordFormScreen extends ConsumerStatefulWidget {
  const RecordFormScreen({super.key, required this.pet, this.record, this.kind, this.planned = false});

  final Pet pet;

  /// The record being edited, or `null` to add one.
  final HealthRecord? record;
  final RecordKind? kind;
  final bool planned;

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.record?.title ?? '');
  late final _product = TextEditingController(text: widget.record?.productName ?? '');
  late final _clinic = TextEditingController(text: widget.record?.clinic ?? '');
  late final _notes = TextEditingController(text: widget.record?.notes ?? '');
  late final _cost = TextEditingController(text: _costText(widget.record?.costAmount));
  late RecordKind _kind;
  late DateTime _day;
  late TimeOfDay _time;
  DateTime? _nextDue;
  final _pending = <PickedFile>[];
  final _previews = <PickedFile, Future<Uint8List>>{};
  bool _saving = false;
  String? _error;

  bool get _editing => widget.record != null;
  String get _petId => widget.pet.id;

  /// An existing record keeps its own currency; a new cost is in the app's.
  String get _currency => widget.record?.costCurrency ?? AppConfig.defaultCurrency;

  static String _costText(double? amount) => amount == null ? '' : formatNumber(amount, decimals: 2);
  DateTime get _now => ref.read(healthClockProvider)();
  DateTime get _at => atTime(_day, _time);
  bool get _ahead => _at.isAfter(_now);

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final now = _now;
    if (record != null) {
      _kind = record.kind;
      _day = dateOnly(record.when);
      _time = TimeOfDay.fromDateTime(record.when);
      _nextDue = record.nextDueOn;
    } else {
      _kind = widget.kind ?? SpeciesSettings.of(widget.pet.species).recordKinds.first;
      if (widget.planned) {
        _day = dateOnly(now).add(const Duration(days: 1));
        _time = const TimeOfDay(hour: 9, minute: 0);
      } else {
        _day = dateOnly(now);
        _time = TimeOfDay.fromDateTime(now);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _product, _clinic, _notes, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = _now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 10, 12, 31),
      currentDate: now,
      helpText: 'Date',
    );
    if (picked != null && mounted) setState(() => _day = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time, helpText: 'Time');
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _pickNextDue() async {
    final now = _now;
    final first = _day.add(const Duration(days: 1));
    final current = _nextDue;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first) ? current : first,
      firstDate: first,
      lastDate: DateTime(now.year + 20, 12, 31),
      currentDate: now,
      helpText: 'Next due date, from your vet',
    );
    if (picked != null && mounted) setState(() => _nextDue = dateOnly(picked));
  }

  Future<void> _attach() async {
    final file = await pickAttachment(context);
    if (file == null || !mounted) return;
    final record = widget.record;
    if (record == null) {
      setState(() => _pending.add(file));
      return;
    }
    try {
      await ref.read(healthDocumentsProvider(_petId).notifier).add(record.id, file);
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  Future<void> _removeDocument(HealthDocument document) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Remove this file?',
      message: '"${document.fileName}" will be removed from the record.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(healthDocumentsProvider(_petId).notifier).remove(document);
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ahead = _ahead;
    final nextDue = _kind.hasNextDue && !ahead ? _nextDue : null;
    if (nextDue != null && !nextDue.isAfter(_day)) {
      setState(() => _error = 'The next due date should be after the date given.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final at = _at;
    try {
      final saved = await ref
          .read(healthRecordsProvider(_petId).notifier)
          .save(
            HealthRecord(
              id: widget.record?.id ?? '',
              petId: _petId,
              kind: _kind,
              title: _title.text.trim(),
              notes: _notes.text.trim(),
              scheduledAt: at,
              doneAt: ahead ? null : at,
              clinic: _clinic.text.trim(),
              productName: _kind.hasProduct ? _product.text.trim() : '',
              nextDueOn: nextDue,
              followUpOf: widget.record?.followUpOf,
              costAmount: _cost.text.trim().isEmpty ? null : parseMoney(_cost.text),
              costCurrency: _currency,
            ),
          );
      String? fileProblem;
      for (final file in _pending) {
        try {
          await ref.read(healthDocumentsProvider(_petId).notifier).add(saved.id, file);
        } catch (error) {
          fileProblem = healthErrorMessage(error);
        }
      }
      if (!mounted) return;
      if (fileProblem != null) {
        showHealthSnack(context, 'The record is saved, but a file was not attached. $fileProblem');
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final record = widget.record!;
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this record?',
      message: '"${record.title}" and its attachments will be removed. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(healthRecordsProvider(_petId).notifier).delete(record);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final kinds = SpeciesSettings.of(widget.pet.species).recordKinds;
    final ahead = _ahead;
    final documents = record == null
        ? const <HealthDocument>[]
        : [
            for (final d in ref.watch(healthDocumentsProvider(_petId)).value ?? const <HealthDocument>[])
              if (d.recordId == record.id) d,
          ];
    final given = _kind.hasNextDue || _kind == RecordKind.medicine;

    return HealthPage(
      petId: _petId,
      title: _editing
          ? 'Edit record'
          : widget.planned
          ? 'New appointment'
          : 'New record',
      actions: [
        if (_editing)
          CoralHeaderAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete record',
            onPressed: _saving ? null : _delete,
          ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormLabel('What kind of record?'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in kinds)
                  ChoiceChip(
                    key: ValueKey('kind-${kind.name}'),
                    label: Text(kind.label),
                    selected: kind == _kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const FormLabel('Details'),
            TextFormField(
              key: const Key('record-title'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Give the record a title.';
                if (v.length > 120) return 'Keep the title under 120 characters.';
                return null;
              },
            ),
            if (_kind.hasProduct) ...[
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('record-product'),
                controller: _product,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Product (optional)'),
              ),
            ],
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('record-date'),
              icon: Icons.event_rounded,
              label: ahead
                  ? 'Planned for'
                  : given
                  ? 'Date given'
                  : 'Date',
              value: formatDate(_day),
              onTap: _pickDay,
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('record-time'),
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: formatTimeOfDay(_time),
              onTap: _pickTime,
            ),
            if (ahead) ...[
              const SizedBox(height: 6),
              const FinePrint(
                'This date is still ahead, so it is saved as an upcoming item in the Schedule.',
                center: false,
              ),
            ],
            if (_kind.hasNextDue && !ahead) ...[
              const SizedBox(height: 10),
              PickerTile(
                key: const Key('record-next-due'),
                icon: Icons.event_repeat_rounded,
                label: 'Next due (optional)',
                value: _nextDue == null ? 'Not set' : formatDate(_nextDue!),
                placeholder: _nextDue == null,
                onTap: _pickNextDue,
                onClear: _nextDue == null ? null : () => setState(() => _nextDue = null),
              ),
              const SizedBox(height: 6),
              const FinePrint('Enter the date your vet gave you. It will appear in the Schedule.', center: false),
            ],
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('record-clinic'),
              controller: _clinic,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Vet or clinic (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('record-cost'),
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: ahead ? 'Expected cost (optional)' : 'Cost (optional)',
                prefixText: '${currencySymbol(_currency)} ',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return null;
                return parseMoney(v) == null ? 'Enter an amount, like 120 or 89.90.' : null;
              },
            ),
            const SizedBox(height: 6),
            FinePrint(
              ahead
                  ? 'What you expect to pay. It stays with your records and is left out of anything you share with a vet.'
                  : 'What you paid. It stays with your records and is left out of anything you share with a vet.',
              center: false,
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('record-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Anything worth remembering'),
              validator: (value) => (value?.length ?? 0) > 4000 ? 'Please keep the notes shorter.' : null,
            ),
            const FormLabel('Attachments'),
            for (final document in documents)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DocumentRow(document: document, onRemove: () => _removeDocument(document)),
              ),
            for (final file in _pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AttachmentRow(
                  name: file.name,
                  sizeBytes: file.bytes.length,
                  isPdf: file.mimeType == 'application/pdf',
                  bytes: _previews.putIfAbsent(file, () => Future.value(file.bytes)),
                  onRemove: () => setState(() => _pending.remove(file)),
                ),
              ),
            OutlinedButton.icon(
              key: const Key('record-attach'),
              onPressed: _saving ? null : _attach,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Add a photo or PDF'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: 'Save record', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
