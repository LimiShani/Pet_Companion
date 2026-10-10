import 'park_area.dart';
import 'park_models.dart';

/// Dog parks: the list, "My parks", members' suggestions, and the review
/// of those suggestions. Every write is checked on the server (row level
/// security and the review functions of `0027_dog_parks.sql`), whatever the
/// app shows.
abstract class ParksRepository {
  /// True for made-up sample parks (no backend).
  bool get isDemo;

  /// The parks members can see (active and closed) for [query]: a coarse
  /// box, or one locality. Never the phone's position.
  Future<List<DogPark>> parks(ParkQuery query);

  /// The visible parks among [ids] (saved parks, wherever they are).
  Future<List<DogPark>> parksByIds(Iterable<String> ids);

  /// One visible park, or `null` when it is not (or no longer) shown.
  Future<DogPark?> park(String id);

  /// The ids of the account's saved parks ("My parks").
  Future<Set<String>> favoriteIds();

  Future<void> setFavorite(String parkId, bool saved);

  /// "Suggest a park". Throws [ParkException] (rate limit, connection).
  Future<void> suggestPark(NewParkSuggestion suggestion);

  /// "Update details": only the details that changed, and [closed] when
  /// the member says it is closed for renovation (true) or open again
  /// (false). Throws [ParkException].
  Future<void> suggestDetails(
    String parkId,
    Map<ParkDetail, ParkAnswer> changes, {
    bool? closed,
  });

  /// Reviewers only (the server refuses anyone else).
  Future<ParkReviewQueue> reviewQueue();

  /// Approves (optionally with [edits]: 'name', 'lat', 'lng',
  /// 'locality_code', 'street' and any detail column) or rejects a
  /// suggestion. Returns the park's id when approved.
  Future<String?> decide(
    String suggestionId, {
    required bool approve,
    Map<String, Object?> edits = const {},
  });

  /// A reviewer's word on a park: keep ([ParkStatus.active]), closed, or
  /// removed (hidden, never deleted).
  Future<void> setParkStatus(String parkId, ParkStatus status);
}

/// The changes of a "details" suggestion as the server stores them.
Map<String, Object?> suggestionChanges(
  Map<ParkDetail, ParkAnswer> changes, {
  bool? closed,
}) => {
  for (final entry in changes.entries) entry.key.column: entry.value.name,
  'closed': ?closed,
};
