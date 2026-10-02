import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/petloop_icon.dart';
import 'dashboard_card.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.status});

  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = AppFormat.of(context);
    final steps = format.integer(status.steps);
    final time = format.hoursMinutes(status.activeTime);
    final nextWalk = status.nextWalk;

    return DashboardCard(
      color: AppColors.yellow,
      icon: PetLoopGlyph.activity,
      title: l10n.homeActivity,
      iconRing: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(value: steps, label: l10n.homeSteps),
              ),
              Container(width: 2, height: 40, color: AppColors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(value: time, label: l10n.homeActivityTime),
              ),
            ],
          ),
          const SizedBox(height: 6),
          NextEventLine(
            text: nextWalk == null ? l10n.homeNextWalkUnset : l10n.homeNextWalk(format.timeOfDay(nextWalk)),
          ),
        ],
      ),
    );
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
        Text(value, style: AppText.metricSmall),
        Text(label, style: AppText.label.copyWith(color: AppColors.brown)),
      ],
    );
  }
}
