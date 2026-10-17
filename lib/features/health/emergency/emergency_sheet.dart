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
import '../../../platform/feature_module.dart';
import '../../../platform/feature_ui.dart';
import '../../../access/access_provider.dart';
import '../../../presentation/health_format.dart';
import '../../../services/safety/state/safety_providers.dart';
import '../../../widgets/area_disc.dart';
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

/// Opens the Emergency sheet, the safety hub, for [petId] as a bottom sheet
/// over the whole app (see [EmergencySheet]); with nothing saved, the
/// add-a-vet prompt takes the place of Call now. Completes when the sheet
/// is closed.
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

/// The content of [showEmergencySheet]: the safety hub.
///
/// The title and one line, then the contact to call first on a peach card
/// (the 24 h clinic if saved, else the regular vet, else the emergency
/// contact) with one Call now, then one white card of rows: the other
/// contacts with round Message and Call, "Is it urgent?", "Can {pet} eat
/// this?", Lost mode, the Emergency card and kit, and Find a clinic
/// nearby; one line of fine print. Each contact appears once.
///
/// The two lists and Lost mode belong to the safety module: their rows
/// show when it answers `safety-urgent`, `safety-food` and `lost-mode`
/// for this account. Without Lost mode the row opens the lost-pet card.
class EmergencySheet extends ConsumerWidget {
  const EmergencySheet({super.key, required this.pet});

  /// Opens Find a vet's emergency path.
  static const findVetKey = Key('emergency-find-vet');

  /// Opens the Emergency card (which leads on to the kit).
  static const cardKey = Key('open-emergency-card');

  /// "Is it urgent?", "Can {pet} eat this?" and Lost mode.
  static const urgentKey = Key('emergency-urgent');
  static const foodKey = Key('emergency-food');
  static const lostKey = Key('emergency-lost');

  /// The rows' white card.
  static const rowsKey = Key('emergency-rows');

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
            subtitle: context.safetyL10n.emergencyLead,
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
                : EmergencyContactList(pet: pet, contacts: data),
          ),
          // Whatever is saved above: the other contacts and the tools.
          const SizedBox(height: 12),
          _HubRows(pet: pet, contacts: contacts.value),
          const SizedBox(height: 12),
          FinePrint(l10n.emergencySheetFinePrint),
        ],
      ),
    );
  }
}

/// Whether an installed module answers [name] for this account, watched so
/// the rows follow a change of permissions.
bool _answers(WidgetRef ref, String name) {
  for (final module in ref.watch(featureModulesProvider)) {
    final action = module.actions[name];
    if (action != null && ref.watch(capabilityProvider(action.capability))) {
      return true;
    }
  }
  return false;
}

/// The white card of rows under the first contact: the other contacts,
/// then the safety tools, the Emergency card and kit, and Find a clinic.
class _HubRows extends ConsumerWidget {
  const _HubRows({required this.pet, required this.contacts});

  final Pet pet;

  /// `null` while the contacts load (or fail): the tools still show.
  final EmergencyContacts? contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(emergencyKitProvider(pet.id)).value;
    final alert = ref.watch(activeLostAlertProvider(pet.id));
    final l10n = context.healthL10n;
    final safety = context.safetyL10n;
    final format = HealthFormat.of(context);
    final now = ref.watch(healthClockProvider)();
    final lostMode = _answers(ref, 'lost-mode');
    final saved = contacts;
    final others = saved == null
        ? const <_Entry>[]
        : _entriesOf(context, pet, saved).skip(1).toList();

