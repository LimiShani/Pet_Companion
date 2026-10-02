import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

/// Shared shell of the feeding / activity / health cards: colored rounded
/// box, illustrated icon disc at the start (an SVG drawing), content after
/// it (mirrored by itself on a right-to-left screen).
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.color,
    required this.iconAsset,
    required this.title,
    required this.child,
    this.trailing,
    this.iconRing = false,
    this.onTap,
    this.tapLabel,
  });

  final Color color;
  final String iconAsset;
  final String title;

  /// Small text at the top end of the card (goal, "Upcoming"...).
  final String? trailing;
  final Widget child;

  /// Draw a faint white ring around the icon disc (used where the disc's
  /// yellow would otherwise blend into the card).
  final bool iconRing;

  /// Opens the card's page.
  final VoidCallback? onTap;

  /// What tapping the card does, for screen readers ("Open feeding").
  final String? tapLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.cardRadius);
    return Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          onTapHint: tapLabel,
          child: Padding(padding: AppSpacing.card, child: _content()),
        ),
      ),
    );
  }

  Widget _content() {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: iconRing ? Border.all(color: AppColors.white.withValues(alpha: 0.6), width: 3) : null,
          ),
          child: ClipOval(child: SvgPicture.asset(iconAsset, fit: BoxFit.cover, excludeFromSemantics: true)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(title, style: AppText.cardTitle),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trailing!,
                        style: AppText.label.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// "Next feeding · 19:30" style line with a small clock. [text] is the
/// whole line, already in the screen's language.
class NextEventLine extends StatelessWidget {
  const NextEventLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppIcon(Icons.schedule_rounded, size: 15, color: AppColors.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// The last line of a card: [line] at the start and the card's quick
/// action at the end. When both do not fit on one row (a long "tomorrow"
/// line, a narrow phone, large text), the action moves under the line, to
/// the end, rather than cutting the line short.
class CardActionRow extends StatelessWidget {
  const CardActionRow({super.key, required this.text, required this.actionLabel, required this.action});

  /// The whole line next to the clock, as in [NextEventLine].
  final String text;

  /// The action's label, measured to decide whether both fit.
  final String actionLabel;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        double width(String s, TextStyle style) =>
            (TextPainter(text: TextSpan(text: s, style: style), textDirection: direction, textScaler: scaler, maxLines: 1)
                  ..layout())
                .width;
        // Clock and gap, the text; the pill's padding and border.
        final lineWidth = 21 + width(text, AppText.body);
        final actionWidth = 31 + width(actionLabel, AppText.button(14));
        if (lineWidth + 8 + actionWidth <= constraints.maxWidth) {
          return Row(
            children: [
              Expanded(child: NextEventLine(text: text)),
              const SizedBox(width: 8),
              action,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NextEventLine(text: text),
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}
