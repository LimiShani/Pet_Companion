import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../health_strings.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';

/// The basic health information of a pet as a ready-made form section:
/// microchip number, allergies and conditions, the last two each with a
/// "None known" tick box that counts as an answer.
///
/// It loads the pet's current values, validates, saves through Health and
/// then calls [onSaved]. It shows its own loading, error and saving states,
/// so it can sit in any page or step (the add-a-pet flow uses it too).
class HealthBasicsSection extends ConsumerStatefulWidget {
  const HealthBasicsSection({
    super.key,
    required this.petId,
    this.saveLabel,
    this.onSaved,
    this.withContactAndNotes = false,
  });

  final String petId;

  /// Text of the section's button: "Save" in the app's language unless
  /// given ("Finish" inside a flow).
  final String? saveLabel;
  final ValueChanged<HealthProfile>? onSaved;

  /// Also shows the emergency contact person and free notes (Health's own
  /// profile page).
  final bool withContactAndNotes;

  @override
  ConsumerState<HealthBasicsSection> createState() => _HealthBasicsSectionState();
}

class _HealthBasicsSectionState extends ConsumerState<HealthBasicsSection> {
  final _form = GlobalKey<FormState>();
  final _microchip = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _notes = TextEditingController();
  bool _notChipped = false;
  bool _noAllergies = false;
  bool _noConditions = false;
  bool _filled = false;
  bool _saving = false;

  /// What went wrong when saving; worded when it is shown, so it follows
  /// the language of the screen.
  Object? _error;

