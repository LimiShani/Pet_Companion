import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../access/access_provider.dart';
import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../platform/feature_ui.dart';
import '../../presentation/care_widgets.dart' show CarePillButton;
import '../../presentation/dashboard_card.dart' show CardTitleRow;
import '../../presentation/first_days_words.dart';
import '../../presentation/health_strings.dart';
import '../../presentation/schedule/routine_form_screen.dart';
import '../../services/budget/state/budget_providers.dart';
import '../../services/care/data/care_models.dart';
import '../../services/care/state/care_logic.dart';
import '../../services/pet_records/data/health_models.dart';
import '../../services/pet_records/state/health_providers.dart';
import '../../services/today/today_providers.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_area.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/area_disc.dart';

/// Home's "Today" card, right under the hero: the day of every pet in one
/// list (meals, walks, routines, doses; the basket products running low,
/// the first 30 days' next step and a profile to finish), with a tick to
/// do or a chevron to open. See `docs/improvement_plan.md` (1a · Today).
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  static const cardKey = Key('today-card');
  static const setUpKey = Key('today-set-up-feeding');
  static const foldKey = Key('today-fold');

  /// The tick of the row with [id] ([TodayItem.id]).
  static Key tickKey(String id) => ValueKey('today-tick-$id');

  /// The row with [id] ([TodayItem.id]).
  static Key rowKey(String id) => ValueKey('today-row-$id');

  /// The chevron of a row with [id] that only opens a page.
  static Key chevronKey(String id) => ValueKey('today-chevron-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.todayL10n;
    final value = ref.watch(todayProvider);
    final day = value.value;
    final Widget body;
    String? line;
    if (day == null) {
      body = value.hasError
          ? InkWell(
              onTap: () => retryToday(ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.loadFailed, style: AppText.body),
              ),
            )
          // A quiet blank while the plans load: a spinner would only
          // flicker.
          : const SizedBox(height: 48);
    } else {
      final progress = todayProgress(day.items);
      final date = _dayLabel(context, day.now);
      line = progress.total == 0
          ? date
          : l10n.headerDone(date, progress.done, progress.total);
      body = day.isEmpty ? const _EmptyDay() : _TodayList(day: day);
    }

    return _TodayKeeper(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        child: Material(
          key: cardKey,
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: CardTitleRow(title: l10n.title, trailing: line),
                ),
                const SizedBox(height: 4),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Tue 10 June" / "יום ג׳ 10 ביוני".
  static String _dayLabel(BuildContext context, DateTime now) {
    final locale = AppFormat.of(context).localeName;
    try {
      return DateFormat('EEE d MMMM', locale).format(now);
    } catch (_) {
      // Before the date symbols are loaded (a plain unit test).
      return AppFormat.of(context).date(now);
    }
  }
}

/// Keeps the Today list's data active while Home is covered by a page
/// (the feeding page, a sheet's page), for the reason given on
/// `HealthKeeper`: what is logged up there must reach the list at once,
/// not in the middle of the frame that uncovers Home.
class _TodayKeeper extends StatefulWidget {
  const _TodayKeeper({required this.child});

  final Widget child;

  @override
  State<_TodayKeeper> createState() => _TodayKeeperState();
}

class _TodayKeeperState extends State<_TodayKeeper> {
  ProviderContainer? _container;
  ProviderSubscription<AsyncValue<TodayDay>>? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _subscription?.close();
      _subscription = container.listen(todayProvider, (_, _) {});
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The rows: what is to do, then the undated ones, then what is done
/// (folded into one "N done" row when there are many).
class _TodayList extends StatefulWidget {
  const _TodayList({required this.day});

  final TodayDay day;

  @override
  State<_TodayList> createState() => _TodayListState();
}

class _TodayListState extends State<_TodayList> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final open = [
      for (final item in day.items)
        if (!item.isDone) item,
    ];
    final done = [
      for (final item in day.items)
        if (item.isDone) item,
    ];
    final folds = todayFoldsDone(done.length);
    Widget row(TodayItem item) => TodayRow(
      key: TodayCard.rowKey(item.id),
      item: item,
      now: day.now,
      namePet: day.petCount > 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in open) row(item),
        if (folds)
          _FoldRow(
            count: done.length,
            open: _showDone,
            onTap: () => setState(() => _showDone = !_showDone),
          ),
        if (!folds || _showDone)
          for (final item in done) row(item),
      ],
    );
  }
}

