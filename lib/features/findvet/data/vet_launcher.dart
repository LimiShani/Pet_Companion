import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../health/emergency/contact_launcher.dart' show telUri;
import 'vet_models.dart';

/// What Find a vet asked the phone to open.
enum VetLaunch { call, directions, link }

/// One request handed to a [VetLauncher] (what tests inspect).
class VetLaunched {
  const VetLaunched(this.kind, this.target);

  final VetLaunch kind;

  /// The phone number, the destination ("lat,lng") or the link.
  final String target;

  @override
  String toString() => 'VetLaunched(${kind.name}, $target)';
}

/// Opens the dialler, a navigation app or a web page. Call opens the
/// dialler at once with the number filled in (one tap: the owner presses
/// call there); nothing is marked confirmed afterwards.
abstract class VetLauncher {
  Future<bool> call(String phone);
  Future<bool> directions(VetResult vet);
  Future<bool> openLink(String url);
}

/// A "navigate to" link for [vet]: by coordinates (they are exact even when
/// the address text is not), plus the provider's place id when known.
Uri directionsUri(VetResult vet) => Uri.https('www.google.com', '/maps/dir/', {
  'api': '1',
  'destination': '${vet.location.lat},${vet.location.lng}',
  if (vet.placeId != null && !vet.placeId!.startsWith('demo')) 'destination_place_id': vet.placeId!,
});

/// The same destination as a `geo:` link: Android lets the owner pick any
/// navigation app (Waze, Google Maps...).
Uri geoUri(VetResult vet) {
  final point = '${vet.location.lat},${vet.location.lng}';
  return Uri.parse('geo:$point?q=$point(${Uri.encodeComponent(vet.name)})');
}

class UrlVetLauncher implements VetLauncher {
  const UrlVetLauncher();

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> call(String phone) => _open(telUri(phone));

  @override
  Future<bool> directions(VetResult vet) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && await _open(geoUri(vet))) return true;
    return _open(directionsUri(vet));
  }

  @override
  Future<bool> openLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return Future.value(false);
    return _open(uri);
  }
}

/// A [VetLauncher] for tests: opens nothing, remembers everything.
class RecordingVetLauncher implements VetLauncher {
  final launched = <VetLaunched>[];
  bool succeeds = true;

  Future<bool> _record(VetLaunched launch) async {
    launched.add(launch);
    return succeeds;
  }

  @override
  Future<bool> call(String phone) => _record(VetLaunched(VetLaunch.call, phone));

  @override
  Future<bool> directions(VetResult vet) =>
      _record(VetLaunched(VetLaunch.directions, '${vet.location.lat},${vet.location.lng}'));

  @override
  Future<bool> openLink(String url) => _record(VetLaunched(VetLaunch.link, url));
}
