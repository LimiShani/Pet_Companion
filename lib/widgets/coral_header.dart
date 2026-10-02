import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// The coral page header every tab and sub-page uses, so screens built by
/// different people look like one app.
///
/// Put it first in the page body (not in `Scaffold.appBar`): it handles the
/// status-bar inset itself. [bottom] is for a pet selector, a segmented
/// control or a search field that belongs to the header.
class CoralHeader extends StatelessWidget {
  const CoralHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions = const [],
    this.bottom,
  });

  final String title;

  /// Shows a back arrow that pops the current route. The arrow mirrors by
  /// itself on a right-to-left screen (it then points right).
  final bool showBack;

  /// Usually [CoralHeaderAction]s.
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.shellRadius)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    if (showBack) ...[
                      CoralHeaderAction(
                        icon: Icons.arrow_back_rounded,
                        tooltip: context.l10n.commonBack,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.appTitle.copyWith(color: AppColors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              if (bottom != null) ...[const SizedBox(height: 12), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

/// White icon button sized for [CoralHeader.actions].
class CoralHeaderAction extends StatelessWidget {
  const CoralHeaderAction({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: AppIcon(icon, size: 24),
      color: AppColors.white,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}
