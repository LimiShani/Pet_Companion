import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// One row of a pick-one list (a language, a week layout): a round mark,
/// the title, an optional quieter line under it and an optional small tag
/// at the end. The row is at least 52 px tall and mirrors by itself on a
/// right-to-left screen.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.tag,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final String title;
  final String? subtitle;
  final String? tag;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                ChoiceMark(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppText.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppText.secondary.copyWith(
                            color: AppColors.brown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    decoration: const ShapeDecoration(
                      color: AppColors.yellow,
                      shape: StadiumBorder(),
                    ),
                    child: Text(
                      tag!,
                      style: AppText.label.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round mark of a [ChoiceRow]: filled when chosen.
class ChoiceMark extends StatelessWidget {
  const ChoiceMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.coralDark : AppColors.brown,
          width: selected ? 7 : 2,
        ),
      ),
    );
  }
}
