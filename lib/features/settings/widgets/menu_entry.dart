import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

/// A row that leads somewhere: an icon disc, a title with a quieter line
/// under it, and a chevron at the end. Used by the side menu and by the
/// "Settings" row of the account sheet. The chevron mirrors by itself on a
/// right-to-left screen.
class MenuEntry extends StatelessWidget {
  const MenuEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = Colors.transparent,
  });

  /// An [Icon] or a [PetLoopIcon]; drawn 22 px in ink on a yellow disc.
  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// The row's own background; transparent on a menu, white as a card.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
                    child: IconTheme.merge(
                      data: const IconThemeData(size: 22, color: AppColors.ink),
                      child: Center(child: icon),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: AppText.secondary.copyWith(color: AppColors.brown),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
