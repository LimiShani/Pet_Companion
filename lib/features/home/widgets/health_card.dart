import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import 'dashboard_card.dart';

class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.events});

  final List<HealthEvent> events;

  static final _date = DateFormat('dd.MM.yy');
  static final _time = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final upcoming = [...events]..sort((a, b) => a.when.compareTo(b.when));
    final shown = upcoming.take(2).toList();

    return DashboardCard(
      color: AppColors.peach,
      iconAsset: 'assets/images/icon_health.png',
      title: 'Health',
      trailing: 'Upcoming',
      iconRing: true,
      child: shown.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No health events yet', style: AppText.body),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) Divider(height: 13, thickness: 1, color: AppColors.white.withValues(alpha: 0.55)),
                  _EventRow(event: shown[i]),
                ],
              ],
            ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final HealthEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(event.title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.ink),
        const SizedBox(width: 5),
        Text(
          '${HealthCard._date.format(event.when)} · ${HealthCard._time.format(event.when)}',
          style: AppText.secondary,
        ),
      ],
    );
  }
}
