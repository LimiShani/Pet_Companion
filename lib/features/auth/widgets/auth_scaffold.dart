import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/brand.dart';
import 'language_pill.dart';

/// Shared frame of the auth screens: coral top with the PetLoop logo, then the form on the cream background. Scrolls when the
/// keyboard is open.
///
/// The top row holds the back arrow (at the start, when [showBack]) and the
/// language pill (at the end), so the language can be changed before
/// signing in.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.showBack = false});

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
            Container(
              decoration: const BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.headerRadius)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            if (showBack)
                              IconButton(
                                onPressed: () => Navigator.of(context).maybePop(),
                                tooltip: l10n.commonBack,
                                // Mirrors by itself on a right-to-left screen.
                                icon: const AppIcon(Icons.arrow_back_rounded),
                                color: AppColors.white,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                              ),
                            const Spacer(),
                            const LanguagePill(),
                          ],
                        ),
                      ),
                      // The full-colour mark on its cream tile, as on the
                      // launcher icon, then the lettering in white.
                      Semantics(
                        label: l10n.appName,
                        header: true,
                        child: Column(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: AppColors.white, width: 3),
                              ),
                              child: const PetLoopMark(size: 64),
                            ),
                            const SizedBox(height: 14),
                            const PetLoopWordmark(height: 34, tone: BrandTone.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 28, AppSpacing.screen, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppText.petName),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppText.body.copyWith(color: AppColors.brown)),
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