    final rows = <Widget>[
      for (final other in others)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
          child: EmergencyContactRow(
            petId: pet.id,
            tag: other.tag,
            role: other.role,
            name: other.name,
            phone: other.phone,
            onWhatsApp: other.onWhatsApp,
            onAddPhone: other.onAddPhone,
            leading: AreaDisc(other.icon, area: AppArea.health),
          ),
        ),
      if (_answers(ref, 'safety-urgent'))
        _HubRow(
          key: EmergencySheet.urgentKey,
          icon: Icons.monitor_heart_rounded,
          title: safety.urgentRow,
          subtitle: safety.urgentRowNote,
          onTap: () => openFeature<Object>(context, 'safety-urgent', pet.id),
        ),
      if (_answers(ref, 'safety-food'))
        _HubRow(
          key: EmergencySheet.foodKey,
          icon: Icons.restaurant_rounded,
          title: safety.foodRow(pet.name),
          subtitle: safety.foodRowNote,
          onTap: () => openFeature<Object>(context, 'safety-food', pet.id),
        ),
      if (alert != null && _answers(ref, 'lost-alert'))
        _HubRow(
          key: EmergencySheet.lostKey,
          icon: Icons.travel_explore_rounded,
          title: safety.lostRowActive(pet.name, alert.sightings),
          subtitle: safety.lostRowActiveNote(
            format.relativeDayTime(alert.lastSeenAt, now),
          ),
          onTap: () => openFeature<Object>(context, 'lost-alert', pet.id, {
            'alert': alert,
          }),
        )
      else
        _HubRow(
          key: EmergencySheet.lostKey,
          icon: Icons.travel_explore_rounded,
          title: safety.lostRow,
          subtitle: lostMode ? safety.lostRowNote : safety.lostRowCardNote,
          onTap: () => lostMode
              ? openFeature<Object>(context, 'lost-mode', pet.id)
              : openLostPetCard(context, pet.id),
        ),
      _HubRow(
        key: EmergencySheet.cardKey,
        icon: Icons.badge_rounded,
        title: l10n.emergencyCardAndKit,
        subtitle: kit == null
            ? l10n.emergencyCardAndKitNote
            : l10n.emergencyCardAndKitNoteKit(kit.ready, kit.total),
        onTap: () {
          Navigator.of(context).pop();
          openEmergencyCard(context, pet.id);
        },
      ),
      // Away from home, or no vet of their own: the nearest facilities.
      _HubRow(
        key: EmergencySheet.findVetKey,
        icon: Icons.local_hospital_rounded,
        title: context.findVetL10n.emergencySheetFindVet,
        subtitle: safety.findClinicNote,
        onTap: () {
          Navigator.of(context).pop();
          openFeature<Object>(context, 'find-vet', '', {
            'mode': VetSearchMode.emergency,
          });
        },
      ),
    ];
    return HealthCard(
      key: EmergencySheet.rowsKey,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// A row of [_HubRows]: an area disc, a title, a line under it, and a
/// chevron. At least 56 px tall.
class _HubRow extends StatelessWidget {
  const _HubRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              AreaDisc(icon, area: AppArea.health),
              const SizedBox(width: 12),
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
                    Text(
                      subtitle,
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
/// saved, else the regular vet, else the emergency contact. The keys of
/// each contact's buttons end in its tag.
List<_Entry> _entriesOf(
  BuildContext context,
  Pet pet,
  EmergencyContacts contacts,
) {
  final regular = contacts.regularVet;
  final emergency = contacts.emergencyVet;
  final person = contacts.contact;
  final l10n = context.healthL10n;
  return [
    if (emergency != null)
      _Entry(
        tag: 'emergency',
        role: l10n.vetRole(VetRole.emergency),
        name: emergency.name,
        icon: Icons.local_hospital_rounded,
        phone: emergency.phone,
        onWhatsApp: emergency.onWhatsApp,
        address: emergency.address,
        vet: true,
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
        vet: true,
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

/// The contact the sheet leads with, on its peach card; without a vet, the
/// add-a-vet prompt under it. The other contacts are rows of the sheet's
/// white card.
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
    final entries = _entriesOf(context, pet, contacts);
    final l10n = context.healthL10n;
    final first = entries.isEmpty ? null : entries.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (first != null)
          EmergencyPrimaryCard(
            tag: first.tag,
            role: first.role,
            name: first.name,
            phone: first.phone,
            address: first.address,
            confirmOpen: first.vet,
            onAddPhone: first.onAddPhone,
          ),
        if (contacts.regularVet == null && contacts.emergencyVet == null) ...[
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
}

/// One contact of the sheet, whichever way it is shown.
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
    this.vet = false,
  });

  final String tag;
  final String role;
  final String name;
  final IconData icon;
  final String? phone;
  final bool onWhatsApp;
  final String? address;

  /// A vet or a clinic (not the emergency contact person).
  final bool vet;
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
