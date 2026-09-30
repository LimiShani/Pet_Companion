import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../health_strings.dart';
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

  /// What went wrong; worded when it is shown.
  Object? _error;

  bool get _editing => widget.vet != null;

  /// The example of a country code, left to right on every screen.
  static const _countryCode = '+972';

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _hours, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final l10n = context.healthL10n;
    final v = value?.trim() ?? '';
    if (v.isEmpty) return _whatsApp ? l10n.validWhatsAppNumber : null;
    final digits = v.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length < 5 || RegExp(r'[^0-9+()\-\s.]').hasMatch(v)) return l10n.validPhone;
    if (_whatsApp && !v.startsWith('+')) {
      return l10n.validWhatsAppCountryCode(HealthFormat.of(context).ltrInLine(_countryCode));
    }
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
          _error = e;
        });
      }
    }
  }

  Future<void> _delete() async {
    final vet = widget.vet!;
    final confirmed = await confirmDelete(
      context,
      title: context.healthL10n.deleteVetTitle,
      message: context.healthL10n.deleteVetMessage(vet.name),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(vetsProvider.notifier).delete(vet.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the owner's vets (and the pet's profile) alive while the form
    // is open, wherever it was opened from.
    ref.watch(vetsProvider);
    if (widget.petId != null) ref.watch(healthProfileProvider(widget.petId!));
    final l10n = context.healthL10n;

    return HealthPage(
      title: _editing ? l10n.editVet : l10n.addVet,
      actions: [
        if (_editing)
          CoralHeaderAction(icon: Icons.delete_outline_rounded, tooltip: l10n.deleteVet, onPressed: _delete),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormLabel(l10n.whoIsIt),
            TextFormField(
              key: const Key('vet-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.vetOrClinicName),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return l10n.validVetName;
                if (v.length > 120) return l10n.validNameTooLong(120);
                return null;
              },
            ),
            FormLabel(l10n.howToReachThem),
            TextFormField(
              key: const Key('vet-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              // A phone number: left to right on every screen.
              textDirection: TextDirection.ltr,
              textAlign: context.isRtl ? TextAlign.end : TextAlign.start,
              decoration: InputDecoration(labelText: l10n.fieldPhone),
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
                title: Text(l10n.onWhatsApp, style: AppText.cardTitle),
                subtitle: Text(
                  l10n.onWhatsAppNote(HealthFormat.of(context).ltrInLine(_countryCode)),
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
              decoration: InputDecoration(labelText: l10n.addressOptional),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('vet-hours'),
              controller: _hours,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.openingHoursOptional),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('vet-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.notesOptional),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                healthErrorOf(context, _error),
                style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: l10n.saveVet, loading: _saving, onPressed: _save),
            const SizedBox(height: 12),
            FinePrint(l10n.vetFormFinePrint),
          ],
        ),
      ),
    );
  }
}
