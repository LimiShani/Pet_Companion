import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a seller's page outside the app. Behind an interface so tests can
/// check which link was opened without launching anything.
abstract class LinkOpener {
  /// Returns whether the link was handed to a browser.
  Future<bool> open(Uri uri);
}

/// Opens links in the device's browser with `url_launcher`.
class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => const UrlLauncherLinkOpener(),
);

/// The address to open for a deal's [link], or `null` when it is not a
/// well-formed `https` link. Anything else is never opened: deals are
/// shared by members, so the link is not trusted.
Uri? safeDealLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
