import 'pets_routes.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import 'pets.dart';

final petsModule = FeatureModule(
  id: 'pets',
  routes: petsRoutes,
  actions: {
    // The essentials checklist (Home's Today row of a pet's profile).
    'pet-checklist': FeatureAction.task(
      capability: 'pets.view',
      open: (c, r) => showPetChecklist(c, r.petId),
    ),
    'add-pet': FeatureAction(
      capability: 'pets.edit',
      open: (c, r) => openAddPet(c),
    ),
    'my-pets': FeatureAction.task(
      capability: 'pets.view',
      open: (c, r) => openMyPets(c),
    ),
    'pet-profile': FeatureAction.task(
      capability: 'pets.view',
      open: (c, r) => openPetProfile(c, r.petId),
    ),
    // Where one detail of the pet is filled in (Home's "Add" pills):
    // values {'item': PetInfoItem}.
    'pet-info-item': FeatureAction.task(
      capability: 'pets.edit',
      open: (c, r) => openPetInfoItem(
        c,
        petId: r.petId,
        item: r.value<PetInfoItem>('item')!,
      ),
    ),
  },
  slots: {
    'pet-attention': FeatureSlot(
      capability: 'pets.view',
      build: (c, r) => PetAttentionDot(petId: r.petId),
    ),
  },
);
