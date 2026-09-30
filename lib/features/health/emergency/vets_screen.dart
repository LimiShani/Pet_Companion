import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../state/health_keeper.dart';
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
    final l10n = context.healthL10n;

    return HealthKeeper(
      petId: pet.id,
      child: HealthPage(
        title: l10n.petsVets(pet.name),
        child: vets.when(
          loading: () => const HealthLoading(),
          error: (error, _) => HealthLoadError(
            title: l10n.loadFailedVets,
            error: error,
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
              FinePrint(l10n.vetsFinePrint),
              const SizedBox(height: 8),
              FinePrint(l10n.safetyLine),
            ],
          ),
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
    final l10n = context.healthL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthSectionTitle(
          l10n.vetRole(role),
          trailing: current == null
              ? null
              : HealthLink(
                  l10n.change,
                  key: ValueKey('change-vet-$tag'),
                  onPressed: () => showVetPicker(context, petId: pet.id, role: role),
                ),
        ),
        if (current == null)
          HealthPromptCard(
            key: ValueKey('add-vet-$tag'),
            icon: role == VetRole.regular ? Icons.add_call : Icons.local_hospital_rounded,
            title: role == VetRole.regular ? l10n.addPetsVet(pet.name) : l10n.addEmergencyVet,
            message: role == VetRole.regular ? l10n.vetPromptNote : l10n.emergencyVetPromptNote,
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
                      child: TypedText(
                        current.name,
                        style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('edit-vet-$tag'),
                      onPressed: () => openVetForm(context, vet: current),
                      tooltip: l10n.editNamed(current.name),
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: AppColors.coralDark,
                      constraints: const BoxConstraints(minWidth: kHealthTapTarget, minHeight: kHealthTapTarget),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (current.hasAddress) LabeledValue(l10n.fieldAddress, current.address),
                LabeledValue(
                  l10n.fieldPhone,
                  // A phone number reads left to right on every screen.
                  current.hasPhone ? HealthFormat.of(context).ltrInLine(current.phone) : l10n.notAddedYet,
                  trailing: current.onWhatsApp && current.hasPhone
                      // The name of the app, the same in every language.
                      ? const Padding(padding: EdgeInsetsDirectional.only(top: 4), child: HealthTag('WhatsApp'))
                      : null,
                ),
                if (current.openingHours.isNotEmpty) LabeledValue(l10n.openingHours, current.openingHours),
                if (current.notes.isNotEmpty) LabeledValue(l10n.notes, current.notes),
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
