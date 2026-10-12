import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon.dart';
import 'health_widgets.dart';

/// A full-width "More details" button under the fields most people fill
/// first, with the rest of a long form folded below it.
///
/// The folded [child] stays mounted while it is closed (offstage and out of
/// the focus order), so its fields keep their state and their validators
/// still run: a form opens the fold itself when a field in it is wrong
/// ([scrollToOnceOpen]).
class MoreDetails extends StatelessWidget {
  const MoreDetails({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.moreLabel,
    this.fewerLabel,
  });

  /// The "More details" / "Fewer details" button.
  static const toggleKey = Key('more-details-toggle');

  /// How long the fold takes to open or close.
  static const duration = Duration(milliseconds: 200);

  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  /// The button's words in the caller's own strings ("More details" /
  /// "Fewer details"); Health's when left out.
  final String? moreLabel;
  final String? fewerLabel;

  /// Scrolls the field under [anchor] into view once a fold that was just
  /// opened has grown to its full height.
  static Future<void> scrollToOnceOpen(GlobalKey anchor) async {
    await Future<void>.delayed(duration);
    final target = anchor.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          child: TextButton.icon(
            key: toggleKey,
            onPressed: onToggle,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.coralDark,
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            iconAlignment: IconAlignment.end,
            icon: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: duration,
              child: const AppIcon(Icons.expand_more_rounded, size: 20),
            ),
            label: Text(
              expanded
                  ? fewerLabel ?? l10n.formFewerDetails
                  : moreLabel ?? l10n.formMoreDetails,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Offstage(
            offstage: !expanded,
            child: TickerMode(
              enabled: expanded,
              child: ExcludeFocus(excluding: !expanded, child: child),
            ),
          ),
        ),
      ],
    );
  }
}
