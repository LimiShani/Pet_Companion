import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../platform/link_opener.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The sign-up line "By creating an account you agree to the Terms of Use
/// and Privacy Policy", with the two names as links to the published
/// pages in the app's language.
///
/// The strings file marks the two links with square brackets, in that
/// order; a translation that lost them shows as plain text.
class LegalNotice extends ConsumerWidget {
  const LegalNotice({super.key});

  static const termsKey = Key('legal-notice-terms');
  static const privacyKey = Key('legal-notice-privacy');

  static final _link = RegExp(r'\[([^\]]+)\]');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final style = AppText.label.copyWith(
      color: AppColors.brown,
      fontWeight: FontWeight.w600,
    );
    final linkStyle = style.copyWith(
      color: AppColors.coralDark,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.coralDark,
    );
    final text = l10n.authTerms;
    final matches = _link.allMatches(text).toList();
    if (matches.length < 2) {
      return Text(
        text.replaceAll('[', '').replaceAll(']', ''),
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final pages = [
      (LegalNotice.termsKey, AppConfig.termsUrl(language)),
      (LegalNotice.privacyKey, AppConfig.privacyUrl(language)),
    ];
    final spans = <InlineSpan>[];
    var at = 0;
    for (var i = 0; i < 2; i++) {
      final match = matches[i];
      if (match.start > at) spans.add(TextSpan(text: text.substring(at, match.start)));
      final (key, url) = pages[i];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            link: true,
            child: GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(linkOpenerProvider).open(url),
              child: Text(match.group(1)!, style: linkStyle),
            ),
          ),
        ),
      );
      at = match.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.center,
    );
  }
}
