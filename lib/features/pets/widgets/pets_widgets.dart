import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';

/// Minimum size of anything tappable in the pets pages.
const kPetsTapTarget = 48.0;

/// The line colour of chips, dividers and dashed outlines.
const kPetsLine = Color(0xFFE7D9B5);

/// A full page of the pets feature: the coral header and a scrolling body.
class PetsPage extends StatelessWidget {
  const PetsPage({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.headerBottom,
  });

  final String title;
  final Widget child;
  final bool showBack;

  /// What the back arrow does; the default pops the page.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? headerBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _Header(title: title, showBack: showBack, onBack: onBack, actions: actions, bottom: headerBottom),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                18,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// [CoralHeader] with a back arrow that can do something other than pop.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.showBack, this.onBack, this.actions = const [], this.bottom});

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    if (onBack == null || !showBack) {
      return CoralHeader(title: title, showBack: showBack, actions: actions, bottom: bottom);
    }
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
                    CoralHeaderAction(icon: Icons.arrow_back_rounded, tooltip: context.l10n.commonBack, onPressed: onBack),
                    const SizedBox(width: 4),
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

/// A text action on the coral header ("Finish later", "My pets").
class HeaderTextAction extends StatelessWidget {
  const HeaderTextAction(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Material(
        color: AppColors.onCoralPill,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.onCoralOutline, width: 2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Step 2 of 4" bar under the header of the add-a-pet flow.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, this.total = 4});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.petsL10n.stepOf(step, total),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.white : AppColors.white.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 6),
            Text(
              context.petsL10n.stepOf(step, total),
              style: AppText.secondary.copyWith(color: AppColors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A page title inside the body ("Who is joining the family?").
class PetsHeading extends StatelessWidget {
  const PetsHeading(this.text, {super.key, this.center = false, this.size = 20});

  final String text;
  final bool center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2),
    );
  }
}

/// Quiet explanatory text under a heading.
class PetsNote extends StatelessWidget {
  const PetsNote(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: AppText.secondary.copyWith(color: AppColors.brown),
    );
  }
}

/// Small print at the end of a page.
class PetsFinePrint extends StatelessWidget {
  const PetsFinePrint(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
    );
  }
}

/// How important a field is, shown as a small tag beside its label.
enum FieldLevel { essential, optional }

/// The label above a field or a group of chips, with an optional
/// "Essential" / "Optional" tag.
class PetsLabel extends StatelessWidget {
  const PetsLabel(this.text, {super.key, this.level, this.topGap = 18});

  final String text;
  final FieldLevel? level;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(text, style: AppText.secondary.copyWith(color: AppColors.brown, fontWeight: FontWeight.w800)),
          if (level == FieldLevel.essential) PetsTag(context.petsL10n.tagEssential, tone: TagTone.yellow),
          if (level == FieldLevel.optional) PetsTag(context.petsL10n.tagOptional),
        ],
      ),
    );
  }
}

enum TagTone { plain, yellow, green }

/// A small rounded tag: "Essential", "Complete", "2 essentials to add".
class PetsTag extends StatelessWidget {
  const PetsTag(this.text, {super.key, this.tone = TagTone.plain, this.icon});

