import '../../community/data/community_models.dart' show ReportReason;
import 'meetup_models.dart';

/// Walk and play partner ads. Every write is checked on the server (the
/// functions and row level security of `0028_meetups.sql`), whatever the
/// app shows; failures are [MeetupException]s.
abstract class MeetupsRepository {
  /// True for made-up sample ads (no backend).
  bool get isDemo;

  /// The open ads in the localities with [localityCodes] (the cities in
  /// range of the chosen one: never a position).
  Future<List<Meetup>> openMeetups(Iterable<String> localityCodes);

  /// The open ads at the parks with [parkIds].
  Future<List<Meetup>> atParks(Iterable<String> parkIds);

  /// A member's open ads (their member page).
  Future<List<Meetup>> byAuthor(String authorId);

  /// All the signed-in member's ads: open, ended and closed (until they
  /// are deleted, 90 days after they ended).
  Future<List<Meetup>> mine();

  /// One ad the reader may see, or `null`.
  Future<Meetup?> meetup(String id);

  /// Posts a new ad, or (with [id]) changes an open one of the author's.
  /// Returns the ad's id.
  Future<String> save(MeetupDraft draft, {String? id});

  /// "Found someone, close it".
  Future<void> close(String id);

  /// Another 30 days for a recurring ad.
  Future<void> renew(String id);

  /// "I want to join": records that the reader answered. Returns how many
  /// answered.
  Future<int> answer(String id);

  /// Who answered the author's ad, newest first.
  Future<List<MeetupResponder>> responders(String id);

  Future<void> report(String id, ReportReason reason);

  /// The saved parks the member asked to hear about new ads at.
  Future<Set<String>> notifyParkIds();

  /// "Tell me about new meetups here" for a saved park.
  Future<void> setNotify(String parkId, bool on);
}
