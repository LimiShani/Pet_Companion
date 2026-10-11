import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/app_tag.dart';
import '../community_words.dart';
import '../../../services/community/data/audience.dart';

/// The tag for an item that is for one animal; nothing for what is shared
/// by everyone.
Widget? tagForAudience(CommunityL10n l10n, Audience audience) {
  final label = l10n.audienceTag(audience);
  if (label == null) return null;
  return AppTag(
    label,
    tone: switch (audience) {
      Audience.cats => AppTagTone.sage,
      Audience.dogs => AppTagTone.peach,
      _ => AppTagTone.yellow,
    },
  );
}

/// Marks a guide shown in English because it has no text in the reader's
/// language yet.
Widget tagEnglishOnly(CommunityL10n l10n) =>
    AppTag(l10n.tagEnglishOnly, icon: Icons.translate_rounded);

/// Marks a guide with a professional review that still applies.
Widget tagReviewed(CommunityL10n l10n) => AppTag(
  l10n.tagReviewed,
  tone: AppTagTone.sage,
  icon: Icons.verified_user_rounded,
);