  @override
  void dispose() {
    for (final c in [_microchip, _allergies, _conditions, _contactName, _contactPhone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(HealthProfile profile) {
    if (_filled) return;
    _filled = true;
    _microchip.text = profile.microchip;
    _allergies.text = profile.allergies.join('\n');
    _conditions.text = profile.conditions.join('\n');
    _contactName.text = profile.contactName;
    _contactPhone.text = profile.contactPhone;
    _notes.text = profile.notes;
    _notChipped = profile.notChipped && profile.microchip.trim().isEmpty;
    _noAllergies = profile.allergiesNoneKnown && profile.allergies.isEmpty;
    _noConditions = profile.conditionsNoneKnown && profile.conditions.isEmpty;
  }

  static List<String> _lines(String text) => [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  Future<void> _save(HealthProfile current) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final allergies = _noAllergies ? const <String>[] : _lines(_allergies.text);
      final conditions = _noConditions ? const <String>[] : _lines(_conditions.text);
      final saved = await ref
          .read(healthProfileProvider(widget.petId).notifier)
          .save(
            current.copyWith(
              microchip: _notChipped ? '' : _microchip.text.trim(),
              notChipped: _notChipped,
              allergies: allergies,
              allergiesNoneKnown: _noAllergies,
              conditions: conditions,
              conditionsNoneKnown: _noConditions,
              contactName: widget.withContactAndNotes ? _contactName.text.trim() : null,
              contactPhone: widget.withContactAndNotes ? _contactPhone.text.trim() : null,
              notes: widget.withContactAndNotes ? _notes.text.trim() : null,
            ),
          );
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved?.call(saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(healthProfileProvider(widget.petId));
    final current = profile.value;
    final l10n = context.healthL10n;
    if (current == null) {
      return profile.hasError
          ? HealthLoadError(
              title: l10n.loadFailedProfile,
              error: profile.error!,
              onRetry: () => ref.invalidate(healthProfileProvider(widget.petId)),
            )
          : const HealthLoading();
    }
    _fill(current);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormLabel(l10n.identification),
          TextFormField(
            key: const Key('profile-microchip'),
            controller: _microchip,
            enabled: !_notChipped,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            // A number: left to right on every screen.
            textDirection: TextDirection.ltr,
            textAlign: context.isRtl ? TextAlign.end : TextAlign.start,
            decoration: InputDecoration(labelText: _notChipped ? l10n.notChipped : l10n.microchipNumberOptional),
            validator: (value) => (value?.trim().length ?? 0) > 40 ? l10n.validNumberTooLong(40) : null,
          ),
          _TickLine(
            checkKey: const Key('profile-not-chipped'),
            label: l10n.notChipped,
            value: _notChipped,
            onChanged: (value) => setState(() => _notChipped = value),
          ),
          FormLabel(l10n.allergies),
          _AnswerField(
            fieldKey: const Key('profile-allergies'),
            checkKey: const Key('profile-no-allergies'),
            controller: _allergies,
            label: l10n.knownAllergies,
            noneKnown: _noAllergies,
            onNoneKnown: (value) => setState(() => _noAllergies = value),
          ),
          FormLabel(l10n.medicalConditions),
          _AnswerField(
            fieldKey: const Key('profile-conditions'),
            checkKey: const Key('profile-no-conditions'),
            controller: _conditions,
            label: l10n.knownConditions,
            noneKnown: _noConditions,
            onNoneKnown: (value) => setState(() => _noConditions = value),
          ),
          if (widget.withContactAndNotes) ...[
            FormLabel(l10n.emergencyContactHeading),
            TextFormField(
              key: const Key('profile-contact-name'),
              controller: _contactName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.nameOptional),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('profile-contact-phone'),
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              // A phone number: left to right on every screen.
              textDirection: TextDirection.ltr,
              textAlign: context.isRtl ? TextAlign.end : TextAlign.start,
              decoration: InputDecoration(labelText: l10n.phoneOptional),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return null;
                final digits = v.replaceAll(RegExp('[^0-9]'), '');
                return digits.length < 5 || RegExp(r'[^0-9+()\-\s.]').hasMatch(v) ? l10n.validPhone : null;
              },
            ),
            FormLabel(l10n.anythingElseForVet),
            TextFormField(
              key: const Key('profile-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.notesOptional),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              healthErrorOf(context, _error),
              style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: widget.saveLabel ?? context.l10n.commonSave,
            loading: _saving,
            onPressed: () => _save(current),
          ),
        ],
      ),
    );
  }
}

/// A multi-line answer with a "None known" tick box beside it.
class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.fieldKey,
    required this.checkKey,
    required this.controller,
    required this.label,
    required this.noneKnown,
    required this.onNoneKnown,
  });

  final Key fieldKey;
  final Key checkKey;
  final TextEditingController controller;
  final String label;
  final bool noneKnown;
  final ValueChanged<bool> onNoneKnown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: fieldKey,
          controller: controller,
          enabled: !noneKnown,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: noneKnown ? l10n.noneKnown : label),
          validator: (value) => (value?.length ?? 0) > 600 ? l10n.validKeepShorter : null,
        ),
        _TickLine(checkKey: checkKey, label: l10n.noneKnown, value: noneKnown, onChanged: onNoneKnown),
      ],
    );
  }
}

/// A tick box with a label: an honest "nothing to enter" answer.
class _TickLine extends StatelessWidget {
  const _TickLine({required this.checkKey, required this.label, required this.value, required this.onChanged});

  final Key checkKey;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: checkKey,
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: AppText.body.copyWith(color: AppColors.ink)),
    );
  }
}

/// Health's own profile page: the basics plus the emergency contact
/// person and notes.
class HealthProfileScreen extends StatelessWidget {
  const HealthProfileScreen({super.key, required this.pet});

  final Pet pet;

  static Future<void> open(BuildContext context, Pet pet) =>
      pushHealthPage<void>(context, HealthProfileScreen(pet: pet));

  @override
  Widget build(BuildContext context) {
    return HealthPage(
      title: context.healthL10n.petsHealthProfile(pet.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthBasicsSection(
            petId: pet.id,
            withContactAndNotes: true,
            saveLabel: context.healthL10n.saveProfile,
            onSaved: (_) => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          FinePrint(context.healthL10n.profileFinePrint),
        ],
      ),
    );
  }
}

/// Opens [HealthProfileScreen] for [petId]; nothing opens for an unknown id.
Future<void> openHealthProfileById(BuildContext context, String petId) {
  for (final pet in ProviderScope.containerOf(context, listen: false).read(petsProvider)) {
    if (pet.id == petId) return HealthProfileScreen.open(context, pet);
  }
  assert(false, 'openHealthProfile: no pet with id "$petId" in petsProvider');
  return Future.value();
}
