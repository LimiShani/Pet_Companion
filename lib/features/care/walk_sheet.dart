import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../health/data/health_models.dart';
import '../health/health_strings.dart';
import '../health/state/health_providers.dart';
import '../health/widgets/health_widgets.dart';
import 'data/care_models.dart';
import 'state/care_logic.dart';
import 'state/care_providers.dart';

/// Opens the walk (or play) sheet: start one now, or log one that
/// happened. [entry] is the planned walk to start on.
Future<void> showWalkSheet(BuildContext context, Pet pet, {CareEntry? entry}) =>
    showHealthSheet<void>(context, WalkSheet(pet: pet, entry: entry));

/// Saves the running walk of [pet] with the minutes it ran (at least one)
/// and forgets it. Shows "Saved 35 min", or what went wrong.
Future<void> finishWalk(BuildContext context, WidgetRef ref, Pet pet) async {
  final walk = ref.read(runningWalkProvider(pet.id));
  if (walk == null) return;
  final l10n = context.careL10n;
  String errorText(Object error) => healthErrorOf(context, error);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final now = ref.read(healthClockProvider)();
  final minutes = now.difference(walk.startedAt).inMinutes.clamp(1, 1440);
  final plan = await ref.read(carePlanProvider(pet.id).future);
  CarePlanItem? item;
  for (final i in plan.items) {
    if (i.id == walk.planItemId) item = i;
  }
  try {
    await ref
        .read(carePlanProvider(pet.id).notifier)
        .record(
          item: item,
          kind: item == null ? CareKind.walk : null,
          title: item == null ? (walksPet(pet.species) ? l10n.typeWalk : l10n.typePlay) : null,
          dueOn: item == null ? now : walk.startedAt,
          status: CareLogStatus.done,
          doneAt: walk.startedAt,
          minutes: minutes,
        );
    await ref.read(runningWalkProvider(pet.id).notifier).clear();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.savedMinutes('$minutes'))));
  } catch (error) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(errorText(error))));
  }
}

enum _Type { walk, play, run }

class WalkSheet extends ConsumerStatefulWidget {
  const WalkSheet({super.key, required this.pet, this.entry});

  static const startKey = Key('walk-start-now');
  static const saveKey = Key('walk-save');
  static const extraKey = Key('walk-extra');

  final Pet pet;
  final CareEntry? entry;

  @override
  ConsumerState<WalkSheet> createState() => _WalkSheetState();
}

class _WalkSheetState extends ConsumerState<WalkSheet> {
  static const _choices = [15, 30, 45, 60];

  CareEntry? _walk;
  bool _chosen = false;
  int _minutes = 30;
  bool _otherMinutes = false;
  late _Type _type = walksPet(widget.pet.species) ? _Type.walk : _Type.play;
  TimeOfDay? _time;
  bool _saving = false;
  Object? _error;

  String get _petId => widget.pet.id;
  bool get _walks => walksPet(widget.pet.species);

  void _init(ActivityDay day, DateTime now) {
    if (_chosen) return;
    _chosen = true;
    _walk = widget.entry ?? day.suggested(now);
    _time = _walk == null || _walk!.time.isAfter(now)
        ? TimeOfDay.fromDateTime(now)
        : TimeOfDay.fromDateTime(_walk!.time);
  }

  String _typeLabel(_Type type) {
    final l10n = context.careL10n;
    return switch (type) {
      _Type.walk => l10n.typeWalk,
      _Type.play => l10n.typePlay,
      _Type.run => l10n.typeRun,
    };
  }

  Future<void> _startNow() async {
    await ref.read(runningWalkProvider(_petId).notifier).start(planItemId: _walk?.item?.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _askMinutes() async {
    final l10n = context.careL10n;
    final controller = TextEditingController(text: '$_minutes');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.howLong),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (text) => Navigator.of(context).pop(int.tryParse(text.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() {
      _minutes = value.clamp(1, 1440);
      _otherMinutes = !_choices.contains(_minutes);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final now = ref.read(healthClockProvider)();
    final walk = _walk;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(carePlanProvider(_petId).notifier)
          .record(
            item: walk?.item,
            kind: walk == null ? CareKind.walk : null,
            title: walk == null ? _typeLabel(_type) : null,
            dueOn: walk?.time ?? now,
            status: CareLogStatus.done,
            doneAt: atTime(now, _time ?? TimeOfDay.fromDateTime(now)),
            minutes: _minutes,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.careL10n;
    final day = ref.watch(activityDayProvider(_petId)).value;
    if (day == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final now = ref.watch(healthClockProvider)();
    _init(day, now);
    final running = ref.watch(runningWalkProvider(_petId));
    final format = AppFormat.of(context);
    final open = [
      for (final w in day.walks)
        if (w.isPlanned && !w.isAnswered) w,
    ];
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(_walks ? l10n.walkTitle : l10n.playTitle, subtitle: widget.pet.name),
        const SizedBox(height: 14),
        if (open.isNotEmpty) ...[
          _Label(l10n.whichWalk),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final w in open)
                ChoiceChip(
                  label: Text('${isolate(w.title)} · ${isolate(format.time(w.time))}'),
                  selected: _walk?.item?.id == w.item!.id,
                  onSelected: (_) => setState(() => _walk = w),
                ),
              ChoiceChip(
                key: WalkSheet.extraKey,
                label: Text(l10n.extra),
                selected: _walk == null,
                onSelected: (_) => setState(() => _walk = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (running == null)
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: WalkSheet.startKey,
              onTap: _startNow,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Icon(Icons.play_circle_outline_rounded, size: 34, color: AppColors.coralDark),
                    const SizedBox(height: 4),
                    Text(_walks ? l10n.startNow : l10n.startPlayNow, style: AppText.cardTitle.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(l10n.startNowNote, textAlign: TextAlign.center, style: AppText.secondary),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(l10n.logPast, style: AppText.cardTitle.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        _Label(l10n.howLong),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final m in _choices)
              ChoiceChip(
                label: Text(format.integer(m)),
                selected: !_otherMinutes && _minutes == m,
                onSelected: (_) => setState(() {
                  _minutes = m;
                  _otherMinutes = false;
                }),
              ),
            ChoiceChip(
              label: Text(_otherMinutes ? l10n.minutesValue(format.integer(_minutes)) : l10n.otherMinutes),
              selected: _otherMinutes,
              onSelected: (_) => _askMinutes(),
            ),
          ],
        ),
        if (_walk == null) ...[
          const SizedBox(height: 12),
          _Label(l10n.activityType),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final type in _walks ? _Type.values : const [_Type.play, _Type.run])
                ChoiceChip(
                  label: Text(_typeLabel(type)),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
            title: Text(l10n.when, style: AppText.body),
            trailing: Text(l10n.todayAt(format.timeOfDay(_time!)), style: AppText.cardTitle.copyWith(fontSize: 16)),
            onTap: _pickTime,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(healthErrorOf(context, error), style: AppText.body.copyWith(color: AppColors.coralDark)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(key: WalkSheet.saveKey, label: l10n.save, loading: _saving, onPressed: _save),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
  );
}