  final String text;
  final TagTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (tone) {
      TagTone.plain => (AppColors.white, kPetsLine, AppColors.brown),
      TagTone.yellow => (AppColors.yellow, AppColors.yellow, AppColors.ink),
      TagTone.green => (AppColors.sage, AppColors.sage, AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[AppIcon(icon, size: 13, color: foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round yellow disc with an icon, as on the dashboard cards.
class PetsDisc extends StatelessWidget {
  const PetsDisc(this.icon, {super.key, this.size = 40, this.color = AppColors.yellow});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: AppIcon(icon, size: size * 0.52, color: AppColors.ink),
    );
  }
}

/// A white rounded card; tappable when [onTap] is given.
class PetsCard extends StatelessWidget {
  const PetsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.color = AppColors.white,
    this.shadow = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool shadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.surfaceRadius);
    final card = Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    final decorated = shadow
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [BoxShadow(color: Color(0x1A5B4636), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: card,
          )
        : card;
    if (semanticLabel == null) return decorated;
    // Its own node, read before what is inside the card.
    return Semantics(container: true, explicitChildNodes: true, label: semanticLabel, child: decorated);
  }
}

/// A row with a leading widget, a title, an optional second line and a
/// trailing widget, in a white card: the list rows of the pets pages.
class PetsRow extends StatelessWidget {
  const PetsRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dashed = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// An invitation rather than a fact: a dashed outline, no fill.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kPetsTapTarget - 20),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.cardTitle),
                if (subtitle != null)
                  Text(subtitle!, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    if (!dashed) return PetsCard(onTap: onTap, padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10), child: content);
    return CustomPaint(
      painter: const _DashedOutline(),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12), child: content),
        ),
      ),
    );
  }
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1),
        const Radius.circular(AppSpacing.surfaceRadius),
      ));
    final paint = Paint()
      ..color = const Color(0xFFD9C28C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = 7.0, gap = 5.0;
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        canvas.drawPath(metric.extractPath(at, (at + dash).clamp(0, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => false;
}

/// Answered (a sage tick) or still open (a dashed ring).
class AnswerMark extends StatelessWidget {
  const AnswerMark({super.key, required this.answered});

  final bool answered;

  @override
  Widget build(BuildContext context) {
    if (answered) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
        child: const AppIcon(Icons.check_rounded, size: 18, color: AppColors.ink),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brown.withValues(alpha: 0.7), width: 2),
      ),
    );
  }
}

/// A small filled pill button ("Add", "Add now").
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onPressed, this.icon, this.outlined = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    final text = AppText.button(13);
    const size = Size(kPetsTapTarget, 40);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[AppIcon(icon, size: 16), const SizedBox(width: 6)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    return outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(padding: padding, textStyle: text, minimumSize: size),
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(padding: padding, textStyle: text, minimumSize: size),
            child: child,
          );
  }
}

/// A centred text button ("Skip for now", "Sign out").
class PetsTextButton extends StatelessWidget {
  const PetsTextButton(this.label, {super.key, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(minimumSize: const Size(kPetsTapTarget, kPetsTapTarget));
    return Center(
      child: icon == null
          ? TextButton(onPressed: onPressed, style: style, child: Text(label, textAlign: TextAlign.center))
          : TextButton.icon(
              onPressed: onPressed,
              style: style,
              icon: AppIcon(icon, size: 18),
              label: Text(label, textAlign: TextAlign.center),
            ),
    );
  }
}

/// A full-width outlined pill button ("Add another pet", "Archive Soya").
class PetsOutlineButton extends StatelessWidget {
  const PetsOutlineButton(this.label, {super.key, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50));
    final text = Text(label, textAlign: TextAlign.center);
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: text)
        : OutlinedButton.icon(onPressed: onPressed, style: style, icon: AppIcon(icon, size: 18), label: text);
  }
}

/// One choice out of a few, as rounded chips ("Male", "Female", "Not sure").
/// Tapping the chosen chip again clears the answer when [allowClear] is set.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.allowClear = true,
  });

  final List<T> options;
  final String Function(T option) labelOf;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: option == selected,
            showCheckmark: false,
            onSelected: (chosen) {
              if (chosen) {
                onSelected(option);
              } else if (allowClear) {
                onSelected(null);
              }
            },
          ),
      ],
    );
  }
}

/// A two-way switch in a white pill ("I know the date" / "About…").
class TwoWaySwitch extends StatelessWidget {
  const TwoWaySwitch({
    super.key,
    required this.first,
    required this.second,
    required this.secondSelected,
    required this.onChanged,
  });

  final String first;
  final String second;
  final bool secondSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget side(String label, bool selected, bool value) => Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected ? AppColors.yellow : Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected ? AppColors.ink : AppColors.brown,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.all(Radius.circular(999))),
      child: Row(children: [side(first, !secondSelected, false), side(second, secondSelected, true)]),
    );
  }
}

/// Pushes [page] over everything, without the bottom bar.
Future<T?> pushPetsPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(builder: (_) => page));

/// Shows [child] as a bottom sheet over everything. The sheet scrolls when
/// its content is taller than the screen.
Future<T?> showPetsSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    ),
  );
}

/// A snack bar with [message], replacing the one on screen.
void showPetsSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
