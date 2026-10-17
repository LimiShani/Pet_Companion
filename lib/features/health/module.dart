import 'package:go_router/go_router.dart';
import '../../services/pet_records/state/health_providers.dart';
import 'package:flutter/material.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../l10n/l10n.dart';
import '../../widgets/petloop_icon.dart';
import '../../services/pet_records/data/health_models.dart';
import 'health_routes.dart';
import 'emergency/emergency.dart';
import 'emergency/vets_screen.dart';
import 'records/pet_documents_screen.dart';
import 'records/record_form_screen.dart';
import 'insights/quick_log_sheet.dart';
import 'schedule/medicine_form_screen.dart';
import 'schedule/record_dose_sheet.dart';
import '../../services/pet_records/state/schedule_logic.dart';
import '../../presentation/schedule/routine_form_screen.dart';
import 'widgets/upcoming_card.dart';
import '../../state/pets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final healthModule = FeatureModule(
  id: 'health',
  tab: FeatureTab(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    glyph: PetLoopGlyph.health,
    label: (c) => c.l10n.navHealth,
    routes: healthRoutes,
    area: AppArea.health,
  ),
  // The Health tab's "+": what can be added for the pet on show.
  add: {
    AddTab.health: [
      AddEntry(
        id: 'quick-log',
        capability: 'health.records.edit',
        area: AppArea.health,
        icon: Icons.edit_note_rounded,
        label: (c) => c.healthL10n.quickLog,
        subtitle: (c) => c.healthL10n.addQuickLogNote,
        order: 0,
        open: (c, r) => showQuickLog(c, requestPet(c, r)),
      ),
      AddEntry(
        id: 'record',
        capability: 'health.records.edit',
        area: AppArea.health,
        icon: Icons.description_rounded,
        label: (c) => c.healthL10n.addSheetRecord,
        subtitle: (c) => c.healthL10n.addSheetRecordNote,
        order: 10,
        open: (c, r) => openRecordForm(c, requestPet(c, r)),
      ),
      AddEntry(
        id: 'appointment',
        capability: 'health.records.edit',
        area: AppArea.health,
        icon: Icons.event_rounded,
        label: (c) => c.healthL10n.addAppointment,
        subtitle: (c) => c.healthL10n.addAppointmentNote,
        order: 20,
        open: (c, r) => openRecordForm(
          c,
          requestPet(c, r),
          kind: RecordKind.checkup,
          planned: true,
        ),
      ),
      AddEntry(
        id: 'medicine',
        capability: 'health.schedule.edit',
        area: AppArea.health,
        icon: Icons.medication_rounded,
        label: (c) => c.healthL10n.medicine,
        subtitle: (c) => c.healthL10n.addMedicineNote,
        order: 30,
        open: (c, r) => openMedicineForm(c, requestPet(c, r)),
      ),
      AddEntry(
        id: 'routine',
        capability: 'health.schedule.edit',
        area: AppArea.care,
        icon: Icons.restaurant_rounded,
        label: (c) => c.healthL10n.addSheetRoutine,
        subtitle: (c) => c.healthL10n.addRoutineNote,
        order: 40,
        open: (c, r) => openRoutineForm(c, requestPet(c, r)),
      ),
    ],
  },
  home: [
    FeatureContribution(
      id: 'upcoming-health',
      capability: 'health.records.view|health.schedule.view',
      order: 20,
      builder: (_, _) => Consumer(
        builder: (c, ref, _) => HealthCard(pet: ref.watch(selectedPetProvider)),
      ),
    ),
  ],
  actions: {
    'health-schedule': FeatureAction.task(
      capability: 'health.schedule.view',
      open: (c, r) async {
        ProviderScope.containerOf(
          c,
          listen: false,
        ).read(healthSectionProvider.notifier).show(HealthSection.schedule);
        Navigator.of(c).maybePop();
        GoRouter.maybeOf(c)?.go(HealthRoutes.root);
      },
    ),
    'vet-picker': FeatureAction.task(
      capability: 'health.emergency.edit',
      open: (c, r) async {
        await showVetPicker(
          c,
          petId: r.petId,
          role: r.value<VetRole>('role') ?? VetRole.regular,
        );
      },
    ),
    // Home's Today dose rows: "Record dose" for one reminder, values
    // {'entry': ScheduleEntry}.
    'record-dose': FeatureAction.task(
      capability: 'health.schedule.view',
      open: (c, r) => showRecordDoseSheet(
        c,
        requestPet(c, r),
        entry: r.value<ScheduleEntry>('entry'),
      ),
    ),
    'emergency': FeatureAction.task(
      capability: 'health.emergency.view',
      open: (c, r) => showEmergencySheet(c, r.petId),
    ),
    'health-profile': FeatureAction.task(
      capability: 'health.emergency.edit',
      open: (c, r) => openHealthProfile(c, r.petId),
    ),
    // The pet's two vets (the pet profile's "Vets" row).
    'pet-vets': FeatureAction.task(
      capability: 'health.emergency.view',
      open: (c, r) => VetsScreen.open(c, requestPet(c, r)),
    ),
    // Every file attached to the pet's records (the pet profile's
    // "Documents" row; the emergency kit opens the same page).
    // The lost-pet card of the pet, to share (Lost mode opens it).
    'lost-card': FeatureAction.task(
      capability: 'health.emergency.view',
      open: (c, r) => openLostPetCard(c, r.petId),
    ),
    'pet-documents': FeatureAction.task(
      capability: 'health.records.view',
      open: (c, r) => PetDocumentsScreen.open(c, requestPet(c, r)),
    ),
    'health-critical': FeatureAction.task(
      capability: 'health.emergency.edit',
      open: (c, r) => openHealthCriticalItem(
        c,
        petId: r.petId,
        item: r.value<HealthCriticalItem>('item')!,
      ),
    ),
    'vet-form': FeatureAction(
      capability: 'health.emergency.edit',
      open: (c, r) => openVetForm(
        c,
        petId: r.petId.isEmpty ? null : r.petId,
        role: r.value<VetRole>('role'),
        prefill: r.value<Vet>('prefill'),
      ),
    ),
    'record-form': FeatureAction(
      capability: 'health.records.edit',
      open: (c, r) => openRecordForm(
        c,
        requestPet(c, r),
        kind: r.value<RecordKind>('kind'),
        planned: r.value<bool>('planned') ?? false,
      ),
    ),
  },
  slots: {
    'emergency-button': FeatureSlot(
      capability: 'health.emergency.view',
      build: (c, r) => EmergencyButton(petId: r.petId),
    ),
    'vet-tile': FeatureSlot(
      capability: 'health.emergency.view',
      build: (c, r) => PetVetTile(
        petId: r.petId,
        role: r.value<VetRole>('role') ?? VetRole.regular,
      ),
    ),
    'health-basics': FeatureSlot(
      capability: 'health.emergency.edit',
      build: (c, r) => HealthBasicsSection(
        petId: r.petId,
        saveLabel: r.value<String>('saveLabel'),
        onSaved: r.value<ValueChanged<HealthProfile>>('onSaved'),
      ),
    ),
  },
);
