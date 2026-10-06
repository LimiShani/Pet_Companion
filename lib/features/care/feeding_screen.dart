import '../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/pet_records/data/health_models.dart';
import '../../presentation/health_strings.dart';
import '../../presentation/schedule/routine_form_screen.dart';
import '../../services/pet_records/state/health_providers.dart';
import '../../presentation/health_widgets.dart';
import 'food_settings_screen.dart';
import 'log_meal_sheet.dart';
import '../../services/care/state/care_logic.dart';
import '../../services/care/state/care_providers.dart';
import '../../presentation/care_widgets.dart';

/// Opens the feeding page of [pet] over the whole app.
Future<void> openFeeding(BuildContext context, Pet pet) =>
    pushHealthPage<void>(context, FeedingScreen(petId: pet.id));

/// Today's meals, the week's calories, the food and the meal times.
class FeedingScreen extends ConsumerWidget {
  const FeedingScreen({super.key, required this.petId});

  static const screenKey = Key('feeding-screen');

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'care.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.careL10n;
    final pet = ref.watch(
      petsProvider.select(
        (pets) => pets.firstWhere((p) => p.id == petId, orElse: () => Pet.none),
      ),
    );
    return CarePage(
      key: screenKey,
      petId: petId,
      title: l10n.feedingTitle(pet.name),
      child: CareAsync(
        value: ref.watch(feedingDayProvider(petId)),
        petId: petId,
        builder: (day) => _Body(pet: pet, day: day),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.pet, required this.day});

  final Pet pet;
  final FeedingDay day;

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CareEntry entry,
  ) async {
    final l10n = context.careL10n;
    final confirmed = await confirmDelete(
      context,
      title: l10n.removeEntry,
      message: l10n.removeEntryQuestion,
      confirmLabel: l10n.remove,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(carePlanProvider(pet.id).notifier).removeLog(entry.log!);
    } catch (error) {
      if (context.mounted) {
        showHealthSnack(context, healthErrorOf(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'care.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.careL10n;
    final format = AppFormat.of(context);
    final goal = day.goal;
    final settings = day.settings;
    final plannedTimes = [
      for (final item
          in ref.watch(carePlanProvider(pet.id)).value?.items ??
              const <CarePlanItem>[])
        if (item.kind == CareKind.feeding && item.active) item,
    ]..sort((a, b) => minutesOf(a.time).compareTo(minutesOf(b.time)));
    // Today is not over yet: the average is of the six days before it.
    final before = day.week.take(day.week.length - 1);
    final average = (before.fold(0, (sum, d) => sum + d.value) / before.length)
        .round();

    String? detail(CareEntry e) {
      final log = e.log;
      if (log == null) return null;
      if (!e.isDone) return l10n.mealNotEaten;
      final grams = log.amountGrams;
      final calories = log.calories;
      if (grams != null && calories != null) {
        return l10n.mealAmount(format.decimal(grams), format.integer(calories));
      }
      if (grams != null) return l10n.gramsValue(format.decimal(grams));
      return l10n.mealDone;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        CareBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.today,
                      style: AppText.cardTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  Text(
                    goal == null
                        ? l10n.caloriesOnly(format.integer(day.calories))
                        : l10n.caloriesOfGoal(
                            format.integer(day.calories),
                            format.integer(goal),
                          ),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CareProgress(value: day.progress ?? 0),
              if (!day.hasFood) ...[
                const SizedBox(height: 8),
                Text(l10n.addFoodToCount, style: AppText.secondary),
              ],
            ],
          ),
        ),
        if (day.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Text(l10n.noMealsToday, style: AppText.secondary),
          ),
        for (final meal in day.meals)
          CareEntryTile(
            entry: meal,
            detail: detail(meal),
            actionLabel: l10n.fed,
            onAction: () => showLogMealSheet(context, pet, entry: meal),
            onRemove: () => _remove(context, ref, meal),
          ),
        CareAddLine(
          label: l10n.extraMeal,
          onTap: () => showLogMealSheet(context, pet, entry: null),
        ),
        CareSectionLabel(l10n.thisWeek),
        CareBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WeekBars(week: day.week, color: AppColors.sage, goal: goal),
              const SizedBox(height: 6),
              Text(
                goal == null
                    ? l10n.weekAverageLine(format.integer(average))
                    : l10n.weekGoalLine(
                        format.integer(goal),
                        format.integer(average),
                      ),
                style: AppText.secondary,
              ),
            ],
          ),
        ),
        CareSectionLabel(l10n.foodAndPortion),
        CareLinkRow(
          title: settings.foodName.isEmpty
              ? l10n.foodAndPortion
              : settings.foodName,
          summary: settings.hasFood
              ? [
                  l10n.foodSummary(format.decimal(settings.kcalPer100g!)),
                  if (settings.portionGrams != null)
                    l10n.portionSummary(format.decimal(settings.portionGrams!)),
                ].join(' · ')
              : l10n.addFoodToCount,
          onTap: () => openFoodSettings(context, pet),
        ),
        CareSectionLabel(l10n.mealTimes),
        for (final item in plannedTimes)
          CareLinkRow(
            title: format.timeOfDay(item.time),
            summary: item.title,
            onTap: () => openRoutineForm(context, pet, item: item),
          ),
        if (plannedTimes.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(l10n.noMealTimes, style: AppText.secondary),
          ),
        CareAddLine(
          label: l10n.addMealTime,
          onTap: () => openRoutineForm(context, pet, kind: CareKind.feeding),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: Text(l10n.sameAsSchedule, style: AppText.secondary),
        ),
      ],
    );
  }
}
