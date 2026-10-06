import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/state/health_keeper.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../presentation/health_widgets.dart';
import '../../../platform/feature_ui.dart';
import '../../../services/findvet/data/vet_models.dart';
import 'contact_actions.dart';
import '../../../platform/contact_launcher.dart';
import 'emergency_card_screen.dart';
import '../../../services/pet_records/state/emergency_contacts.dart';
import 'emergency_kit_screen.dart';
import 'health_profile_form.dart';
import 'lost_pet_card_screen.dart';
import 'vet_form_screen.dart';
import 'vet_picker.dart';

Pet? _petById(BuildContext context, String petId) {
  for (final pet in ProviderScope.containerOf(
    context,
    listen: false,
  ).read(petsProvider)) {
    if (pet.id == petId) return pet;
  }
  return null;
}

/// Opens the emergency actions for [petId] as a bottom sheet over the
/// whole app: Call, Message and Map for the pet's vets and emergency
/// contact, a link to the Emergency card, or the add-a-vet prompt when
/// nothing is saved. Completes when the sheet is closed.
///
/// Nothing opens for an unknown [petId] (an assertion in debug builds).
Future<void> showEmergencySheet(BuildContext context, String petId) {
  final pet = _petById(context, petId);
  assert(
    pet != null,
    'showEmergencySheet: no pet with id "$petId" in petsProvider',
  );
  if (pet == null) return Future.value();
  return showHealthSheet<void>(context, EmergencySheet(pet: pet));
}

/// Dials the pet's first saved number (regular vet, else emergency vet,
/// else the emergency contact). With no number saved it opens the sheet on
/// the add-a-vet prompt instead. Returns whether the dialler was opened.
Future<bool> callPrimaryEmergencyContact(
  BuildContext context,
  String petId,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final sub = container.listen(
    emergencyContactsProvider(petId).future,
    (_, _) {},
  );
  EmergencyContacts? contacts;
  try {
    contacts = await sub.read();
  } catch (_) {
    contacts = null;
  } finally {
    sub.close();
  }
  if (!context.mounted) return false;
  final phone = contacts?.primaryPhone;
  if (phone == null) {
    await showEmergencySheet(context, petId);
    return false;
  }
  final launcher = container.read(contactLauncherProvider);
  return launchOrExplain(
    context,
    launch: () => launcher.call(phone),
    problem: context.healthL10n.couldNotOpenPhone,
    copyLabel: context.healthL10n.copyNumber,
    copyText: phone,
    copyIsNumber: true,
  );
}

/// The content of [showEmergencySheet].
class EmergencySheet extends ConsumerWidget {
  const EmergencySheet({super.key, required this.pet});

  /// Opens Find a vet's emergency path.
  static const findVetKey = Key('emergency-find-vet');

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'health.emergency.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider(pet.id));
    final l10n = context.healthL10n;

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.emergency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(
            l10n.emergencySheetTitle(pet.name),
            subtitle: l10n.emergencySheetSubtitle,
          ),
          const SizedBox(height: 12),
          contacts.when(
            loading: () => const HealthLoading(),
            error: (error, _) => HealthLoadError(
              title: l10n.loadFailedContacts,
              error: error,
              onRetry: () {
                ref.invalidate(vetsProvider);
                ref.invalidate(healthProfileProvider(pet.id));
              },
            ),
            data: (data) => data.isEmpty
                ? NoVetPrompt(pet: pet)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EmergencyContactList(pet: pet, contacts: data),
                      Center(
                        child: HealthLink(
                          l10n.openEmergencyCardOf(pet.name),
                          icon: Icons.chevron_right_rounded,
                          onPressed: () {
                            Navigator.of(context).pop();
                            openEmergencyCard(context, pet.id);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          // Away from home, or no vet of their own: the nearest facilities.
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: EmergencySheet.findVetKey,
            onPressed: () {
              Navigator.of(context).pop();
              openFeature<Object>(context, 'find-vet', '', {
                'mode': VetSearchMode.emergency,
              });
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.near_me_rounded),
            label: Text(context.findVetL10n.emergencySheetFindVet),
          ),
          // Being ready, whatever is saved above.
          const SizedBox(height: 10),
          EmergencyKitRow(pet: pet),
          const SizedBox(height: 10),
          LostPetButton(pet: pet),
          const SizedBox(height: 8),
          FinePrint(l10n.safetyLine),
        ],
      ),
    );
  }
}

