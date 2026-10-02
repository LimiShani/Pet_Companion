import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/petloop_icon.dart';
import 'dashboard_card.dart';

class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.events});

  final List<HealthEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final upcoming = [...events]..sort((a, b) => a.when.compareTo(b.when));
    final shown = upcoming.take(2).toList();

    return DashboardCard(
      color: AppColors.peach,
      icon: PetLoopGlyph.health,
      title: l10n.homeHealth,
      trailing: l10n.homeUpcoming,
      iconRing: true,
      child: shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.homeNoHealthEvents, style: AppText.body),
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
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Text(event.title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          // The date keeps its natural size and the title takes the rest.
          // Only when the date alone would take most of the row (a narrow
          // phone with very large text) is it scaled down to fit.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.65),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.ink),
                  const SizedBox(width: 5),
                  // "12.06.25 · 18:20": read from the right it is still date,
                  // then time.
                  Text(AppFormat.of(context).dateTime(event.when), style: AppText.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