class _FoldRow extends StatelessWidget {
  const _FoldRow({required this.count, required this.open, required this.onTap});

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.todayL10n;
    return Semantics(
      button: true,
      expanded: open,
      onTapHint: open ? l10n.hideDone : l10n.showDone,
      child: InkWell(
        key: TodayCard.foldKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              const AreaDisc(Icons.done_all_rounded, area: AppArea.care),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.foldDone(count),
                  style: AppText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: AppIcon(
                  open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.brown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Nothing planned today." and, for a pet without meal times, "Set up
/// feeding" (the selected pet's feeding page).
class _EmptyDay extends ConsumerWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.todayL10n;
    final pet = ref.watch(selectedPetProvider);
    final plan = pet.id.isEmpty
        ? null
        : ref.watch(carePlanProvider(pet.id)).value;
    final noMeals =
        plan != null && !plan.items.any((i) => i.kind == CareKind.feeding);
    final canSetUp = noMeals && ref.watch(capabilityProvider('care.edit'));
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.empty,
            style: AppText.body.copyWith(color: AppColors.brown),
          ),
          if (canSetUp) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CarePillButton(
                key: TodayCard.setUpKey,
                label: l10n.setUpFeeding,
                onPressed: () => openFeature<Object>(context, 'feeding', pet.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of the Today list: a disc in its area's colour, the title (with
/// the pet's name when the account has several pets), when and who, and
/// one control at the end: a tick for something to do (filled once done),
/// or a chevron for a row that only opens a page.
///
/// Tapping the rest of the row opens what it is about (the meal, walk or
/// dose sheet, the routine, the basket, the first 30 days, the checklist).
class TodayRow extends ConsumerStatefulWidget {
  const TodayRow({
    super.key,
    required this.item,
    required this.now,
    required this.namePet,
  });

  final TodayItem item;

  /// When the list was worked out (what the row shows; a tick reads the
  /// clock again).
  final DateTime now;

  /// Add the pet's name to the title.
  final bool namePet;

  /// The ticked row's opacity.
  static const doneOpacity = 0.62;

  @override
  ConsumerState<TodayRow> createState() => _TodayRowState();
}

class _TodayRowState extends ConsumerState<TodayRow> {
  bool _busy = false;

  TodayItem get _item => widget.item;

  Pet? _pet() {
    for (final pet in ref.read(petsProvider)) {
      if (pet.id == _item.petId) return pet;
    }
    return null;
  }

  /// What a tick needs: the meal or walk the care pages log, else the
  /// Schedule's.
  String get _editCapability =>
      _item.kind == TodayKind.meal || _item.kind == TodayKind.walk
      ? 'care.edit'
      : 'health.schedule.edit';

  CareEntry? get _careEntry {
    final entry = _item.entry;
    if (entry == null) return null;
    return CareEntry(
      time: entry.due,
      title: entry.item.title,
      item: entry.item,
      log: entry.log,
    );
  }

  Future<void> _open() async {
    final item = _item;
    switch (item.kind) {
      case TodayKind.meal:
        await openFeature<Object>(context, 'log-meal', item.petId, {
          'entry': _careEntry,
        });
      case TodayKind.walk:
        await openFeature<Object>(context, 'walk-sheet', item.petId, {
          'entry': _careEntry,
        });
      case TodayKind.dose:
        await openFeature<Object>(context, 'record-dose', item.petId, {
          'entry': item.entry,
        });
      case TodayKind.routine:
        final pet = _pet();
        final entry = item.entry;
        if (pet != null &&
            entry != null &&
            ref.read(capabilityProvider('health.schedule.edit'))) {
          await openRoutineForm(context, pet, item: entry.item);
        }
      case TodayKind.runsOut:
        ref.read(storeViewProvider.notifier).show(StoreView.basket);
        await openFeature<Object>(context, 'basket', item.petId);
      case TodayKind.firstDays:
        await openFeature<Object>(context, 'first-days', item.petId);
      case TodayKind.essentials:
        await openFeature<Object>(context, 'pet-checklist', item.petId);
    }
  }

  Future<void> _tick() async {
    if (_busy) return;
    final item = _item;
    final now = ref.read(healthClockProvider)();
    if (item.isDone && !item.canUndo(now)) {
      await _open();
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    String errorText(Object error) => healthErrorOf(context, error);
    try {
      final controller = ref.read(todayControllerProvider.notifier);
      if (item.isDone) {
        await controller.undo(item);
      } else {
        await controller.tick(item);
      }
    } catch (error) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorText(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _title(BuildContext context, String? petName) {
    final l10n = context.todayL10n;
    final item = _item;
    final String base;
    switch (item.kind) {
      case TodayKind.essentials:
        // Already names the pet: "Finish Soya's profile".
        return context.petsL10n.finishProfile(petName ?? '');
      case TodayKind.runsOut:
        final days = item.line?.daysLeft ?? 0;
        base = days < 0
            ? l10n.ranOut(item.title)
            : l10n.runsOutIn(days, item.title);
      case TodayKind.firstDays:
        final next = item.firstDays?.next;
        base = next == null
            ? ''
            : firstDaysTaskText(context.firstDaysL10n, next.task.id);
      default:
        base = item.title;
    }
    return widget.namePet && petName != null && petName.isNotEmpty
        ? l10n.withPet(base, petName)
        : base;
  }

  String? _subtitle(BuildContext context, String? petName) {
    final l10n = context.todayL10n;
    final format = AppFormat.of(context);
    final item = _item;
    switch (item.kind) {
      case TodayKind.runsOut:
        return null;
      case TodayKind.firstDays:
        final view = item.firstDays;
        return view == null
            ? null
            : l10n.firstDaysLine(format.integer(view.shownDay));
      case TodayKind.essentials:
        final info = item.essentials;
        return info == null
            ? null
            : context.petsL10n.essentialsStillToAdd(
                info.missing.length,
                info.total,
              );
      default:
        break;
    }
    final at = item.isDone ? item.doneAt : item.time;
    if (at == null) return null;
    final time = format.time(at);
    if (!item.isDone) return time;
    final who = item.doneByMe ? l10n.you : (item.doneBy ?? '');
    if (item.isSkipped) {
      return who.isEmpty ? l10n.notDoneAt(time) : l10n.notDoneBy(time, who);
    }
    return who.isEmpty ? time : l10n.doneBy(time, who);
  }

  (IconData, AppArea) _disc(Pet? pet) => switch (_item.kind) {
    TodayKind.meal => (Icons.restaurant_rounded, AppArea.care),
    TodayKind.walk =>
      pet == null || walksPet(pet.species)
          ? (Icons.directions_walk_rounded, AppArea.care)
          : (Icons.toys_rounded, AppArea.care),
    TodayKind.routine => (Icons.cleaning_services_rounded, AppArea.care),
    TodayKind.dose => (Icons.medication_rounded, AppArea.health),
    TodayKind.runsOut => (Icons.shopping_basket_rounded, AppArea.store),
    TodayKind.firstDays => (Icons.flag_rounded, AppArea.care),
    TodayKind.essentials => (Icons.fact_check_rounded, AppArea.care),
  };

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final l10n = context.todayL10n;
    final pet = ref.watch(
      petsProvider.select((pets) {
        for (final p in pets) {
          if (p.id == item.petId) return p;
        }
        return null;
      }),
    );
    final title = _title(context, pet?.name);
    final subtitle = _subtitle(context, pet?.name);
    final done = item.isDone;
    final canEdit =
        item.isTickable && ref.watch(capabilityProvider(_editCapability));
    final (icon, area) = _disc(pet);

    final Widget trailing;
    if (canEdit) {
      final undo = done && item.canUndo(widget.now);
      trailing = Semantics(
        button: true,
        checked: done,
        label: !done
            ? l10n.markDone(title)
            : undo
            ? l10n.undoDone(title)
            : l10n.doneSemantics(title),
        excludeSemantics: true,
        child: InkResponse(
          key: TodayCard.tickKey(item.id),
          onTap: _busy ? null : _tick,
          radius: 24,
          child: SizedBox(
            width: 44,
            height: 48,
            child: Center(child: _TickCircle(done: done)),
          ),
        ),
      );
    } else {
      trailing = SizedBox(
        key: TodayCard.chevronKey(item.id),
        width: 44,
        height: 48,
        child: const Center(
          child: AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
        ),
      );
    }

    final row = InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              AreaDisc(icon, area: area),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.cardTitle.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.ink,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
        ),
      ),
    );
    return done ? Opacity(opacity: TodayRow.doneOpacity, child: row) : row;
  }
}

/// The tick: an empty 26 px ring in coral dark, or a filled circle with a
/// white check once done.
class _TickCircle extends StatelessWidget {
  const _TickCircle({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? AppColors.coralDark : null,
      border: Border.all(color: AppColors.coralDark, width: 2),
    ),
    alignment: Alignment.center,
    child: done
        ? const AppIcon(Icons.check_rounded, size: 18, color: AppColors.white)
        : null,
  );
}
