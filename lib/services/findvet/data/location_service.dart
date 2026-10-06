import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../regions/region.dart';

/// How asking for the phone's location ended.
enum LocationOutcome {
  /// A fix: see [LocationResult.point].
  found,

  /// The owner said no (this time).
  denied,

  /// The owner said "never": only the phone's settings can change it.
  deniedForever,

  /// Location is switched off on the phone.
  serviceOff,

  /// No fix in time, or the phone could not tell.
  unavailable,
}

class LocationResult {
  const LocationResult(this.outcome, {this.point, this.accuracyM});

  final LocationOutcome outcome;
  final GeoPoint? point;

  /// How far off the fix may be, in metres.
  final double? accuracyM;
}

/// The phone's location, asked for only when the owner taps "Use my
/// location" (after the screen has said why). Behind an interface so
/// tests choose the answer.
abstract class LocationService {
  /// Asks for permission if needed, then for one fix. Never throws.
  Future<LocationResult> current();

  /// Opens the phone's settings where location access can be granted
  /// again (after "never", or when location is off).
  Future<bool> openSettings(LocationOutcome outcome);
}

/// [LocationService] on the `geolocator` package. Only one fix is taken:
/// no tracking, nothing kept.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({
    this.timeLimit = const Duration(seconds: 12),
  });

  final Duration timeLimit;

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationOutcome.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationResult(LocationOutcome.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        // City-block accuracy is plenty to rank vets, and comes faster.
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeLimit,
        ),
      );
      return LocationResult(
        LocationOutcome.found,
        point: GeoPoint(position.latitude, position.longitude),
        accuracyM: position.accuracy,
      );
    } on TimeoutException {
      return const LocationResult(LocationOutcome.unavailable);
    } catch (_) {
      return const LocationResult(LocationOutcome.unavailable);
    }
  }

  @override
  Future<bool> openSettings(LocationOutcome outcome) async {
    try {
      return outcome == LocationOutcome.serviceOff
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

/// A [LocationService] for tests: answers [result] and counts the asks.
class FakeLocationService implements LocationService {
  FakeLocationService([
    this.result = const LocationResult(LocationOutcome.denied),
  ]);

  LocationResult result;
  int asked = 0;
  final settingsOpened = <LocationOutcome>[];

  @override
  Future<LocationResult> current() async {
    asked++;
    return result;
  }

  @override
  Future<bool> openSettings(LocationOutcome outcome) async {
    settingsOpened.add(outcome);
    return true;
  }
}
