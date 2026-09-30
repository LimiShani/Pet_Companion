import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import 'dashboard_card.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.status});

  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = NumberFormat.decimalPattern().format(status.steps);
    final h = status.activeTime.inHours;
    final m = status.activeTime.inMinutes.remainder(60);
    final time = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return DashboardCard(
      color: AppColors.yellow,
      iconAsset: 'assets/images/icon_activity.png',
      title: 'Activity',
      iconRing: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(value: steps, label: 'Steps'),
              ),
              Container(width: 2, height: 40, color: AppColors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(value: time, label: 'Activity time'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          NextEventLine(label: 'Next walk', time: status.nextWalk),
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
