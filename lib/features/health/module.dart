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
import 'records/record_form_screen.dart';
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
  ),
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
    'emergency': FeatureAction.task(
      capability: 'health.emergency.view',
      open: (c, r) => showEmergencySheet(c, r.petId),
    ),
    'health-profile': FeatureAction.task(
      capability: 'health.emergency.edit',
      open: (c, r) => openHealthProfile(c, r.petId),
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
