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
import '../../../platform/usage.dart';
import '../../../services/findvet/data/vet_models.dart';
import 'contact_actions.dart';
import '../../../platform/contact_launcher.dart';
import 'emergency_card_screen.dart';
import '../../../services/pet_records/state/emergency_contacts.dart';
import '../../../services/pet_records/state/emergency_kit.dart';
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
/// whole app: one "Call now" for the most urgent contact, Message and Call
/// for the others, then Find a vet, the Emergency card and kit, and the
/// lost-pet card; or the add-a-vet prompt when nothing is saved. Completes
/// when the sheet is closed.
///
/// Nothing opens for an unknown [petId] (an assertion in debug builds).
Future<void> showEmergencySheet(BuildContext context, String petId) {
  final pet = _petById(context, petId);
  assert(
    pet != null,
    'showEmergencySheet: no pet with id "$petId" in petsProvider',
  );
  if (pet == null) return Future.value();
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(usageProvider).count(UsageKind.emergencyOpened);
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

  /// Opens the Emergency card (which leads on to the kit).
  static const cardKey = Key('open-emergency-card');

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
          SheetTitle(l10n.emergencySheetTitle(pet.name)),
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
                : EmergencyContactList(pet: pet, contacts: data),
          ),
          // Whatever is saved above: the nearest facilities, the card and
          // the kit, and the lost-pet card.
          const SizedBox(height: 12),
          _EmergencyLinks(pet: pet),
          const SizedBox(height: 12),
          FinePrint(l10n.emergencySheetFinePrint),
        ],
      ),
    );
  }
}

/// The three plain rows under the contacts: "Find an emergency vet nearby",
/// "Emergency card and kit" and "{name} is lost".
class _EmergencyLinks extends ConsumerWidget {
  const _EmergencyLinks({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(emergencyKitProvider(pet.id)).value;
    final l10n = context.healthL10n;
    const divider = Divider(height: 1, indent: 16, endIndent: 16);
    return HealthCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Away from home, or no vet of their own: the nearest facilities.
          _PlainRow(
            key: EmergencySheet.findVetKey,
            title: context.findVetL10n.emergencySheetFindVet,
            onTap: () {
              Navigator.of(context).pop();
              openFeature<Object>(context, 'find-vet', '', {
                'mode': VetSearchMode.emergency,
              });
            },
          ),
          divider,
          _PlainRow(
            key: EmergencySheet.cardKey,
            title: l10n.emergencyCardAndKit,
            subtitle: kit == null
                ? l10n.emergencyCardAndKitNote
                : l10n.emergencyCardAndKitNoteKit(kit.ready, kit.total),
            onTap: () {
              Navigator.of(context).pop();
              openEmergencyCard(context, pet.id);
            },
          ),
          divider,
          _PlainRow(
            key: const Key('open-lost-card'),
            title: l10n.petIsLost(pet.name),
            onTap: () => openLostPetCard(context, pet.id),
          ),
        ],
      ),
    );
  }
}

/// A row of [_EmergencyLinks]: a title, an optional line under it, and a
/// chevron. At least 52 px tall.
class _PlainRow extends StatelessWidget {
  const _PlainRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppText.cardTitle.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.label.copyWith(color: AppColors.brown),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const AppIcon(
                Icons.chevron_right_rounded,
                color: AppColors.brown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pet's contacts, most urgent first: the 24 h emergency vet if one is
/// saved, else the regular vet, else the emergency contact leads as one
/// card with "Call now"; the others follow as rows with round Message and
/// Call buttons. Without a vet, the add-a-vet prompt comes last.
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
    // Most urgent first. The keys of each contact's buttons end in its tag.
    final entries = <_Entry>[
      if (emergency != null)
        _Entry(
          tag: 'emergency',
          role: l10n.vetRole(VetRole.emergency),
          name: emergency.name,
          icon: Icons.local_hospital_rounded,
          phone: emergency.phone,
          onWhatsApp: emergency.onWhatsApp,
          address: emergency.address,
          onAddPhone: () => _editVet(context, emergency.id),
        ),
      if (regular != null)
        _Entry(
          tag: 'regular',
          role: l10n.vetRole(VetRole.regular),
          name: regular.name,
          icon: Icons.medical_services_rounded,
          phone: regular.phone,
          onWhatsApp: regular.onWhatsApp,
          address: regular.address,
          onAddPhone: () => _editVet(context, regular.id),
        ),
      if (person != null)
        _Entry(
          tag: 'contact',
          role: l10n.emergencyContact,
          // Only a phone number was given: the person has no name to show.
          name: person.name.isEmpty ? l10n.emergencyContact : person.name,
          icon: Icons.person_rounded,
          phone: person.phone,
          onAddPhone: () => HealthProfileScreen.open(context, pet),
        ),
    ];
    final others = entries.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isNotEmpty)
          EmergencyPrimaryCard(
            petId: pet.id,
            tag: entries.first.tag,
            role: entries.first.role,
            name: entries.first.name,
            icon: entries.first.icon,
            phone: entries.first.phone,
            onWhatsApp: entries.first.onWhatsApp,
            address: entries.first.address,
            onAddPhone: entries.first.onAddPhone,
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          HealthCard(
            key: const Key('emergency-other-contacts'),
            padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < others.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  EmergencyContactRow(
                    petId: pet.id,
                    tag: others[i].tag,
                    role: others[i].role,
                    name: others[i].name,
                    phone: others[i].phone,
                    onWhatsApp: others[i].onWhatsApp,
                    onAddPhone: others[i].onAddPhone,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (regular == null && emergency == null) ...[
          const SizedBox(height: 12),
          HealthPromptCard(
            key: const Key('add-vet-prompt'),
            icon: Icons.add_call,
            title: l10n.addPetsVet(pet.name),
            message: l10n.vetPromptNote,
            onTap: () => showVetPicker(context, petId: pet.id),
          ),
        ],
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

/// One contact of [EmergencyContactList], whichever way it is shown.
class _Entry {
  const _Entry({
    required this.tag,
    required this.role,
    required this.name,
    required this.icon,
    required this.onAddPhone,
    this.phone,
    this.onWhatsApp = false,
    this.address,
  });

  final String tag;
  final String role;
  final String name;
  final IconData icon;
  final String? phone;
  final bool onWhatsApp;
  final String? address;
  final VoidCallback onAddPhone;
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
