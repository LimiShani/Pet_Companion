import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../models/pet.dart';
import '../../../platform/usage.dart';
import '../../../state/pets_provider.dart';
import '../data/fake_household_repository.dart';
import '../data/household_models.dart';
import '../data/household_repository.dart';
import '../data/supabase_household_repository.dart';

/// Who may do what with households (`0030_household.sql`).
abstract final class HouseholdCapabilities {
  static const view = 'household.view';

  /// Invite, take back an invitation, rename, remove (the last two also
  /// need the owner's role, checked by the server).
  static const manage = 'household.manage';
}

/// The clock of invitations ("5 days left"). Tests fix it.
final householdClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseHouseholdRepository(sb.Supabase.instance.client)
      : FakeHouseholdRepository(
          viewerId: () => ref.read(authControllerProvider).value?.id ?? 'demo',
          viewerName: () =>
              ref.read(authControllerProvider).value?.displayName ?? '',
          now: ref.watch(householdClockProvider),
        ),
);

/// The signed-in account's households, its own first; empty when signed
/// out or without [HouseholdCapabilities.view]. Every change goes through
/// here and loads the list again.
class HouseholdsController extends AsyncNotifier<List<Household>> {
  @override
  Future<List<Household>> build() async {
    final user = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final allowed = ref.watch(capabilityProvider(HouseholdCapabilities.view));
    if (user == null || !allowed) return const [];
    return ref.watch(householdRepositoryProvider).myHouseholds();
  }

  HouseholdRepository get _repo => ref.read(householdRepositoryProvider);

  Future<void> _reload() async {
    final households = await _repo.myHouseholds();
    if (ref.mounted) state = AsyncData(households);
  }

  /// Loads the households again (pull to refresh, "Try again").
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.myHouseholds);
  }

  /// An invitation code for [householdId]: an open one [me] made that
  /// still has a day left, else a new one.
  Future<HouseholdInvite> inviteFor(Household household, String me) async {
    final now = ref.read(householdClockProvider)();
    for (final invite in household.invites) {
      if (invite.createdBy == me && invite.daysLeft(now) >= 1) return invite;
    }
    final made = await _repo.createInvite(household.id);
    ref.read(usageProvider).count(UsageKind.householdInviteSent);
    await _reload();
    return HouseholdInvite(
      code: made.code,
      createdBy: me,
      createdByName: '',
      createdAt: now,
      expiresAt: made.expiresAt,
    );
  }

  Future<void> revokeInvite(String code) async {
    await _repo.revokeInvite(code);
    await _reload();
  }

  Future<void> removeMember(String householdId, String userId) async {
    await _repo.removeMember(householdId, userId);
    await _reload();
  }

  Future<void> rename(String householdId, String name) async {
    await _repo.rename(householdId, name);
    await _reload();
  }

  /// Leaves [householdId]; its pets leave the app with it.
  Future<void> leave(String householdId) async {
    await _repo.leave(householdId);
    await _reload();
    _petsChanged();
  }

  /// Joins the household of [code] as a carer; its pets arrive in the app.
  /// Returns the household's id.
  Future<String> accept(String code) async {
    final id = await _repo.accept(code);
    await _reload();
    _petsChanged();
    return id;
  }

  /// The pets the account looks after came or went: load them again.
  void _petsChanged() {
    if (ref.mounted) ref.read(petsStoreProvider.notifier).retry();
  }
}

final householdsProvider =
    AsyncNotifierProvider<HouseholdsController, List<Household>>(
      HouseholdsController.new,
    );

/// The households the Household page shows: the account's own one is left
/// out while nobody else is in it, it has no pets, and the account belongs
/// to another household (a carer who has no pets of their own).
final shownHouseholdsProvider = Provider<AsyncValue<List<Household>>>((ref) {
  final me = ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref
      .watch(householdsProvider)
      .whenData((households) => householdsToShow(households, me));
});

/// [households] without the account's own one while it is empty (only
/// [me], no invitations, no pets) and there is another to show.
List<Household> householdsToShow(List<Household> households, String? me) {
  if (households.length < 2) return households;
  bool emptyOwn(Household h) => h.ownerId == me && h.isJustMe && h.pets.isEmpty;
  final shown = [
    for (final household in households)
      if (!emptyOwn(household)) household,
  ];
  return shown.isEmpty ? households : shown;
}

/// The household [pet] lives in, when the households are loaded.
Household? householdOfPet(List<Household> households, Pet pet) {
  for (final household in households) {
    if (pet.householdId != null && household.id == pet.householdId) {
      return household;
    }
  }
  for (final household in households) {
    if (household.pets.any((p) => p.id == pet.id)) return household;
  }
  return null;
}

/// The other people who look after the pet with [petId]: the members of
/// its household other than the signed-in account. Empty while loading,
/// for a pet nobody shares, and without households.
final petCarersProvider = Provider.family<List<HouseholdMember>, String>((
  ref,
  petId,
) {
  final me = ref.watch(authControllerProvider.select((a) => a.value?.id));
  final pet = ref.watch(petsStoreProvider).byId(petId);
  final households = ref.watch(householdsProvider).value;
  if (pet == null || households == null) return const [];
  return householdOfPet(households, pet)?.othersThan(me) ?? const [];
});
