import 'household_models.dart';

/// Households: the people of one home who share their pets. Every write is
/// checked on the server (the functions and row level security of
/// `0030_household.sql`) whatever the app shows; failures are
/// [HouseholdException]s.
abstract class HouseholdRepository {
  /// The signed-in account's households, its own first.
  Future<List<Household>> myHouseholds();

  /// A new invitation code for [householdId] (any member).
  Future<NewInvite> createInvite(String householdId);

  /// Takes back an invitation nobody used yet.
  Future<void> revokeInvite(String code);

  /// What [code] leads to, before joining.
  Future<InvitePreview> preview(String code);

  /// Joins the household of [code] as a carer. Returns its id.
  Future<String> accept(String code);

  /// The owner removes a carer.
  Future<void> removeMember(String householdId, String userId);

  /// A carer leaves.
  Future<void> leave(String householdId);

  /// The owner names the household; empty names it after its pets.
  Future<void> rename(String householdId, String name);
}
