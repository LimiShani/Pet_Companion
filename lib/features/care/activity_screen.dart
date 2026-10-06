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
import '../../services/care/data/care_models.dart';
import '../../services/care/state/care_logic.dart';
import '../../services/care/state/care_providers.dart';
import 'walk_sheet.dart';
import '../../presentation/care_widgets.dart';

/// Opens the activity page of [pet] over the whole app.
Future<void> openActivity(BuildContext context, Pet pet) =>
    pushHealthPage<void>(context, ActivityScreen(petId: pet.id));

/// Today's walks (or play), the week's minutes, the goal and the walk
/// times.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key, required this.petId});

  static const screenKey = Key('activity-screen');

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'care.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(
      petsProvider.select(
        (pets) => pets.firstWhere((p) => p.id == petId, orElse: () => Pet.none),
      ),
    );
    return CarePage(
      key: screenKey,
      petId: petId,
      title: context.careL10n.activityTitle(pet.name),
      child: CareAsync(
        value: ref.watch(activityDayProvider(petId)),
        petId: petId,
        builder: (day) => _Body(pet: pet, day: day),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.pet, required this.day});

  final Pet pet;
  final ActivityDay day;

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
    final walks = walksPet(pet.species);
    final running = ref.watch(runningWalkProvider(pet.id));
    final plannedTimes = [
      for (final item
          in ref.watch(carePlanProvider(pet.id)).value?.items ??
              const <CarePlanItem>[])
        if (item.kind == CareKind.walk && item.active) item,
    ]..sort((a, b) => minutesOf(a.time).compareTo(minutesOf(b.time)));

    String? detail(CareEntry e) {
      final log = e.log;
      if (log == null) return null;
      if (!e.isDone) return l10n.skipped;
      final minutes = log.minutes;
      return minutes == null
          ? l10n.mealDone
          : l10n.minutesValue(format.integer(minutes));
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
                    l10n.minutesOfGoal(
                      format.integer(day.minutes),
                      format.integer(day.goalMinutes),
                    ),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CareProgress(value: day.progress, color: AppColors.coralDark),
            ],
          ),
        ),
        if (running != null) RunningWalkBox(pet: pet),
        if (day.walks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Text(
              walks ? l10n.noWalksToday : l10n.noPlayToday,
              style: AppText.secondary,
            ),
          ),
        for (final walk in day.walks)
          CareEntryTile(
            entry: walk,
            detail: detail(walk),
            actionLabel: l10n.start,
            onAction: () => showWalkSheet(context, pet, entry: walk),
            onRemove: () => _remove(context, ref, walk),
          ),
        CareAddLine(
          label: walks ? l10n.extraWalk : l10n.extraPlay,
          onTap: () => showWalkSheet(context, pet),
        ),
        CareSectionLabel(l10n.weekMinutes),
        CareBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WeekBars(
                week: day.week,
                color: AppColors.yellow,
                goal: day.goalMinutes,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.goalMinutesLine(format.integer(day.goalMinutes)),
                style: AppText.secondary,
              ),
            ],
          ),
        ),
        CareSectionLabel(l10n.activityGoal),
        CareLinkRow(
          title: l10n.goalMinutesLine(format.integer(day.goalMinutes)),
          summary: l10n.goalSheetTitle,
          onTap: () => _editGoal(context, ref),
        ),
        if (walks) ...[
          CareSectionLabel(l10n.walkTimes),
          for (final item in plannedTimes)
            CareLinkRow(
              title: format.timeOfDay(item.time),
              summary: item.title,
              onTap: () => openRoutineForm(context, pet, item: item),
            ),
          if (plannedTimes.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(l10n.noWalkTimes, style: AppText.secondary),
            ),
          CareAddLine(
            label: l10n.addWalkTime,
            onTap: () => openRoutineForm(context, pet, kind: CareKind.walk),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: Text(l10n.sameAsSchedule, style: AppText.secondary),
          ),
        ],
      ],
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref) async {
    final chosen = await showHealthSheet<int>(
      context,
      _GoalSheet(current: day.goalMinutes),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await ref
          .read(careSettingsProvider(pet.id).notifier)
          .save(day.settings.copyWith(activityGoalMinutes: chosen));
    } catch (error) {
      if (context.mounted) {
        showHealthSnack(context, healthErrorOf(context, error));
      }
    }
  }
}

class _GoalSheet extends StatelessWidget {
  const _GoalSheet({required this.current});

  final int current;

  static const _choices = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'care.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.careL10n;
    final format = AppFormat.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(l10n.goalSheetTitle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _choices)
              ChoiceChip(
                label: Text(l10n.minutesValue(format.integer(m))),
                selected: m == current,
                onSelected: (_) => Navigator.of(context).pop(m),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Walking · 12:04" with Finish, shown while a walk runs. Ticks every
/// second while it is on screen.
class RunningWalkBox extends ConsumerStatefulWidget {
  const RunningWalkBox({super.key, required this.pet, this.onCard = false});

  static const finishKey = Key('walk-finish');

  final Pet pet;

  /// Drawn inside Home's yellow card rather than as a white block.
  final bool onCard;

  @override
  ConsumerState<RunningWalkBox> createState() => _RunningWalkBoxState();
}

class _RunningWalkBoxState extends ConsumerState<RunningWalkBox> {
  late final Stream<int> _ticks = Stream.periodic(
    const Duration(seconds: 1),
    (i) => i,
  );

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'care.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final walk = ref.watch(runningWalkProvider(widget.pet.id));
    if (walk == null) return const SizedBox.shrink();
    final l10n = context.careL10n;
    final walks = walksPet(widget.pet.species);
    final line = StreamBuilder<int>(
      stream: TickerMode.of(context) ? _ticks : null,
      builder: (context, _) {
        final elapsed = ref
            .read(healthClockProvider)()
            .difference(walk.startedAt);
        final safe = elapsed.isNegative ? Duration.zero : elapsed;
        final text =
            '${safe.inMinutes.toString().padLeft(2, '0')}:${(safe.inSeconds % 60).toString().padLeft(2, '0')}';
        return Text(
          walks
              ? l10n.walkRunning(isolate(text))
              : l10n.playRunning(isolate(text)),
          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
    // On the narrow card there is room for the clock and Finish only; the
    // walk is cancelled from the activity page.
    final row = Row(
      children: [
        if (!widget.onCard) ...[
          const Icon(Icons.directions_walk_rounded, color: AppColors.coralDark),
          const SizedBox(width: 8),
        ],
        Expanded(child: line),
        if (!widget.onCard)
          TextButton(
            onPressed: () =>
                ref.read(runningWalkProvider(widget.pet.id).notifier).clear(),
            child: Text(l10n.cancel),
          ),
        const SizedBox(width: 8),
        CarePillButton(
          key: RunningWalkBox.finishKey,
          label: l10n.finish,
          filled: true,
          onPressed: () => finishWalk(context, ref, widget.pet),
        ),
      ],
    );
    if (widget.onCard) return row;
    return CareBox(child: row);
  }
}
