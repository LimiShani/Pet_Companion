import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/health_models.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'contact_actions.dart';
import 'vet_form_screen.dart';
import 'vet_picker.dart';

/// The Vet section: the pet's regular vet and its emergency vet, each with
/// address, phone, opening hours, notes and the Call / Message / Map
/// actions.
class VetsScreen extends ConsumerWidget {
  const VetsScreen({super.key, required this.pet});

  final Pet pet;

  static Future<void> open(BuildContext context, Pet pet) => pushHealthPage<void>(context, VetsScreen(pet: pet));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vets = ref.watch(petVetsProvider(pet.id));

    return HealthPage(
      title: "${pet.name}'s vets",
      child: vets.when(
        loading: () => const HealthLoading(),
        error: (error, _) => HealthLoadError(
          what: 'the vets',
          message: healthErrorMessage(error),
          onRetry: () {
            ref.invalidate(vetsProvider);
            ref.invalidate(healthProfileProvider(pet.id));
          },
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            for (final role in VetRole.values) ...[
              _VetBlock(pet: pet, role: role, vet: data.of(role)),
              const SizedBox(height: 16),
            ],
            const FinePrint('Vets are saved once for your account, so your other pets can use the same ones.'),
            const SizedBox(height: 8),
            const FinePrint(kSafetyLine),
          ],
        ),
      ),
    );
  }
}

class _VetBlock extends StatelessWidget {
  const _VetBlock({required this.pet, required this.role, required this.vet});

  final Pet pet;
  final VetRole role;
  final Vet? vet;

  @override
  Widget build(BuildContext context) {
    final current = vet;
    final tag = role.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthSectionTitle(
          role.label,
          trailing: current == null
              ? null
              : HealthLink(
                  'Change',
                  key: ValueKey('change-vet-$tag'),
                  onPressed: () => showVetPicker(context, petId: pet.id, role: role),
                ),
        ),
        if (current == null)
          HealthPromptCard(
            key: ValueKey('add-vet-$tag'),
            icon: role == VetRole.regular ? Icons.add_call : Icons.local_hospital_rounded,
            title: role == VetRole.regular ? "Add ${pet.name}'s vet" : 'Add an emergency vet',
            message: role == VetRole.regular
                ? 'Phone and address, ready for an emergency'
                : 'A 24-hour clinic for nights and weekends',
            onTap: () => showVetPicker(context, petId: pet.id, role: role),
          )
        else
          HealthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconDisc(role == VetRole.regular ? Icons.medical_services_rounded : Icons.local_hospital_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(current.name, style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      key: ValueKey('edit-vet-$tag'),
                      onPressed: () => openVetForm(context, vet: current),
                      tooltip: 'Edit ${current.name}',
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: AppColors.coralDark,
                      constraints: const BoxConstraints(minWidth: kHealthTapTarget, minHeight: kHealthTapTarget),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (current.hasAddress) LabeledValue('Address', current.address),
                LabeledValue(
                  'Phone',
                  current.hasPhone ? current.phone : 'Not added yet',
                  trailing: current.onWhatsApp && current.hasPhone
                      ? const Padding(padding: EdgeInsets.only(top: 4), child: HealthTag('WhatsApp'))
                      : null,
                ),
                if (current.openingHours.isNotEmpty) LabeledValue('Opening hours', current.openingHours),
                if (current.notes.isNotEmpty) LabeledValue('Notes', current.notes),
                const SizedBox(height: 8),
                ContactActionButtons(
                  petId: pet.id,
                  tag: tag,
                  name: current.name,
                  phone: current.hasPhone ? current.phone : null,
                  onWhatsApp: current.onWhatsApp,
                  address: current.hasAddress ? current.address : null,
                  onAddPhone: () => openVetForm(context, vet: current),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
