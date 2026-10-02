import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../care/care.dart';
import 'dashboard_card.dart';
import 'feeding_card.dart';

/// Today's walks (or play sessions for a pet that is not a dog) and
/// active minutes, the next walk, and a "Walk" button. While a walk runs
/// the last line shows its clock and Finish. Tapping the card opens the
/// activity page.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.pet});

  static const walkKey = Key('home-walk');

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final care = context.careL10n;
    final format = AppFormat.of(context);
    final value = ref.watch(activityDayProvider(pet.id));
    final day = value.value;
    final walks = walksPet(pet.species);
    final running = ref.watch(runningWalkProvider(pet.id)) != null;

    return DashboardCard(
      color: AppColors.yellow,
      iconAsset: 'assets/images/icon_activity.svg',
      title: l10n.homeActivity,
      iconRing: true,
      onTap: () => openActivity(context, pet),
      tapLabel: care.openActivity,
      child: day == null
          ? HomeCardState(value: value, petId: pet.id)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        value: '${format.integer(day.done)}/${format.integer(day.planned)}',
                        label: walks ? care.walksTodayLabel : care.playTodayLabel,
                      ),
                    ),
                    Container(width: 2, height: 40, color: AppColors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(value: format.integer(day.minutes), label: care.minutesLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (running)
                  RunningWalkBox(pet: pet, onCard: true)
                else
                  CardActionRow(
                    text: _nextLine(context, day),
                    actionLabel: walks ? care.walkAction : care.playAction,
                    action: CarePillButton(
                      key: walkKey,
                      label: walks ? care.walkAction : care.playAction,
                      filled: true,
                      onPressed: () => showWalkSheet(context, pet),
                    ),
                  ),
              ],
            ),
    );
  }

  String _nextLine(BuildContext context, ActivityDay day) {
    final l10n = context.l10n;
    final care = context.careL10n;
    final format = AppFormat.of(context);
    final next = day.next;
    if (next != null) {
      final time = format.time(next.entry.time);
      return next.tomorrow ? care.nextWalkTomorrow(time) : l10n.homeNextWalk(time);
    }
    // A pet that does not go for walks has no walk times to wait for.
    if (!walksPet(pet.species)) return care.goalMinutesLine(format.integer(day.goalMinutes));
    return l10n.homeNextWalkUnset;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isolate(value), style: AppText.metricSmall),
        Text(label, style: AppText.label.copyWith(color: AppColors.brown), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
