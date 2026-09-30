import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'choice_row.dart';

/// The language switch as a short list: one row per choice, the current one
/// marked. A tap switches the app at once and the choice is remembered on
/// the phone.
///
/// The choices are "Follow the phone", Hebrew and English, each language
/// named in its own letters. With [hebrewFollowsDeviceProvider] off (a
/// state kept for tests) there is no "Follow the phone": a phone that made
/// no choice is on English, and Hebrew carries a "Preview" tag.
class LanguageChoice extends ConsumerWidget {
  const LanguageChoice({super.key});

  /// The key of a choice's row.
  static Key keyOf(AppLanguage language) => ValueKey('language-${language.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final followsPhone = ref.watch(hebrewFollowsDeviceProvider);
    final chosen = ref.watch(appLanguageProvider);
    final selected = chosen == AppLanguage.system && !followsPhone ? AppLanguage.english : chosen;
    final phoneLanguage = resolveAppLocale(
      AppLanguage.system,
      ref.watch(deviceLocalesProvider),
      hebrewFollowsDevice: true,
    );

    final options = [if (followsPhone) AppLanguage.system, AppLanguage.hebrew, AppLanguage.english];

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options) ...[
            if (option != options.first) const Divider(indent: 16, endIndent: 16),
            ChoiceRow(
              key: keyOf(option),
              title: switch (option) {
                AppLanguage.system => l10n.languageFollowPhone,
                AppLanguage.hebrew => nativeLanguageName(hebrewLocale),
                AppLanguage.english => nativeLanguageName(englishLocale),
              },
              subtitle: option == AppLanguage.system
                  ? l10n.languageFollowPhoneNow(nativeLanguageName(phoneLanguage))
                  : null,
              tag: option == AppLanguage.hebrew && !followsPhone ? l10n.languagePreviewTag : null,
              selected: option == selected,
              onTap: () => ref.read(appLanguageProvider.notifier).choose(option),
            ),
          ],
        ],
      ),
    );
  }
}
