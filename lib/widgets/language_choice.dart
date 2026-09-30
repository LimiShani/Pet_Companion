import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The language switch as a short list: one row per choice, the current one
/// marked. A tap switches the app at once and the choice is remembered on
/// the phone.
///
/// The choices are Hebrew and English, each named in its own letters, plus
/// "Follow the phone" once Hebrew follows the phone's language (see
/// [hebrewFollowsDeviceProvider]). Until then a phone that made no choice
/// is simply on English, and Hebrew carries a "Preview" tag.
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
            _Option(
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

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.tag,
  });

  final String title;
  final String? subtitle;
  final String? tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _RadioDot(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppText.secondary.copyWith(color: AppColors.brown),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: const ShapeDecoration(color: AppColors.yellow, shape: StadiumBorder()),
                    child: Text(tag!, style: AppText.label.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.coralDark : AppColors.brown,
          width: selected ? 7 : 2,
        ),
      ),
    );
  }
}
