import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../health_format.dart';
import '../health_strings.dart';

/// The weekday chips of the medicine and routine forms.
///
/// They follow the owner's week (Settings, [weekSettingsProvider]): the
/// chips start on its first day, and the line under them says "Weekdays" or
/// "Weekends" for the days that week calls so.
class DaysPicker extends ConsumerWidget {
  const DaysPicker({super.key, required this.days, required this.onChanged});

  /// ISO weekdays: Monday = 1 ... Sunday = 7.
  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekSettingsProvider);
    final l10n = context.healthL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final day in week.orderedDays)
              FilterChip(
                key: ValueKey('day-$day'),
                label: Text(l10n.dayChip(day)),
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
          days.isEmpty ? l10n.chooseAtLeastOneDay : HealthFormat.of(context).days(days, week),
          style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
