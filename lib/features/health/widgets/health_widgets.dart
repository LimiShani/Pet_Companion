import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../state/health_keeper.dart';

/// Minimum size of anything tappable in Health.
const kHealthTapTarget = 48.0;

/// The line shown wherever the app offers to call or message someone.
const kSafetyLine = 'Pet Companion never contacts anyone on its own, and it does not replace veterinary advice.';

/// A section heading with an optional count pill and a trailing action.
class HealthSectionTitle extends StatelessWidget {
  const HealthSectionTitle(this.title, {super.key, this.count, this.detail, this.trailing});

  final String title;
  final int? count;

  /// Quieter text after the title ("· Tue 10 June").
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text('$count', style: AppText.label.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                detail!,
                style: AppText.secondary.copyWith(color: AppColors.brown),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A round icon disc, as on the home dashboard cards.
class IconDisc extends StatelessWidget {
  const IconDisc(this.icon, {super.key, this.size = 40, this.color = AppColors.yellow, this.iconColor = AppColors.ink});

  final IconData icon;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.55, color: iconColor),
    );
  }
}

/// A rounded card. White by default; peach for the tab's accent surface.
class HealthCard extends StatelessWidget {
  const HealthCard({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.radius = AppSpacing.surfaceRadius,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// A dashed-looking prompt card inviting the owner to add something.
class HealthPromptCard extends StatelessWidget {
  const HealthPromptCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
        side: const BorderSide(color: AppColors.peach, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconDisc(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    Text(message, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small text link with an optional icon, at least 48 px tall.
class HealthLink extends StatelessWidget {
  const HealthLink(this.label, {super.key, required this.onPressed, this.icon, this.color = AppColors.coralDark});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return icon == null
        ? TextButton(onPressed: onPressed, style: style, child: text)
        : TextButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: text);
  }
}

/// A label above a value, for detail cards ("Date given / 14.03.25").
class LabeledValue extends StatelessWidget {
  const LabeledValue(this.label, this.value, {super.key, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label.copyWith(color: AppColors.brown)),
          const SizedBox(height: 2),
          Text(value, style: AppText.cardTitle),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A small rounded tag ("Next due 14.03.26", "Paused", "WhatsApp").
class HealthTag extends StatelessWidget {
  const HealthTag(this.label, {super.key, this.icon, this.highlight = false});

  final String label;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? AppColors.yellow : AppColors.cream,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: highlight ? AppColors.yellow : const Color(0xFFE7D9B5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: highlight ? AppColors.ink : AppColors.brown),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppText.label.copyWith(color: highlight ? AppColors.ink : AppColors.brown),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet line under forms and sheets.
class FinePrint extends StatelessWidget {
  const FinePrint(this.text, {super.key, this.center = true});

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

/// A tappable field that shows a value picked elsewhere (a date, a time).
class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.placeholder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Shows a clear button when set.
  final VoidCallback? onClear;

  /// Draws [value] as a hint (nothing chosen yet).
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 8, bottom: 8),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.brown, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppText.label.copyWith(color: AppColors.brown),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          value,
                          style: AppText.body.copyWith(
                            fontSize: 16,
                            color: placeholder ? AppColors.brown.withValues(alpha: 0.55) : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      onPressed: onClear,
                      tooltip: 'Clear $label',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.brown,
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small brown caption above a group of form fields.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16, bottom: 6, start: 2),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
    );
  }
}

/// A full page over the tab: coral header with a back arrow, then a
/// scrolling body. Used by every Health form and detail page.
class HealthPage extends StatelessWidget {
  const HealthPage({super.key, required this.title, required this.child, this.actions = const [], this.petId});

  final String title;
  final List<Widget> actions;
  final Widget child;

  /// The pet whose health data the page reads and changes. When set, that
  /// data stays loaded and up to date for as long as the page is open,
  /// wherever it was opened from.
  final String? petId;

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      body: Column(
        children: [
          CoralHeader(title: title, showBack: true, actions: actions),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                8,
                AppSpacing.screen,
                24 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
    final id = petId;
    return id == null ? page : HealthKeeper(petId: id, keep: HealthKeep.everything, child: page);
  }
}

/// Pushes [page] over the whole app (above the bottom bar).
Future<T?> pushHealthPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(builder: (_) => page));

/// Opens [child] as a bottom sheet over the whole app. The sheet scrolls
/// and stays above the keyboard.
Future<T?> showHealthSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => HealthSheetBody(child: child),
  );
}

/// The scrolling frame of a Health bottom sheet.
class HealthSheetBody extends StatelessWidget {
  const HealthSheetBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 24 + media.viewInsets.bottom),
        child: child,
      ),
    );
  }
}

/// The title of a bottom sheet.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.petName.copyWith(fontSize: 20)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppText.secondary.copyWith(color: AppColors.brown)),
        ],
      ],
    );
  }
}

/// Asks before something is deleted. Returns whether the owner confirmed.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A short message at the bottom of the screen, with an optional action.
void showHealthSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

/// The loading state of a section.
class HealthLoading extends StatelessWidget {
  const HealthLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// The "could not load" state of a section, with a retry button.
class HealthLoadError extends StatelessWidget {
  const HealthLoadError({super.key, required this.what, required this.message, required this.onRetry});

  /// What failed to load, e.g. "the schedule".
  final String what;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load $what',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
