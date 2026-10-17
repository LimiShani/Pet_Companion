import 'lost_alert_models.dart';

/// Lost mode's backend. The rules live on the server (`0034`): one open
/// alert per pet, three a day per account, the post through the community
/// rules, the pushes to members nearby. Failures are [LostAlertException]s.
abstract class LostAlertsRepository {
  /// The open alerts of the account's households, newest first, with their
  /// sightings.
  Future<List<LostAlert>> mine();

  /// The open alerts of [localityCode] any member may see.
  Future<List<NearbyLostAlert>> near(String localityCode);

  /// Starts an alert: the post, the alert and the pushes, in one go.
  Future<LostAlert> start(LostStart request);

  /// The pet is home: closes the alert with a thank-you on the post.
  Future<LostAlert> markFound(String alertId);

  /// Closes the alert without "found" (started by mistake): the post goes
  /// too when nobody answered it yet.
  Future<LostAlert> cancel(String alertId);
}
