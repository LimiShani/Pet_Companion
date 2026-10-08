import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web page in the phone's browser (the legal pages today).
///
/// Behind an interface so tests can check which page would have opened.
/// Returns whether the browser was opened.
abstract class LinkOpener {
  Future<bool> open(Uri url);
}

/// [LinkOpener] on `url_launcher`: launches and reports failure rather
/// than asking first, so no platform manifest entries are needed.
class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => const UrlLauncherLinkOpener(),
);

/// A [LinkOpener] for widget tests: opens nothing and remembers every
/// page in [opened].
class RecordingLinkOpener implements LinkOpener {
  final opened = <Uri>[];
  bool succeeds = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}
