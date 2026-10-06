import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import 'auth_banner.dart';
import 'language_pill.dart';

/// Shared frame of the auth screens: the illustrated PetLoop banner on top
/// ([AuthBanner]), then the form on the cream background. Scrolls when the
/// keyboard is open.
///
/// The row over the banner holds the back arrow (at the start, when
/// [showBack]) and the language pill (at the end), so the language can be
/// changed before signing in.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // The illustrated banner with the logo, announced by name.
                Semantics(
                  label: l10n.appName,
                  header: true,
                  child: ExcludeSemantics(
                    child: AuthBanner(showBird: !showBack),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        8,
                        AppSpacing.screen,
                        0,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            if (showBack)
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                tooltip: l10n.commonBack,
                                // Mirrors by itself on a right-to-left screen.
                                icon: const AppIcon(Icons.arrow_back_rounded),
                                color: AppColors.white,
                                // A disc like the language pill's, so the
                                // arrow reads over the leaves.
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.onCoralPill,
                                  side: const BorderSide(
                                    color: AppColors.onCoralOutline,
                                    width: 2,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                              ),
                            const Spacer(),
                            const LanguagePill(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                28,
                AppSpacing.screen,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppText.petName),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppText.body.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 22),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
