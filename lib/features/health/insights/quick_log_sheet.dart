import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/primary_button.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../emergency/emergency_sheet.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/schedule_logic.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/data/issue_models.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../issues/issue_widgets.dart';

/// Opens the Quick log: pick a category suited to the species, pick a
/// simple answer (or type the weight), save. Notes are optional.
///
/// [category] preselects a category key (the weight, from "Log weight").
/// With [observation] the sheet edits or deletes an existing entry.
/// [issueId] puts a new entry into that followed problem (its page's "Add
/// an entry"). While the pet has an open problem the sheet offers "Part of
/// a problem", and an entry of a problem takes photos.
Future<void> showQuickLog(
  BuildContext context,
  Pet pet, {
  String? category,
  Observation? observation,
  String? issueId,
}) => showHealthSheet<void>(
  context,
  QuickLogSheet(
    pet: pet,
    category: category,
    observation: observation,
    issueId: issueId,
  ),
);

class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({
    super.key,
    required this.pet,
    this.category,
    this.observation,
    this.issueId,
  });

  final Pet pet;
  final String? category;
  final Observation? observation;
  final String? issueId;

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  final _weight = TextEditingController();
  final _note = TextEditingController();
  QuickLogCategory? _category;
  ObservationLevel? _level;
  late DateTime _at;
  bool _busy = false;

  /// The followed problem the entry belongs to, or `null`.
  String? _issueId;

  /// Photos chosen here, stored when the entry is saved.
  final _newPhotos = <PickedFile>[];

  /// Stored photos the owner removed here, deleted when the entry is saved.
  final _removedPhotos = <String>{};

  /// The entry as stored by a save whose photos did not all go through: a
  /// second save updates it instead of adding another one.
  Observation? _stored;

  /// What is wrong: a message of the sheet, or what saving threw (worded
  /// when it is shown).
  Object? _error;

  SpeciesSettings get _settings => SpeciesSettings.of(widget.pet.species);
  bool get _grams => _settings.weightInGrams;
  bool get _editing => widget.observation != null;
  String get _petId => widget.pet.id;
  DateTime get _now => ref.read(healthClockProvider)();

  @override
  void initState() {
    super.initState();
    final observation = widget.observation;
    _issueId = widget.issueId ?? observation?.issueId;
    _at = observation?.observedAt ?? _now;
    final key = observation?.category ?? widget.category;
    if (key != null) _category = _settings.category(key);
    if (observation != null) {
      _level = observation.level;
      _note.text = observation.note;
      final value = observation.value;
      if (value != null) {
        _weight.text = _grams
            ? formatNumber(value * 1000, decimals: 0)
            : formatNumber(value, decimals: 2);
      }
    }
    _weight.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isWeight => _category?.scale == QuickLogScale.weight;

  /// The typed weight in kilograms, or `null` while it is not a number.
  double? get _kilograms {
    final typed = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (typed == null || typed <= 0) return null;
    return _grams ? typed / 1000 : typed;
  }

  bool get _ready =>
      _category != null && (_isWeight ? _kilograms != null : _level != null);

  Future<void> _pickWhen() async {
    final now = _now;
    final day = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      currentDate: now,
      helpText: context.healthL10n.whenDidYouNotice,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
      helpText: context.healthL10n.fieldTime,
    );
    if (!mounted) return;
    final picked = atTime(day, time ?? TimeOfDay.fromDateTime(_at));
    setState(() => _at = picked.isAfter(now) ? now : picked);
  }

  Future<void> _save() async {
    final category = _category;
    if (category == null) return;
    final kilograms = _kilograms;
    if (_isWeight && (kilograms == null || kilograms > 500)) {
      setState(() => _error = context.healthL10n.validWeight);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var saved = await ref
          .read(observationsProvider(_petId).notifier)
          .save(
            Observation(
              id: _stored?.id ?? widget.observation?.id ?? '',
              petId: _petId,
              category: category.key,
              level: _isWeight ? null : _level,
              value: _isWeight ? kilograms : null,
              note: _note.text.trim(),
              observedAt: _at,
              issueId: _issueId,
            ),
          );
      _stored = saved;
      // Saving never clears a link: taking an entry out of its problem
      // is a step of its own.
      if (_issueId == null && saved.issueId != null) {
        saved = await ref
            .read(healthIssuesProvider(_petId).notifier)
            .link(saved, null);
      }
      if (!await _savePhotos(saved)) return;
      if (!mounted) return;
      Navigator.of(context).pop();
      showHealthSnack(
        context,
        _editing
            ? context.healthL10n.entryUpdated
            : context.healthL10n.savedToJournal,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  /// Stores the chosen photos and removes the removed ones. On a failure
  /// the sheet stays open with the reason; what went through is kept.
  Future<bool> _savePhotos(Observation saved) async {
    if (_issueId == null) return true;
    final photos = ref.read(entryPhotosProvider(_petId).notifier);
    try {
      for (final id in [..._removedPhotos]) {
        final photo = _storedPhotos.where((p) => p.id == id).firstOrNull;
        if (photo != null) await photos.remove(photo);
        _removedPhotos.remove(id);
      }
      while (_newPhotos.isNotEmpty) {
        await photos.add(saved.id, _newPhotos.first);
        if (mounted) setState(() => _newPhotos.removeAt(0));
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.healthL10n.issuePhotoNotSaved(
            HealthFormat.of(context).error(error),
          );
        });
      }
      return false;
    }
  }

  /// The stored photos of the entry being edited.
  List<HealthDocument> get _storedPhotos {
    final id = _stored?.id ?? widget.observation?.id;
    if (id == null) return const [];
    return [
      for (final p
          in ref.read(entryPhotosProvider(_petId)).value ??
              const <HealthDocument>[])
        if (p.observationId == id) p,
    ];
  }

  Future<void> _addPhoto() async {
    final file = await pickEntryPhoto(context);
    if (file != null && mounted) setState(() => _newPhotos.add(file));
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: context.healthL10n.deleteEntryTitle,
      message: context.healthL10n.deleteEntryMessage,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(observationsProvider(_petId).notifier)
          .delete(widget.observation!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  void _urgent() {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    showEmergencySheet(navigator.context, _petId);
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
    final category = _category;
    final now = ref.watch(healthClockProvider)();
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final error = _error;
    // The open problems, and the one the entry is in even once resolved.
    final digests = ref.watch(issueDigestsProvider(_petId)).value ?? const [];
    final choices = [
      for (final d in digests)
        if (d.issue.isOpen || d.issue.id == _issueId) d.issue,
    ];
    String? forTitle;
    for (final issue in choices) {
      if (issue.id == widget.issueId) forTitle = issue.title;
    }
    // Watched so the photos of the entry are at hand.
    ref.watch(entryPhotosProvider(_petId));
    Observation? lastWeight;
    if (_isWeight) {
      final weights = weightEntries(
        ref.watch(observationsProvider(_petId)).value ?? const [],
      );
      for (final w in weights) {
        if (w.id != widget.observation?.id) lastWeight = w;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          _editing ? l10n.editEntry : l10n.quickLogFor(pet.name),
          subtitle: _editing
              ? (category == null ? null : l10n.quickLogCategory(category))
              : forTitle != null
              ? l10n.issueFor(forTitle)
              : l10n.whatDidYouNotice,
        ),
        if (!_editing)
          // Two short groups. A species without behaviour categories keeps
          // the single list, with no heading.
          for (final group in QuickLogGroup.values)
            if (_settings.quickLogIn(group).isNotEmpty) ...[
              if (_settings.quickLogIn(QuickLogGroup.behaviour).isEmpty)
                const SizedBox(height: 12)
              else
                FormLabel(
                  l10n.quickLogGroup(group),
                  key: ValueKey('quick-group-${group.name}'),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in _settings.quickLogIn(group))
                    ChoiceChip(
                      key: ValueKey('quick-${c.key}'),
                      avatar: HealthIcon(
                        c.icon,
                        size: 18,
                        color: AppColors.ink,
                      ),
                      label: Text(l10n.quickLogCategory(c)),
                      selected: c.key == category?.key,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        if (_category?.key != c.key) _level = null;
                        _category = c;
                        _error = null;
                      }),
                    ),
                ],
              ),
            ],
        if (category != null) ...[
          if (_isWeight) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('quick-weight-field'),
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              // A number: left to right on every screen, its unit beside it.
              textDirection: TextDirection.ltr,
              textAlign: context.isRtl ? TextAlign.end : TextAlign.start,
              decoration: InputDecoration(
                labelText: _grams ? l10n.weightInGrams : l10n.weightInKilograms,
                suffixText: format.weightUnit(grams: _grams),
              ),
            ),
            if (lastWeight != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
                child: Text(
                  l10n.lastTimeWeight(
                    format.weight(lastWeight.value!, grams: _grams),
                    format.date(lastWeight.observedAt),
                  ),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ),
          ] else ...[
            FormLabel(l10n.quickLogCategory(category)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final level in category.levels)
                  ChoiceChip(
                    key: ValueKey('level-${level.dbValue}'),
                    label: Text(l10n.level(level)),
                    selected: level == _level,
                    onSelected: (_) => setState(() => _level = level),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PickerTile(
            key: const Key('quick-when'),
            icon: Icons.schedule_rounded,
            label: l10n.fieldWhen,
            value: format.relativeDayTime(_at, now),
            onTap: _pickWhen,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('quick-note'),
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.notesOptional),
          ),
          if (choices.isNotEmpty) ..._issuePart(context, choices),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error is String ? error : format.error(error),
            style: AppText.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _editing ? l10n.saveChanges : l10n.saveToJournal,
          loading: _busy,
          onPressed: _ready ? _save : null,
        ),
        if (_editing)
          Center(
            child: HealthLink(
              l10n.deleteThisEntry,
              key: const Key('quick-delete'),
              icon: Icons.delete_outline_rounded,
              onPressed: _busy ? null : _delete,
            ),
          ),
        Center(
          child: HealthLink(
            l10n.looksUrgent,
            key: const Key('quick-urgent'),
            icon: emergencyIcon,
            onPressed: _urgent,
          ),
        ),
        FinePrint(l10n.quickLogFinePrint),
      ],
    );
  }

  /// "Part of a problem" and, for an entry of a problem, its photos.
  List<Widget> _issuePart(BuildContext context, List<HealthIssue> choices) {
    final l10n = context.healthL10n;
    final stored = [
      for (final p in _storedPhotos)
        if (!_removedPhotos.contains(p.id)) p,
    ];
    final count = stored.length + _newPhotos.length;
    return [
      FormLabel(l10n.issuePartOf, key: const Key('quick-issue-label')),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            key: const Key('quick-issue-none'),
            label: Text(l10n.issueNone),
            selected: _issueId == null,
            onSelected: (_) => setState(() => _issueId = null),
          ),
          for (final issue in choices)
            ChoiceChip(
              key: ValueKey('quick-issue-${issue.id}'),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: TypedText(
                  issue.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              selected: _issueId == issue.id,
              onSelected: (_) => setState(() => _issueId = issue.id),
            ),
        ],
      ),
      if (_issueId != null) ...[
        FormLabel(
          l10n.issuePhotos(HealthIssue.maxPhotosPerEntry),
          key: const Key('quick-photos-label'),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final photo in stored)
              EntryPhotoThumb(
                key: ValueKey('quick-photo-${photo.id}'),
                photo: photo,
                onRemove: () => setState(() => _removedPhotos.add(photo.id)),
              ),
            for (final file in _newPhotos)
              EntryPhotoThumb(
                key: ObjectKey(file),
                bytes: file.bytes,
                onRemove: () => setState(() => _newPhotos.remove(file)),
              ),
            if (count < HealthIssue.maxPhotosPerEntry)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 14),
                child: Semantics(
                  button: true,
                  label: l10n.issueAddPhoto,
                  excludeSemantics: true,
                  child: Material(
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      key: const Key('quick-add-photo'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: _busy ? null : _addPhoto,
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: AppIcon(
                            Icons.add_a_photo_rounded,
                            color: AppColors.coralDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}
