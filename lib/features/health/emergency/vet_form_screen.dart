import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';

/// Opens the add / edit vet page over the whole app.
///
/// With [petId] and [role], a new vet is linked to that pet when saved.
/// Returns the saved vet, or `null` when the owner went back or deleted it.
Future<Vet?> openVetForm(BuildContext context, {String? petId, VetRole? role, Vet? vet}) =>
    pushHealthPage<Vet>(context, VetFormScreen(petId: petId, role: role, vet: vet));

class VetFormScreen extends ConsumerStatefulWidget {
  const VetFormScreen({super.key, this.petId, this.role, this.vet});

  final String? petId;
  final VetRole? role;

  /// The vet being edited, or `null` to add one.
  final Vet? vet;

  @override
  ConsumerState<VetFormScreen> createState() => _VetFormScreenState();
}

class _VetFormScreenState extends ConsumerState<VetFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.vet?.name ?? '');
  late final _phone = TextEditingController(text: widget.vet?.phone ?? '');
  late final _address = TextEditingController(text: widget.vet?.address ?? '');
  late final _hours = TextEditingController(text: widget.vet?.openingHours ?? '');
  late final _notes = TextEditingController(text: widget.vet?.notes ?? '');
  late bool _whatsApp = widget.vet?.onWhatsApp ?? false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.vet != null;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _hours, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return _whatsApp ? 'Enter the number that is on WhatsApp.' : null;
    final digits = v.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length < 5 || RegExp(r'[^0-9+()\-\s.]').hasMatch(v)) return 'That does not look like a phone number.';
    if (_whatsApp && !v.startsWith('+')) return 'For WhatsApp, start with the country code, like +972.';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(vetsProvider.notifier)
          .save(
            Vet(
              id: widget.vet?.id ?? '',
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              onWhatsApp: _whatsApp && _phone.text.trim().isNotEmpty,
              address: _address.text.trim(),
              openingHours: _hours.text.trim(),
              notes: _notes.text.trim(),
            ),
          );
      final petId = widget.petId;
      final role = widget.role;
      if (!_editing && petId != null && role != null) {
        await ref.read(healthProfileProvider(petId).notifier).setVet(role, saved.id);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = healthErrorMessage(e);
        });
      }
    }
  }

  Future<void> _delete() async {
    final vet = widget.vet!;
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this vet?',
      message: '"${vet.name}" will be removed from your account and from every pet that uses it.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(vetsProvider.notifier).delete(vet.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = healthErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the owner's vets (and the pet's profile) alive while the form
    // is open, wherever it was opened from.
    ref.watch(vetsProvider);
    if (widget.petId != null) ref.watch(healthProfileProvider(widget.petId!));

    return HealthPage(
      title: _editing ? 'Edit vet' : 'Add a vet',
      actions: [
        if (_editing) CoralHeaderAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete vet', onPressed: _delete),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormLabel('Who is it?'),
            TextFormField(
              key: const Key('vet-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Vet or clinic name'),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Enter the name of the vet or the clinic.';
                if (v.length > 120) return 'Keep the name under 120 characters.';
                return null;
              },
            ),
            const FormLabel('How to reach them'),
            TextFormField(
              key: const Key('vet-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: _validatePhone,
            ),
            const SizedBox(height: 10),
            HealthCard(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
              radius: AppSpacing.fieldRadius,
              child: SwitchListTile(
                key: const Key('vet-whatsapp'),
                value: _whatsApp,
                onChanged: (value) => setState(() => _whatsApp = value),
                title: const Text('This number is on WhatsApp', style: AppText.cardTitle),
                subtitle: Text(
                  'Adds a WhatsApp button next to the text message. Needs the country code, like +972.',
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('vet-address'),
              controller: _address,
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Address (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('vet-hours'),
              controller: _hours,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Opening hours (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('vet-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: 'Save vet', loading: _saving, onPressed: _save),
            const SizedBox(height: 12),
            const FinePrint('Saved once for your account, so your other pets can use the same vet.'),
          ],
        ),
      ),
    );
  }
}
