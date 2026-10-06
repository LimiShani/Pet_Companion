import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the app asked the phone to open.
enum ContactAction { call, textMessage, whatsApp, map }

/// One request handed to a [ContactLauncher] (what tests inspect).
class LaunchedContact {
  const LaunchedContact(this.action, this.target, [this.body = '']);

  final ContactAction action;

  /// The phone number, or the address for [ContactAction.map].
  final String target;

  /// The pre-filled message text (empty for calls and maps).
  final String body;

  @override
  String toString() =>
      'LaunchedContact(${action.name}, $target${body.isEmpty ? '' : ', "$body"'})';
}

/// Opens the phone's dialler, messaging app, WhatsApp or maps with
/// everything filled in. It never calls or sends anything itself: the
/// owner always presses the last button in the other app.
///
/// Behind an interface so tests can check what would have been opened.
/// Every method returns whether the other app was opened.
abstract class ContactLauncher {
  Future<bool> call(String phone);
  Future<bool> textMessage(String phone, String body);
  Future<bool> whatsApp(String phone, String body);
  Future<bool> openMap(String address);
}

/// [phone] reduced to what a dialler understands: digits and a leading "+".
String dialable(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp('[^0-9]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

Uri telUri(String phone) => Uri(scheme: 'tel', path: dialable(phone));

/// A text message to [phone] with [body] already typed.
Uri smsUri(String phone, String body) =>
    Uri.parse('sms:${dialable(phone)}?body=${Uri.encodeComponent(body)}');

/// A WhatsApp chat with [phone] (which must include the country code) with
/// [body] already typed.
Uri whatsAppUri(String phone, String body) => Uri.parse(
  'https://wa.me/${dialable(phone).replaceAll('+', '')}?text=${Uri.encodeComponent(body)}',
);

/// A maps search for [address].
Uri mapUri(String address) => Uri.parse(
  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}',
);

/// [ContactLauncher] on `url_launcher`. It launches and handles failure
/// rather than asking first, so no platform manifest entries are needed.
class UrlLauncherContactLauncher implements ContactLauncher {
  const UrlLauncherContactLauncher();

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
  Future<bool> textMessage(String phone, String body) =>
      _open(smsUri(phone, body));

  @override
  Future<bool> whatsApp(String phone, String body) =>
      _open(whatsAppUri(phone, body));

  @override
  Future<bool> openMap(String address) => _open(mapUri(address));
}

final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => const UrlLauncherContactLauncher(),
);

/// A [ContactLauncher] for widget tests: opens nothing and remembers every
/// request in [calls]. Set [succeeds] to false to simulate a phone that
/// cannot open the other app.
class RecordingContactLauncher implements ContactLauncher {
  final calls = <LaunchedContact>[];
  bool succeeds = true;

  Future<bool> _record(LaunchedContact contact) async {
    calls.add(contact);
    return succeeds;
  }

  @override
  Future<bool> call(String phone) =>
      _record(LaunchedContact(ContactAction.call, phone));

  @override
  Future<bool> textMessage(String phone, String body) =>
      _record(LaunchedContact(ContactAction.textMessage, phone, body));

  @override
  Future<bool> whatsApp(String phone, String body) =>
      _record(LaunchedContact(ContactAction.whatsApp, phone, body));

  @override
  Future<bool> openMap(String address) =>
      _record(LaunchedContact(ContactAction.map, address));
}
