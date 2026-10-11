import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
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
    bool? showAccount,
    this.actions = const [],
    this.bottom,
  }) : showAccount = showAccount ?? !showBack;

  final String title;

  /// Shows a back arrow that pops the current route. The arrow mirrors by
  /// itself on a right-to-left screen (it then points right).
  final bool showBack;

  /// Ends the row with the avatar of the signed-in account, which opens the
  /// You page ([HeaderAvatar]). On by default at the root of a tab (no back
  /// arrow), off on a sub-page; a root that must not have it passes false.
  final bool showAccount;

  /// Usually [CoralHeaderAction]s.
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.shellRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            8,
            AppSpacing.screen,
            16,
          ),
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
                        style: AppText.appTitle.copyWith(
                          color: AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...actions,
                    if (showAccount) ...[
                      const SizedBox(width: 8),
                      const HeaderAvatar(),
                    ],
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
  const CoralHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

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

/// The 40 px yellow circle with the initial of the signed-in account, at
/// the end of a header row (every tab's, and Home's top bar). A tap opens
/// the You page above the current tab. Announced as "You".
class HeaderAvatar extends ConsumerWidget {
  const HeaderAvatar({super.key});

  static const size = 40.0;

  /// The location of the You page (`SettingsRoutes.you` is this). The
  /// page is pushed on the app's router, so it opens on the root navigator
  /// above the tabs; a header shown on its own, outside the router (a
  /// test), has nowhere to go.
  static const route = '/you';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final label = context.l10n.youTitle;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.yellow,
          shape: CircleBorder(
            side: BorderSide(
              color: AppColors.white.withValues(alpha: 0.85),
              width: 2,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: user == null
                ? null
                : () => GoRouter.maybeOf(context)?.push<void>(route),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: ExcludeSemantics(
                  child: Text(
                    user?.initial ?? '?',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
