import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import 'dashboard_card.dart';

class FeedingCard extends StatelessWidget {
  const FeedingCard({super.key, required this.status});

  final FeedingStatus status;

  @override
  Widget build(BuildContext context) {
    final goal = status.dailyGoal;
    return DashboardCard(
      color: AppColors.sage,
      iconAsset: 'assets/images/icon_feeding.png',
      title: 'Feeding',
      trailing: goal == null ? 'No goal set' : 'Goal $goal cal/day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${status.caloriesToday}', style: AppText.metric),
              const SizedBox(width: 6),
              const Flexible(
                child: Text('cal today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Calories toward daily goal',
            value: goal == null ? null : '${status.caloriesToday} of $goal',
            child: LinearProgressIndicator(
              value: status.progress ?? 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          NextEventLine(label: 'Next feeding', time: status.nextFeeding),
        ],
      ),
    );
  }
}
