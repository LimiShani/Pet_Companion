import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/petloop_icon.dart';
import 'dashboard_card.dart';

class FeedingCard extends StatelessWidget {
  const FeedingCard({super.key, required this.status});

  final FeedingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final goal = status.dailyGoal;
    final nextFeeding = status.nextFeeding;
    return DashboardCard(
      color: AppColors.sage,
      icon: PetLoopGlyph.food,
      title: l10n.homeFeeding,
      trailing: goal == null ? l10n.homeNoGoal : l10n.homeGoal(goal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${status.caloriesToday}', style: AppText.metric),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.homeCalToday,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: l10n.homeCaloriesSemantics,
            value: goal == null ? null : l10n.homeCaloriesOfGoal(status.caloriesToday, goal),
            child: LinearProgressIndicator(
              value: status.progress ?? 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          NextEventLine(
            text: nextFeeding == null
                ? l10n.homeNextFeedingUnset
                : l10n.homeNextFeeding(AppFormat.of(context).timeOfDay(nextFeeding)),
          ),
        ],
      ),
    );
  }
}
