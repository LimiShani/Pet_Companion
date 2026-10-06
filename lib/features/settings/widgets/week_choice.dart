import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/choice_row.dart';

/// The week layout as two choices: the day the week starts on, and which
/// days are weekdays (the others are the weekend). Under them the seven day
/// letters in the chosen order, the weekend dimmed, so the effect of a
/// choice shows at once. Each tap is applied and remembered on the phone
/// (see [weekSettingsProvider]).
class WeekChoice extends ConsumerWidget {
  const WeekChoice({super.key});

  /// The key of the chip of a first day (an ISO weekday number).
  static Key firstDayKey(int day) => ValueKey('week-first-day-$day');

  static const sundayToThursdayKey = Key('weekdays-sunday-thursday');
  static const mondayToFridayKey = Key('weekdays-monday-friday');
  static const previewKey = Key('week-preview');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final week = ref.watch(weekSettingsProvider);
    final controller = ref.read(weekSettingsProvider.notifier);

    final firstDays = [
      (DateTime.saturday, l10n.settingsDaySaturday),
      (DateTime.sunday, l10n.settingsDaySunday),
      (DateTime.monday, l10n.settingsDayMonday),
    ];
    final weekdaySets = [
      (
        sundayToThursdayKey,
        WeekSettings.israeli.weekdays,
        l10n.settingsWeekdaysSunThu,
      ),
      (
        mondayToFridayKey,
        WeekSettings.mondayToFriday.weekdays,
        l10n.settingsWeekdaysMonFri,
      ),
    ];

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsFirstDay, style: AppText.cardTitle),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final (day, name) in firstDays)
                  ChoiceChip(
                    key: firstDayKey(day),
                    label: Text(name),
                    selected: week.firstDay == day,
                    showCheckmark: false,
                    onSelected: (_) => controller.setFirstDay(day),
                  ),
              ],
            ),
            const Divider(height: 25),
            Text(l10n.settingsWeekdays, style: AppText.cardTitle),
            for (final (key, days, name) in weekdaySets)
              ChoiceRow(
                key: key,
                title: name,
                selected: week.isWeekdays(days),
                onTap: () => controller.setWeekdays(days),
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
            const Divider(height: 25),
            _WeekPreview(key: previewKey, week: week),
          ],
        ),
      ),
    );
  }
}

/// The seven day letters in the week's order; weekend days are dimmed.
class _WeekPreview extends StatelessWidget {
  const _WeekPreview({super.key, required this.week});

  final WeekSettings week;

  @override
  Widget build(BuildContext context) {
    final format = AppFormat.of(context);
    final weekend = week
        .sorted(week.weekend)
        .map(format.weekdayShort)
        .join(', ');

    return Semantics(
      label: context.l10n.settingsWeekendIs(weekend),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (final day in week.orderedDays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DayCell(
                    letter: format.weekdayNarrow(day),
                    weekend: !week.weekdays.contains(day),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.letter, required this.weekend});

  final String letter;
  final bool weekend;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: weekend ? Colors.transparent : AppColors.yellow,
        borderRadius: BorderRadius.circular(12),
        border: weekend
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      // Scaled down rather than cut when the text is very large.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letter,
          maxLines: 1,
          style: AppText.secondary.copyWith(
            color: weekend ? AppColors.brown : AppColors.ink,
            fontWeight: weekend ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
