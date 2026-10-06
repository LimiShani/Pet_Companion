import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../services/care/state/care_logic.dart';
import '../../../services/care/state/care_providers.dart';
import '../health_routes.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../presentation/dashboard_card.dart';
import '../../../presentation/dashboard_state.dart';

/// The two soonest health items: today's medicine doses nobody answered
/// yet, planned visits, vaccinations and treatments. Tapping the card
/// opens the Health tab on its schedule.
class HealthCard extends ConsumerWidget {
  const HealthCard({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final value = ref.watch(upcomingHealthProvider(pet.id));
    final items = value.value;
    final shown = (items ?? const <HealthItem>[]).take(2).toList();

    return DashboardCard(
      color: AppColors.peach,
      iconAsset: 'assets/images/icon_health.svg',
      title: l10n.homeHealth,
      trailing: l10n.homeUpcoming,
      iconRing: true,
      tapLabel: context.careL10n.openHealth,
      onTap: () {
        ref.read(healthSectionProvider.notifier).show(HealthSection.schedule);
        GoRouter.maybeOf(context)?.go(HealthRoutes.root);
      },
      child: items == null
          ? HomeCardState(value: value, petId: pet.id)
          : shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.homeNoHealthEvents, style: AppText.body),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 13,
                      thickness: 1,
                      color: AppColors.white.withValues(alpha: 0.55),
                    ),
                  _ItemRow(item: shown[i]),
                ],
              ],
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final HealthItem item;

  @override
  Widget build(BuildContext context) {
    final format = AppFormat.of(context);
    final care = context.careL10n;
    final title = item.isDose ? care.medicineItem(item.title) : item.title;
    final when = item.isDose
        ? care.doseToday(format.time(item.when))
        : format.dateTime(item.when);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                  AppIcon(
                    item.isDose
                        ? Icons.schedule_rounded
                        : Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 5),
                  // "12.06.25 · 18:20": read from the right it is still date,
                  // then time.
                  Text(when, style: AppText.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
