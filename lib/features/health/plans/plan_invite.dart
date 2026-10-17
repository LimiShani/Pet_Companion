import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../presentation/health_widgets.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/area_disc.dart';
import 'yearly_plan_sheet.dart';

/// The Health Overview's invitation to the yearly plan, while [pet] has
/// no vaccination on record: one sentence and one link.
class PlanInviteCard extends StatelessWidget {
  const PlanInviteCard({super.key, required this.pet});

  static const cardKey = Key('overview-plan-invite');
  static const actionKey = Key('overview-plan-invite-action');

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthPlanL10n;
    return HealthCard(
      key: cardKey,
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 8,
        top: 12,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AreaDisc(Icons.event_note_rounded, area: AppArea.health),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.planInvite(pet.name),
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: HealthLink(
                    l10n.planInviteAction,
                    key: actionKey,
                    padding: 0,
                    onPressed: () => showYearlyPlan(context, pet),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
