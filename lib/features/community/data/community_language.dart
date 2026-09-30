import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A language the Community tab's long-form content (the guides) can be
/// written in.
enum ContentLanguage {
  en('en', TextDirection.ltr),
  he('he', TextDirection.rtl);

  const ContentLanguage(this.code, this.direction);

  /// The language code, as in a `Locale`.
  final String code;

  /// The direction text in this language is read in.
  final TextDirection direction;

  /// The language for a locale's language code; English for anything the
  /// content is not written in. `iw` is the old code for Hebrew.
  static ContentLanguage fromCode(String? code) {
    final wanted = code == 'iw' ? 'he' : code;
    return values.firstWhere((language) => language.code == wanted, orElse: () => en);
  }
}

/// "Which language now?" for the Community tab's content.
///
/// English until the app has a language setting. INTEGRATION: this is the
/// one place to connect it. Make the provider follow the app's language,
/// for example
/// `ContentLanguage.fromCode(ref.watch(appLocaleProvider).languageCode)`;
/// the guides then load in that language, falling back to English with an
/// "English only" tag where a guide is not translated yet.
final communityLanguageProvider = Provider<ContentLanguage>((ref) => ContentLanguage.en);
