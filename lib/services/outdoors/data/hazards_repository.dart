import 'hazard_models.dart';

/// Hazard reports by area. Every write is checked on the server (the
/// functions and row level security of `0035_neighbourhood.sql`), whatever
/// the app shows; failures are [HazardException]s.
abstract class HazardsRepository {
  /// True for made-up sample reports (no backend).
  bool get isDemo;

  /// The current reports in the localities with [localityCodes] (the
  /// cities in range: never a position), newest first. The reader's own
  /// hidden ones too.
  Future<List<HazardReport>> current(Iterable<String> localityCodes);

  /// A new report. Returns its id.
  Future<String> report(HazardDraft draft);

  /// "Still there" (`gone: false`) or "Not there any more" (`gone: true`)
  /// on someone else's report. Returns whether it is still shown.
  Future<bool> vote(String id, {required bool gone});

  /// The author takes their report down.
  Future<void> delete(String id);
}
