import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';

/// Shared shell of the feeding / activity / health cards: colored rounded
/// box, illustrated icon disc at the start (an SVG drawing), content after
/// it (mirrored by itself on a right-to-left screen).
///
/// Every Home card follows one contract (this shell, `MoneyCard` and the
/// first 30 days card alike):
///
/// * a 64 px illustrated icon at the start;
/// * the title owns its line ([CardTitleRow]): it is never cut short;
/// * at most one small label beside the title, when it fits (else under it);
/// * one metric block (a number, a progress bar, or one invitation line);
/// * at most one pill, always the house outlined pill (`CarePillButton`
///   with `filled: true`), at the end of the last line ([CardActionRow],
///   which drops it under the line when both do not fit);
/// * a card with nothing to do has no pill, and the whole card is the
///   button ([onTap]).
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
            border: iconRing
                ? Border.all(
                    color: AppColors.white.withValues(alpha: 0.6),
                    width: 3,
                  )
                : null,
          ),
          child: ClipOval(
            child: SvgPicture.asset(
              iconAsset,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardTitleRow(title: title, trailing: trailing),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// The first line of a card: the title, and a small label after it
/// ("Goal 1,030 cal/day", "Upcoming", "All the home") when there is room.
/// The title owns its line: a label that does not fit beside it moves
/// under it instead of cutting the title short.
class CardTitleRow extends StatelessWidget {
  const CardTitleRow({
    super.key,
    required this.title,
    this.trailing,
    this.labelBelow = false,
  });

  final String title;
  final String? trailing;

  /// Always put the label on its own line under the title (a label that
  /// names the scope of the whole card, "All the home").
  final bool labelBelow;

  @override
  Widget build(BuildContext context) {
    final label = trailing;
    final titleText = Text(title, style: AppText.cardTitle, softWrap: true);
    if (label == null) return titleText;
    final labelStyle = AppText.label.copyWith(fontWeight: FontWeight.w600);
    Widget below() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleText,
        const SizedBox(height: 2),
        Text(label, style: labelStyle, softWrap: true),
      ],
    );
    if (labelBelow) return below();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        // Measured as the Text widgets draw it: on top of the inherited
        // style (its letter spacing widens the line by a few pixels).
        final inherited = DefaultTextStyle.of(context).style;
        double width(String s, TextStyle style) => (TextPainter(
          text: TextSpan(text: s, style: inherited.merge(style)),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width;
        final fits =
            width(title, AppText.cardTitle) + 8 + width(label, labelStyle) + 4 <=
            constraints.maxWidth;
        if (!fits) return below();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: titleText),
            const SizedBox(width: 8),
            Text(label, style: labelStyle, softWrap: true),
          ],
        );
      },
    );
  }
}

/// "Next feeding · 19:30" style line with a small clock. [text] is the
/// whole line, already in the screen's language.
class NextEventLine extends StatelessWidget {
  const NextEventLine({super.key, required this.text, this.maxLines = 1});

  final String text;

  /// Lines the text may take before it is cut short.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppIcon(Icons.schedule_rounded, size: 15, color: AppColors.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppText.body,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
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
  const CardActionRow({
    super.key,
    required String this.text,
    required this.actionLabel,
    required this.action,
    this.maxLines = 1,
  });

  /// Only the action, at the end of its own line (under a card's
  /// invitation, "Add walk times to follow the activity.").
  const CardActionRow.alone({super.key, required this.action})
    : text = null,
      actionLabel = '',
      maxLines = 1;

  /// The whole line next to the clock, as in [NextEventLine].
  final String? text;

  /// The action's label, measured to decide whether both fit.
  final String actionLabel;
  final Widget action;

  /// Lines the text may take before it is cut short, once the action has
  /// moved under it (beside the action it is always one line).
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    if (text == null) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: action);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        // On top of the inherited style, as the Text widgets draw it.
        final inherited = DefaultTextStyle.of(context).style;
        double width(String s, TextStyle style) => (TextPainter(
          text: TextSpan(text: s, style: inherited.merge(style)),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width;
        // Clock and gap, the text; the pill's padding and border.
        final lineWidth = 21 + width(text, AppText.body);
        final actionWidth = 31 + width(actionLabel, AppText.button(14));
        // A margin for what the measure cannot see (the font fallback the
        // screen really uses, rounding): better under the line than cut.
        if (lineWidth + 8 + actionWidth + 16 <= constraints.maxWidth) {
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
            NextEventLine(text: text, maxLines: maxLines),
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}
