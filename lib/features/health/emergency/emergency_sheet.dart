import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/health_models.dart';
import '../state/health_keeper.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'contact_actions.dart';
import 'contact_launcher.dart';
import 'emergency_card_screen.dart';
import 'emergency_contacts.dart';
import 'emergency_kit_screen.dart';
import 'health_profile_form.dart';
import 'vet_form_screen.dart';
import 'vet_picker.dart';

Pet? _petById(BuildContext context, String petId) {
  for (final pet in ProviderScope.containerOf(context, listen: false).read(petsProvider)) {
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
  assert(pet != null, 'showEmergencySheet: no pet with id "$petId" in petsProvider');
  if (pet == null) return Future.value();
  return showHealthSheet<void>(context, EmergencySheet(pet: pet));
}

/// Dials the pet's first saved number (regular vet, else emergency vet,
/// else the emergency contact). With no number saved it opens the sheet on
/// the add-a-vet prompt instead. Returns whether the dialler was opened.
Future<bool> callPrimaryEmergencyContact(BuildContext context, String petId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final sub = container.listen(emergencyContactsProvider(petId).future, (_, _) {});
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
    problem: 'Could not open the phone app',
    copyLabel: 'Copy number',
    copyText: phone,
  );
}

/// The content of [showEmergencySheet].
class EmergencySheet extends ConsumerWidget {
  const EmergencySheet({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider(pet.id));

    return HealthKeeper(
      petId: pet.id,
      keep: HealthKeep.emergency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(
            'Emergency · ${pet.name}',
            subtitle: 'Call or message. You make the call or send the message yourself.',
          ),
          const SizedBox(height: 12),
          contacts.when(
            loading: () => const HealthLoading(),
            error: (error, _) => HealthLoadError(
              what: 'the contacts',
              message: healthErrorMessage(error),
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
                          "Open ${pet.name}'s Emergency card",
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
          // Being ready, whatever is saved above.
          const SizedBox(height: 10),
          EmergencyKitRow(pet: pet),
          const SizedBox(height: 8),
          const FinePrint(kSafetyLine),
        ],
      ),
    );
  }
}

/// The three contacts with their buttons (also used by the Emergency card).
class EmergencyContactList extends StatelessWidget {
  const EmergencyContactList({super.key, required this.pet, required this.contacts});

  final Pet pet;
  final EmergencyContacts contacts;

  @override
  Widget build(BuildContext context) {
    final regular = contacts.regularVet;
    final emergency = contacts.emergencyVet;
    final person = contacts.contact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (regular != null) ...[
          EmergencyContactCard(
            petId: pet.id,
            tag: 'regular',
            role: VetRole.regular.label,
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
            role: VetRole.emergency.label,
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
            role: 'Emergency contact',
            name: person.name,
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
            title: "Add ${pet.name}'s vet",
            message: 'Phone and address, ready for an emergency',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(vetsProvider).value ?? const <Vet>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
            child: const Icon(Icons.add_call, size: 34, color: AppColors.coralDark),
          ),
        ),
        Text(
          'No vet saved for ${pet.name} yet',
          textAlign: TextAlign.center,
          style: AppText.cardTitle.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          "Add the vet's phone now, so a call or a message is two taps away when you need it.",
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.brown),
        ),
        if (saved.isNotEmpty) ...[
          const FormLabel('Use a vet you already saved'),
          for (final vet in saved)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SavedVetRow(
                vet: vet,
                onUse: () => ref.read(healthProfileProvider(pet.id).notifier).setVet(VetRole.regular, vet.id),
              ),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('add-new-vet'),
          onPressed: () => openVetForm(context, petId: pet.id, role: VetRole.regular),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a new vet'),
        ),
      ],
    );
  }
}
