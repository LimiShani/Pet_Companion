import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../services/household/state/household_providers.dart';
import '../home/widgets/pet_hero.dart' show PetHero;
import '../settings/you_screen.dart' show YouScreen;
import 'household_routes.dart';
import 'widgets/household_slots.dart';

/// Household: the people of one home who share their pets. The Household
/// page (from the You page), the join page, and the people badge on a
/// shared pet's photo. Design: docs/household.md.
final householdModule = FeatureModule(
  id: 'household',
  routes: householdRoutes,
  slots: {
    YouScreen.householdSlot: FeatureSlot(
      capability: HouseholdCapabilities.view,
      build: (c, r) => const HouseholdMenuEntry(),
    ),
    PetHero.peopleSlot: FeatureSlot(
      capability: HouseholdCapabilities.view,
      build: (c, r) => PetPeopleBadge(petId: r.petId),
    ),
  },
  actions: {
    'household': FeatureAction.task(
      capability: HouseholdCapabilities.view,
      open: (c, r) => openHousehold(c),
    ),
    // An invitation link's code: {'code': 'KELY7Q4M'}.
    'join-household': FeatureAction.task(
      capability: HouseholdCapabilities.view,
      open: (c, r) => openJoinHousehold(c, code: r.value<String>('code')),
    ),
  },
);
