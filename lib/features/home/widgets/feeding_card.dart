import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../care/care.dart';
import 'dashboard_card.dart';

/// Today's calories toward the goal, the next feeding, and a "Fed" button.
/// Tapping the card opens the feeding page.
class FeedingCard extends ConsumerWidget {
  const FeedingCard({super.key, required this.pet});

  static const fedKey = Key('home-fed');

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final care = context.careL10n;
    final value = ref.watch(feedingDayProvider(pet.id));
    final day = value.value;
    final goal = day?.goal;

    return DashboardCard(
      color: AppColors.sage,
      iconAsset: 'assets/images/icon_feeding.svg',
      title: l10n.homeFeeding,
      trailing: day == null
          ? null
          : (goal == null ? l10n.homeNoGoal : l10n.homeGoal(AppFormat.of(context).integer(goal))),
      onTap: () => openFeeding(context, pet),
      tapLabel: care.openFeeding,
      child: day == null
          ? HomeCardState(value: value, petId: pet.id)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (day.hasFood) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(AppFormat.of(context).integer(day.calories), style: AppText.metric),
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
                    value: goal == null ? null : l10n.homeCaloriesOfGoal(day.calories, goal),
                    child: LinearProgressIndicator(
                      value: day.progress ?? 0,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ] else
                  Text(care.addFoodToCount, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                CardActionRow(
                  text: nextFeedingText(context, day.next),
                  actionLabel: care.fed,
                  action: CarePillButton(
                    key: fedKey,
                    label: care.fed,
                    filled: true,
                    onPressed: () => showLogMealSheet(context, pet),
                  ),
                ),
              ],
            ),
    );
  }

  static String nextFeedingText(BuildContext context, NextUp? next) {
    final l10n = context.l10n;
    if (next == null) return l10n.homeNextFeedingUnset;
    final time = AppFormat.of(context).time(next.entry.time);
    return next.tomorrow ? context.careL10n.nextFeedingTomorrow(time) : l10n.homeNextFeeding(time);
  }
}

/// A Home card's body while its data loads, or when it could not load
/// (tap to try again).
class HomeCardState extends ConsumerWidget {
  const HomeCardState({super.key, required this.value, required this.petId});

  final AsyncValue<Object?> value;
  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (value.hasError) {
      return InkWell(
        onTap: () => retryCare(ref, petId),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(context.careL10n.loadFailed, style: AppText.body),
        ),
      );
    }
    // A quiet blank of the body's height: the data is usually there in a
    // moment, and a spinner on every card would only flicker.
    return const SizedBox(height: 56);
  }
}
