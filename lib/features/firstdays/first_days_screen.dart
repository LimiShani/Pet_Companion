import '../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../presentation/care_widgets.dart';
import '../../presentation/health_strings.dart';
import '../../presentation/health_widgets.dart';
import '../../presentation/pets_widgets.dart';
import '../../services/firstdays/data/first_days_models.dart';
import '../../services/firstdays/data/first_days_tasks.dart';
import 'first_days_actions.dart';
import 'first_days_words.dart';
import '../../services/firstdays/state/first_days_logic.dart';
import '../../services/firstdays/state/first_days_providers.dart';
import 'widgets/first_days_keeper.dart';

/// Opens the first 30 days of the pet with [petId] over the whole app.
Future<void> openFirstDays(BuildContext context, String petId) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => FirstDaysScreen(petId: petId)));

/// "The first 30 days · Mitzi": the arrival day, the day of the path, the
/// progress, and the tasks of the first week and of weeks 2 to 4. Each task
/// has a tick and, when the app can do it, a pill that opens the screen
/// that does it. Once the path is closed or over, the page is a read-only
/// summary.
class FirstDaysScreen extends ConsumerWidget {
  const FirstDaysScreen({super.key, required this.petId});

  static const screenKey = Key('first-days-screen');
  static const closeKey = Key('first-days-close');

  /// The tick of the task with [id].
  static Key tickKey(String id) => Key('first-days-tick-$id');

  /// The pill of the task with [id].
  static Key actionKey(String id) => Key('first-days-action-$id');

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'firstdays.view',
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
    final value = ref.watch(firstDaysViewProvider(petId));
    final l10n = context.firstDaysL10n;

    final Widget body;
    if (value.hasError) {
      body = HealthLoadError(
        title: l10n.loadFailed,
        error: value.error!,
        onRetry: () => ref.invalidate(firstDaysProvider(petId)),
      );
    } else if (!value.hasValue) {
      body = const HealthLoading();
    } else if (value.value == null) {
      body = Padding(
        padding: const EdgeInsets.only(top: 16),
        child: PetsNote(l10n.notStarted(pet.name)),
      );
    } else {
      body = _Body(view: value.value!);
    }

    return FirstDaysKeeper(
      petId: petId,
      child: CarePage(
        key: screenKey,
        petId: petId,
        title: l10n.pageTitle(pet.name),
        child: body,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.view});

  final FirstDaysView view;

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final l10n = context.firstDaysL10n;
    final confirmed = await confirmDelete(
      context,
      title: l10n.closeQuestion,
      message: l10n.closeMessage(view.pet.name),
      confirmLabel: l10n.closeConfirm,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(firstDaysProvider(view.pet.id).notifier).close();
    } catch (error) {
      if (context.mounted) {
        showHealthSnack(context, healthErrorOf(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'firstdays.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.firstDaysL10n;
    final format = AppFormat.of(context);
    final stage = view.stage;
    final closedAt = view.path.closedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        CareBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.arrivedOn(format.date(view.path.arrivedOn)),
                style: AppText.secondary,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      view.hasEnded
                          ? (closedAt != null
                                ? l10n.closedOn(format.date(closedAt))
                                : l10n.overLine)
                          : l10n.dayOfTotal(
                              format.integer(view.shownDay),
                              format.integer(firstDaysLength),
                            ),
                      style: AppText.cardTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.doneCount(
                      '${format.integer(view.doneCount)}/${format.integer(view.total)}',
                    ),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CareProgress(value: view.progress, color: AppColors.sage),
              if (stage == FirstDaysStage.finished) ...[
                const SizedBox(height: 8),
                Text(l10n.allDoneLine, style: AppText.secondary),
              ],
              if (view.hasEnded) ...[
                const SizedBox(height: 8),
                Text(l10n.summaryNote, style: AppText.secondary),
              ],
            ],
          ),
        ),
        for (final week in FirstDaysWeek.values)
          if (view.itemsOf(week).isNotEmpty) ...[
            CareSectionLabel(
              week == FirstDaysWeek.first ? l10n.firstWeek : l10n.laterWeeks,
            ),
            for (final item in view.itemsOf(week))
              _TaskRow(view: view, item: item),
          ],
        if (!view.hasEnded) ...[
          const SizedBox(height: 12),
          PetsTextButton(
            l10n.closePath,
            key: FirstDaysScreen.closeKey,
            onPressed: () => _close(context, ref),
          ),
        ],
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.view, required this.item});

  final FirstDaysView view;
  final FirstDaysItem item;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(firstDaysProvider(view.pet.id).notifier)
          .setDone(item.task.id, done: !item.ticked);
    } catch (error) {
      if (context.mounted) {
        showHealthSnack(context, healthErrorOf(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'firstdays.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.firstDaysL10n;
    final task = item.task;
    final action = task.action;
    final readOnly = view.hasEnded;
    final canToggle = !readOnly && !item.onlyAuto;

    final tick = Semantics(
      button: canToggle,
      checked: item.isDone,
      label: item.isDone ? l10n.markNotDone : l10n.markDone,
      excludeSemantics: true,
      child: InkResponse(
        key: FirstDaysScreen.tickKey(task.id),
        onTap: canToggle ? () => _toggle(context, ref) : null,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            item.isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 24,
            color: item.isDone
                ? AppColors.sage
                : AppColors.brown.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstDaysTaskText(l10n, task.id),
          style: AppText.body.copyWith(
            color: item.isDone ? AppColors.brown : AppColors.ink,
          ),
        ),
        if (item.autoDone)
          Text(
            l10n.tickedForYou,
            style: AppText.secondary.copyWith(fontSize: 12),
          ),
      ],
    );
    final label = action == null || readOnly
        ? null
        : firstDaysActionLabel(l10n, action.kind);
    final pill = label == null
        ? null
        : CarePillButton(
            key: FirstDaysScreen.actionKey(task.id),
            label: label,
            onPressed: () => runFirstDaysAction(context, view.pet, action!),
          );

    return CareBox(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 10, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The pill sits at the end of the row while the text keeps at
          // least 120 px; otherwise (a narrow phone, large text) under it.
          var pillBeside = true;
          if (label != null) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: AppText.button(14)),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            pillBeside =
                constraints.maxWidth - 48 - 8 - (painter.width + 31) >= 120;
            painter.dispose();
          }
          return Row(
            crossAxisAlignment: pillBeside
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              tick,
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: pillBeside || pill == null
                      ? words
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            words,
                            const SizedBox(height: 6),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: pill,
                            ),
                          ],
                        ),
                ),
              ),
              if (pillBeside && pill != null) ...[
                const SizedBox(width: 8),
                pill,
              ],
            ],
          );
        },
      ),
    );
  }
}
