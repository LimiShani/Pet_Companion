import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/health_models.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'vet_form_screen.dart';

/// Lets the owner choose the vet of [petId] for [role]: one of the vets
/// already saved for the account ("Use"), or a new one (the vet form).
///
/// Returns the vet now linked to the pet, or `null` when the owner closed
/// the sheet without choosing. With no saved vets it goes straight to the
/// form.
Future<Vet?> showVetPicker(BuildContext context, {required String petId, VetRole role = VetRole.regular}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final sub = container.listen(vetsProvider.future, (_, _) {});
  List<Vet> saved;
  try {
    saved = await sub.read();
  } catch (_) {
    saved = const [];
  } finally {
    sub.close();
  }
  if (!context.mounted) return null;
  if (saved.isEmpty) return openVetForm(context, petId: petId, role: role);
  return showHealthSheet<Vet>(context, VetPickerSheet(petId: petId, role: role));
}

class VetPickerSheet extends ConsumerStatefulWidget {
  const VetPickerSheet({super.key, required this.petId, required this.role});

  final String petId;
  final VetRole role;

  @override
  ConsumerState<VetPickerSheet> createState() => _VetPickerSheetState();
}

class _VetPickerSheetState extends ConsumerState<VetPickerSheet> {
  String? _busyId;
  String? _error;

  Future<void> _use(Vet vet) async {
    setState(() {
      _busyId = vet.id;
      _error = null;
    });
    try {
      await ref.read(healthProfileProvider(widget.petId).notifier).setVet(widget.role, vet.id);
      if (mounted) Navigator.of(context).pop(vet);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busyId = null;
          _error = healthErrorMessage(e);
        });
      }
    }
  }

  Future<void> _addNew() async {
    final vet = await openVetForm(context, petId: widget.petId, role: widget.role);
    if (vet != null && mounted) Navigator.of(context).pop(vet);
  }

  Future<void> _remove() async {
    try {
      await ref.read(healthProfileProvider(widget.petId).notifier).setVet(widget.role, null);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = healthErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vets = ref.watch(petVetsProvider(widget.petId));
    final current = vets.value?.of(widget.role);
    final saved = vets.value?.saved ?? const <Vet>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          widget.role == VetRole.regular ? 'Choose the regular vet' : 'Choose the emergency vet',
          subtitle: 'Vets you saved before can be used for any of your pets.',
        ),
        const SizedBox(height: 12),
        if (vets.isLoading && !vets.hasValue) const HealthLoading(),
        for (final vet in saved)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SavedVetRow(
              vet: vet,
              selected: vet.id == current?.id,
              busy: _busyId == vet.id,
              onUse: _busyId == null ? () => _use(vet) : null,
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: _addNew,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a new vet'),
        ),
        if (current != null)
          Center(child: HealthLink('Remove ${current.name} from this pet', onPressed: _remove)),
      ],
    );
  }
}

/// One of the owner's saved vets with a "Use" button.
class SavedVetRow extends StatelessWidget {
  const SavedVetRow({super.key, required this.vet, required this.onUse, this.selected = false, this.busy = false});

  final Vet vet;
  final VoidCallback? onUse;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final detail = vet.hasPhone
        ? vet.phone
        : vet.hasAddress
            ? vet.address
            : 'No phone number yet';
    return HealthCard(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 10, bottom: 10),
      child: Row(
        children: [
          const IconDisc(Icons.medical_services_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vet.name, style: AppText.cardTitle),
                Text(detail, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (selected)
            const HealthTag('In use', highlight: true)
          else
            OutlinedButton(
              key: ValueKey('use-vet-${vet.id}'),
              onPressed: busy ? null : onUse,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Use'),
            ),
        ],
      ),
    );
  }
}

/// A ready-made card for a form step: the pet's vet for [role] (name,
/// phone, "Change") or a prompt to add one. Tapping opens [showVetPicker].
/// Handles loading and load errors itself.
class PetVetTile extends ConsumerWidget {
  const PetVetTile({super.key, required this.petId, this.role = VetRole.regular});

  final String petId;
  final VetRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vets = ref.watch(petVetsProvider(petId));
    void pick() => showVetPicker(context, petId: petId, role: role);

    if (vets.hasError && !vets.hasValue) {
      return HealthCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                healthErrorMessage(vets.error!),
                style: AppText.secondary.copyWith(color: AppColors.brown),
              ),
            ),
            HealthLink('Try again', onPressed: () {
              ref.invalidate(vetsProvider);
              ref.invalidate(healthProfileProvider(petId));
            }),
          ],
        ),
      );
    }
    if (!vets.hasValue) return const HealthCard(child: Center(child: CircularProgressIndicator()));

    final vet = vets.value!.of(role);
    if (vet == null) {
      return HealthPromptCard(
        icon: role == VetRole.regular ? Icons.add_call : Icons.local_hospital_rounded,
        title: role == VetRole.regular ? 'Add a vet' : 'Add an emergency vet',
        message: role == VetRole.regular
            ? 'Phone and address, ready for an emergency'
            : 'A 24-hour clinic for nights and weekends',
        onTap: pick,
      );
    }
    return HealthCard(
      onTap: pick,
      child: Row(
        children: [
          const IconDisc(Icons.medical_services_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.label, style: AppText.label.copyWith(color: AppColors.brown)),
                Text(vet.name, style: AppText.cardTitle),
                Text(
                  vet.hasPhone ? vet.phone : 'No phone number yet',
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('Change', style: AppText.secondary.copyWith(color: AppColors.coralDark, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