/// The three contacts with their buttons (also used by the Emergency card).
class EmergencyContactList extends StatelessWidget {
  const EmergencyContactList({
    super.key,
    required this.pet,
    required this.contacts,
  });

  final Pet pet;
  final EmergencyContacts contacts;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.emergency.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final regular = contacts.regularVet;
    final emergency = contacts.emergencyVet;
    final person = contacts.contact;
    final l10n = context.healthL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (regular != null) ...[
          EmergencyContactCard(
            petId: pet.id,
            tag: 'regular',
            role: l10n.vetRole(VetRole.regular),
            name: regular.name,
            icon: Icons.medical_services_rounded,
            detail: regular.openingHours ?? regular.address,
            phone: regular.phone,
            onWhatsApp: regular.onWhatsApp,
            address: regular.address,
            onAddPhone: () => _editVet(context, regular.id),
          ),
          const SizedBox(height: 10),
        ],
        if (emergency != null) ...[
          EmergencyContactCard(
            petId: pet.id,
            tag: 'emergency',
            role: l10n.vetRole(VetRole.emergency),
            name: emergency.name,
            icon: Icons.local_hospital_rounded,
            detail: emergency.openingHours ?? emergency.address,
            phone: emergency.phone,
            onWhatsApp: emergency.onWhatsApp,
            address: emergency.address,
            onAddPhone: () => _editVet(context, emergency.id),
          ),
          const SizedBox(height: 10),
        ],
        if (person != null) ...[
          EmergencyContactCard(
            petId: pet.id,
            tag: 'contact',
            role: l10n.emergencyContact,
            // Only a phone number was given: the person has no name to show.
            name: person.name.isEmpty ? l10n.emergencyContact : person.name,
            icon: Icons.person_rounded,
            phone: person.phone,
            onAddPhone: () => HealthProfileScreen.open(context, pet),
          ),
          const SizedBox(height: 10),
        ],
        if (regular == null && emergency == null)
          HealthPromptCard(
            key: const Key('add-vet-prompt'),
            icon: Icons.add_call,
            title: l10n.addPetsVet(pet.name),
            message: l10n.vetPromptNote,
            onTap: () => showVetPicker(context, petId: pet.id),
          ),
      ],
    );
  }

  Future<void> _editVet(BuildContext context, String vetId) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final vets = container.read(vetsProvider).value ?? const <Vet>[];
    for (final vet in vets) {
      if (vet.id == vetId) {
        await openVetForm(context, vet: vet);
        return;
      }
    }
  }
}

/// What the sheet shows when the pet has no vet and no contact yet: a
/// prompt, the owner's already saved vets with "Use", and "Add a new vet".
class NoVetPrompt extends ConsumerWidget {
  const NoVetPrompt({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'health.emergency.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(vetsProvider).value ?? const <Vet>[];
    final l10n = context.healthL10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            margin: const EdgeInsetsDirectional.only(top: 4, bottom: 12),
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
            child: const AppIcon(
              Icons.add_call,
              size: 34,
              color: AppColors.coralDark,
            ),
          ),
        ),
        Text(
          l10n.noVetSavedFor(pet.name),
          textAlign: TextAlign.center,
          style: AppText.cardTitle.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.noVetSavedNote,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.brown),
        ),
        if (saved.isNotEmpty) ...[
          FormLabel(l10n.useSavedVet),
          for (final vet in saved)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: SavedVetRow(
                vet: vet,
                onUse: () => ref
                    .read(healthProfileProvider(pet.id).notifier)
                    .setVet(VetRole.regular, vet.id),
              ),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('add-new-vet'),
          onPressed: () =>
              openVetForm(context, petId: pet.id, role: VetRole.regular),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(kHealthTapTarget),
          ),
          icon: const AppIcon(Icons.add_rounded),
          label: Text(l10n.addNewVet),
        ),
      ],
    );
  }
}
