import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import 'language_pill.dart';

/// Shared frame of the auth screens: coral top with the paw mark and a
/// title, then the form on the cream background. Scrolls when the
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
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: AppColors.white,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                              ),
                            const Spacer(),
                            const LanguagePill(),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.white, width: 4),
                          ),
                          child: const Icon(Icons.pets_rounded, size: 40, color: AppColors.coralDark),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.appName,
                        textAlign: TextAlign.center,
                        style: AppText.appTitle.copyWith(color: AppColors.white, fontSize: 26),
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
