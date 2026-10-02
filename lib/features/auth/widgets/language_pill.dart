import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_icon.dart';

/// The language switch of the sign-in and sign-up screens: a small pill on
/// the coral header showing the *other* language in its own letters
/// ("עברית" on an English screen, "English" on a Hebrew one). One tap
/// switches the app at once and the choice is remembered on the phone.
class LanguagePill extends ConsumerWidget {
  const LanguagePill({super.key});

  static const pillKey = Key('language-pill');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toHebrew = !isHebrew(ref.watch(appLocaleProvider));
    final name = nativeLanguageName(toHebrew ? hebrewLocale : englishLocale);

    return Semantics(
      button: true,
      label: context.l10n.languageSwitchTo(name),
      excludeSemantics: true,
      child: InkWell(
        key: pillKey,
        customBorder: const StadiumBorder(),
        onTap: () => ref.read(appLanguageProvider.notifier).choose(toHebrew ? AppLanguage.hebrew : AppLanguage.english),
        // The pill is 36 px tall inside a 44 px tap target.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsetsDirectional.only(start: 10, end: 14),
              decoration: const ShapeDecoration(
                color: AppColors.onCoralPill,
                shape: StadiumBorder(side: BorderSide(color: AppColors.onCoralOutline, width: 2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(Icons.language_rounded, size: 18, color: AppColors.white),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
