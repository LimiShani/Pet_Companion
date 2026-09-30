import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../health_format.dart';

/// The weekday chips of the medicine and routine forms (Monday first).
class DaysPicker extends StatelessWidget {
  const DaysPicker({super.key, required this.days, required this.onChanged});

  /// ISO weekdays: Monday = 1 ... Sunday = 7.
  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                key: ValueKey('day-$day'),
                label: Text(dayName(day)),
                selected: days.contains(day),
                showCheckmark: false,
                onSelected: (selected) => onChanged({
                  for (final d in days)
                    if (d != day) d,
                  if (selected) day,
                }),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          days.isEmpty ? 'Choose at least one day.' : formatDays(days),
          style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
