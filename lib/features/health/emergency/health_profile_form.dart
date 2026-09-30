import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
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
    this.saveLabel = 'Save',
    this.onSaved,
    this.withContactAndNotes = false,
  });

  final String petId;

  /// Text of the section's button ("Save", or "Next" inside a flow).
  final String saveLabel;
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
  String? _error;

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
      final saved = await ref.read(healthProfileProvider(widget.petId).notifier).save(current.copyWith(
            microchip: _notChipped ? '' : _microchip.text.trim(),
            notChipped: _notChipped,
            allergies: allergies,
            allergiesNoneKnown: _noAllergies,
            conditions: conditions,
            conditionsNoneKnown: _noConditions,
            contactName: widget.withContactAndNotes ? _contactName.text.trim() : null,
            contactPhone: widget.withContactAndNotes ? _contactPhone.text.trim() : null,
            notes: widget.withContactAndNotes ? _notes.text.trim() : null,
          ));
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved?.call(saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = healthErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(healthProfileProvider(widget.petId));
    final current = profile.value;
    if (current == null) {
      return profile.hasError
          ? HealthLoadError(
              what: 'the health profile',
              message: healthErrorMessage(profile.error!),
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
          const FormLabel('Identification'),
          TextFormField(
            key: const Key('profile-microchip'),
            controller: _microchip,
            enabled: !_notChipped,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: _notChipped ? 'Not chipped' : 'Microchip number (optional)'),
            validator: (value) => (value?.trim().length ?? 0) > 40 ? 'Keep the number under 40 characters.' : null,
          ),
          _TickLine(
            checkKey: const Key('profile-not-chipped'),
            label: 'Not chipped',
            value: _notChipped,
            onChanged: (value) => setState(() => _notChipped = value),
          ),
          const FormLabel('Allergies'),
          _AnswerField(
            fieldKey: const Key('profile-allergies'),
            checkKey: const Key('profile-no-allergies'),
            controller: _allergies,
            label: 'Known allergies, one per line',
            noneKnown: _noAllergies,
            onNoneKnown: (value) => setState(() => _noAllergies = value),
          ),
          const FormLabel('Medical conditions'),
          _AnswerField(
            fieldKey: const Key('profile-conditions'),
            checkKey: const Key('profile-no-conditions'),
            controller: _conditions,
            label: 'Known conditions, one per line',
            noneKnown: _noConditions,
            onNoneKnown: (value) => setState(() => _noConditions = value),
          ),
          if (widget.withContactAndNotes) ...[
            const FormLabel('Emergency contact (someone who can help)'),
            TextFormField(
              key: const Key('profile-contact-name'),
              controller: _contactName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('profile-contact-phone'),
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return null;
                final digits = v.replaceAll(RegExp('[^0-9]'), '');
                return digits.length < 5 || RegExp(r'[^0-9+()\-\s.]').hasMatch(v)
                    ? 'That does not look like a phone number.'
                    : null;
              },
            ),
            const FormLabel('Anything else a vet should know'),
            TextFormField(
              key: const Key('profile-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 22),
          PrimaryButton(label: widget.saveLabel, loading: _saving, onPressed: () => _save(current)),
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
          decoration: InputDecoration(labelText: noneKnown ? 'None known' : label),
          validator: (value) => (value?.length ?? 0) > 600 ? 'Please keep this shorter.' : null,
        ),
        _TickLine(checkKey: checkKey, label: 'None known', value: noneKnown, onChanged: onNoneKnown),
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
      title: "${pet.name}'s health profile",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthBasicsSection(
            petId: pet.id,
            withContactAndNotes: true,
            saveLabel: 'Save profile',
            onSaved: (_) => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          const FinePrint('Everything here is optional. It fills the Emergency card and the message to the vet.'),
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
