import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/feature_ui.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../services/findvet/regions/regions.dart';
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart'
    show outsideAreaProvider;
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../../community/feed/post_actions.dart' show showCommunitySnack;
import '../../community/safety/safety_flows.dart' show ensureCommunityRules;
import '../../outdoors/outdoors.dart' show PickedPark, parkDetailIcon;
import '../../outdoors/outdoors_words.dart';
import '../board/meetups_area_picker.dart';
import '../meetups_words.dart';
import '../../../widgets/app_tag.dart';

/// A new ad, or the new text of an open one ([edit]). [copyOf] starts a
/// new ad from an old one ("Post again"); [park] starts it at a park (the
/// park page's "Post a meetup here").
class MeetupFormScreen extends ConsumerStatefulWidget {
  const MeetupFormScreen({super.key, this.edit, this.copyOf, this.park});

  static const screenKey = Key('meetup-form');
  static const noPetKey = Key('meetup-form-no-pet');
  static Key petKey(String id) => Key('meetup-form-pet-$id');
  static Key kindKey(MeetupKind kind) => Key('meetup-form-kind-${kind.name}');
  static const parkModeKey = Key('meetup-form-where-park');
  static const otherModeKey = Key('meetup-form-where-other');
  static const chooseParkKey = Key('meetup-form-choose-park');
  static const changeCityKey = Key('meetup-form-change-city');
  static const placeKey = Key('meetup-form-place');
  static const onceKey = Key('meetup-form-once');
  static const weeklyKey = Key('meetup-form-weekly');
  static const dateKey = Key('meetup-form-date');
  static const fromKey = Key('meetup-form-from');
  static const toKey = Key('meetup-form-to');
  static Key dayKey(int day) => Key('meetup-form-day-$day');
  static Key partKey(DayPart part) => Key('meetup-form-part-${part.name}');
  static Key sizeKey(PetSize? size) =>
      Key('meetup-form-size-${size?.name ?? 'any'}');
  static const noteKey = Key('meetup-form-note');
  static const submitKey = Key('meetup-form-submit');
  static const problemKey = Key('meetup-form-problem');

  final Meetup? edit;
  final Meetup? copyOf;
  final DogPark? park;

  @override
  ConsumerState<MeetupFormScreen> createState() => _MeetupFormScreenState();
}

class _MeetupFormScreenState extends ConsumerState<MeetupFormScreen> {
  final _place = TextEditingController();
  final _note = TextEditingController();
  var _ready = false;
  var _busy = false;
  var _showProblems = false;

  MeetupKind _kind = MeetupKind.walk;
  String? _petId;
  var _atPark = true;
  DogPark? _park;
  Locality? _city;
  var _choosingCity = false;
  var _once = false;
  late DateTime _date;
  var _from = const TimeOfDay(hour: 18, minute: 0);
  var _to = const TimeOfDay(hour: 19, minute: 0);
  var _days = <int>{};
  var _part = DayPart.morning;
  var _suits = <PetSize>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final now = ref.read(meetupsClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    // A one-off ad starts on the next full hour, today or tomorrow.
    final next = now.hour >= 21
        ? DateTime(today.year, today.month, today.day + 1, 9)
        : DateTime(today.year, today.month, today.day, now.hour + 1);
    _date = DateTime(next.year, next.month, next.day);
    _from = TimeOfDay(hour: next.hour, minute: 0);
    _to = TimeOfDay(hour: (next.hour + 1).clamp(0, 23), minute: 0);
    _days = {now.weekday};
    // Outside's area, read at its source (nothing to work out mid-build).
    _city = MeetupsArea.of(ref.read(outsideAreaProvider).area)?.city;

    final pets = ref.read(petsProvider);
    final from = widget.edit ?? widget.copyOf;
    if (from == null) {
      final selected = ref.read(selectedPetProvider);
      _petId = pets.any((p) => p.id == selected.id)
          ? selected.id
          : pets.firstOrNull?.id;
      if (widget.park case final park?) {
        _park = park;
        _city = localityOfCode(park.localityCode) ?? _city;
      }
      return;
    }
    _kind = from.kind;
    _petId = pets.any((p) => p.id == from.pet?.petId) ? from.pet?.petId : null;
    _atPark = from.parkId != null;
    _park = from.park;
    if (!_atPark) {
      _city = localityOfCode(from.localityCode) ?? _city;
      _place.text = from.placeText ?? '';
    }
    _suits = {...from.suits};
    _note.text = from.note;
    switch (from.time) {
      case OneOffTime(:final start, :final end) when widget.edit != null:
        _once = true;
        _date = DateTime(start.year, start.month, start.day);
        _from = TimeOfDay.fromDateTime(start);
        _to = TimeOfDay.fromDateTime(end);
      case OneOffTime(:final start, :final end):
        // "Post again": the same hours, on the next possible day.
        _once = true;
        _from = TimeOfDay.fromDateTime(start);
        _to = TimeOfDay.fromDateTime(end);
      case RecurringTime(:final weekdays, :final part):
        _once = false;
        _days = {...weekdays};
        _part = part;
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  MeetupDraft get _draft {
    final pet = ref
        .read(petsProvider)
        .where((p) => p.id == _petId)
        .firstOrNull;
    return MeetupDraft(
      kind: _kind,
      pet: pet == null ? null : MeetupPet.of(pet),
      parkId: _atPark ? _park?.id : null,
      park: _atPark ? _park : null,
      localityCode: _atPark ? _park?.localityCode : _city?.code,
      placeText: _atPark ? null : _place.text.trim(),
      time: _once
          ? OneOffTime(_at(_from), _at(_to))
          : RecurringTime({..._days}, _part),
      suits: {..._suits},
      note: _note.text.trim(),
    );
  }

  Future<void> _pickPark() async {
    final picked = await openFeature<PickedPark>(context, 'pick-park', '');
    if (picked == null || !mounted) return;
    setState(() => _park = picked.park);
  }

  Future<void> _pickDate() async {
    final now = ref.read(meetupsClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: MeetupLimits.aheadDays)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _from : _to,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _from = picked;
        if (_to.hour * 60 + _to.minute <= picked.hour * 60 + picked.minute) {
          _to = TimeOfDay(hour: (picked.hour + 1).clamp(0, 23), minute: picked.minute);
        }
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = context.meetupsL10n;
    final now = ref.read(meetupsClockProvider)();
    final draft = _draft;
    final problems = draftProblems(draft, now);
    if (problems.isNotEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    if (!await ensureCommunityRules(context, ref)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(meetupsControllerProvider.notifier)
          .save(draft, id: widget.edit?.id);
      showCommunitySnack(
        messenger,
        widget.edit == null ? l10n.posted : l10n.saved,
      );
      navigator.pop();
    } catch (e) {
      showCommunitySnack(messenger, l10n.failure(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: MeetupCapabilities.post,
    builder: (context) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.meetupsL10n;
    final outdoors = context.outdoorsL10n;
    final language = languageOf(context);
    final format = AppFormat.of(context);
    final week = ref.watch(weekSettingsProvider);
    final pets = ref.watch(petsProvider);
    final now = ref.watch(meetupsClockProvider)();
    final problems = _showProblems
        ? draftProblems(_draft, now)
        : const <MeetupDraftProblem>{};
    final placeProblem = problems.contains(MeetupDraftProblem.place)
        ? (_atPark ? l10n.parkRequired : l10n.placeRequired)
        : null;
    final timeProblems = [
      for (final p in problems) ?l10n.problem(p),
    ];

    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: AppText.sectionTitle),
      ),
    );
    Widget chip(Key key, String label, bool selected, VoidCallback onTap) =>
        ChoiceChip(
          key: key,
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        );

    return Scaffold(
      key: MeetupFormScreen.screenKey,
      body: Column(
        children: [
          CoralHeader(
            title: widget.edit == null ? l10n.formNewTitle : l10n.formEditTitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                4,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                title(l10n.withWhom),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final pet in pets)
                      chip(
                        MeetupFormScreen.petKey(pet.id),
                        pet.name,
                        _petId == pet.id,
                        () => setState(() => _petId = pet.id),
                      ),
                    chip(
                      MeetupFormScreen.noPetKey,
                      l10n.noPet,
                      _petId == null,
                      () => setState(() => _petId = null),
                    ),
                  ],
                ),
                title(l10n.whatQ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final kind in MeetupKind.values)
                      chip(
                        MeetupFormScreen.kindKey(kind),
                        l10n.kind(kind),
                        _kind == kind,
                        () => setState(() => _kind = kind),
                      ),
                  ],
                ),
                title(l10n.whereQ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    chip(
                      MeetupFormScreen.parkModeKey,
                      l10n.wherePark,
                      _atPark,
                      () => setState(() => _atPark = true),
                    ),
                    chip(
                      MeetupFormScreen.otherModeKey,
                      l10n.whereOther,
                      !_atPark,
                      () => setState(() => _atPark = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_atPark) ...[
                  if (_park case final park?)
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        14,
                        10,
                        6,
                        10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.fieldRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          const AppIcon(
                            Icons.park_rounded,
                            color: AppColors.coralDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outdoors.parkFullName(park, language),
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (park.has.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final d in park.has)
                                        AppTag(
                                          outdoors.detail(d),
                                          icon: parkDetailIcon(d),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton(
                            key: MeetupFormScreen.chooseParkKey,
                            onPressed: _pickPark,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                kHealthTapTarget,
                                kHealthTapTarget,
                              ),
                            ),
                            child: Text(l10n.changePark),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      key: MeetupFormScreen.chooseParkKey,
                      onPressed: _pickPark,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(kHealthTapTarget),
                      ),
                      icon: const AppIcon(Icons.park_rounded),
                      label: Text(l10n.choosePark),
                    ),
                ] else ...[
                  if (_city == null || _choosingCity)
                    MeetupsAreaPicker(
                      locating: false,
                      problem: null,
                      onNearMe: null,
                      onOpenSettings: () {},
                      title: l10n.cityLabel,
                      onCity: (city) => setState(() {
                        _city = city;
                        _choosingCity = false;
                      }),
                    )
                  else
                    Row(
                      children: [
                        const AppIcon(
                          Icons.place_rounded,
                          color: AppColors.coralDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _city!.nameIn(language),
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          key: MeetupFormScreen.changeCityKey,
                          onPressed: () =>
                              setState(() => _choosingCity = true),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              kHealthTapTarget,
                              kHealthTapTarget,
                            ),
                          ),
                          child: Text(l10n.changePark),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    key: MeetupFormScreen.placeKey,
                    controller: _place,
                    maxLength: MeetupLimits.place,
                    onChanged: (_) {
                      if (_showProblems) setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: l10n.placeLabel,
                      hintText: l10n.placeHint,
                      helperText: l10n.placeHelp,
                      helperMaxLines: 2,
                      hintMaxLines: 2,
                    ),
                  ),
                ],
                if (placeProblem != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      placeProblem,
                      key: MeetupFormScreen.problemKey,
                      style: AppText.body.copyWith(color: AppColors.coralDark),
                    ),
                  ),
                title(l10n.whenQ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    chip(
                      MeetupFormScreen.onceKey,
                      l10n.once,
                      _once,
                      () => setState(() => _once = true),
                    ),
                    chip(
                      MeetupFormScreen.weeklyKey,
                      l10n.weekly,
                      !_once,
                      () => setState(() => _once = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_once)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (key, label, value, onTap) in [
                        (
                          MeetupFormScreen.dateKey,
                          l10n.dateLabel,
                          format.date(_date),
                          _pickDate,
                        ),
                        (
                          MeetupFormScreen.fromKey,
                          l10n.fromLabel,
                          format.timeOfDay(_from),
                          () => _pickTime(true),
                        ),
                        (
                          MeetupFormScreen.toKey,
                          l10n.toLabel,
                          format.timeOfDay(_to),
                          () => _pickTime(false),
                        ),
                      ])
                        OutlinedButton(
                          key: key,
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, kHealthTapTarget),
                          ),
                          child: Text('$label: ${ltr(value)}'),
                        ),
                    ],
                  )
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final day in week.orderedDays)
                        FilterChip(
                          key: MeetupFormScreen.dayKey(day),
                          label: Text(format.weekdayShort(day)),
                          selected: _days.contains(day),
                          showCheckmark: false,
                          onSelected: (on) => setState(
                            () => on ? _days.add(day) : _days.remove(day),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.partQ,
                    style: AppText.label.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final part in DayPart.values)
                        chip(
                          MeetupFormScreen.partKey(part),
                          l10n.dayPart(part),
                          _part == part,
                          () => setState(() => _part = part),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.recurringNote,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ],
                for (final problem in timeProblems)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      problem,
                      style: AppText.body.copyWith(color: AppColors.coralDark),
                    ),
                  ),
                title(l10n.suitsQ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    chip(
                      MeetupFormScreen.sizeKey(null),
                      l10n.sizeAny,
                      _suits.isEmpty,
                      () => setState(_suits.clear),
                    ),
                    for (final size in PetSize.values)
                      FilterChip(
                        key: MeetupFormScreen.sizeKey(size),
                        label: Text(l10n.sizeChip(size)),
                        selected: _suits.contains(size),
                        showCheckmark: false,
                        onSelected: (on) => setState(() {
                          on ? _suits.add(size) : _suits.remove(size);
                          if (_suits.length == PetSize.values.length) {
                            _suits.clear();
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: MeetupFormScreen.noteKey,
                  controller: _note,
                  maxLength: MeetupLimits.note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.noteLabel,
                    hintText: l10n.noteHint,
                    hintMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsetsDirectional.only(top: 2, end: 8),
                      child: AppIcon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.brown,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${l10n.safetyStrip} ${l10n.limitsNote}',
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: MeetupFormScreen.submitKey,
                  child: PrimaryButton(
                    label: widget.edit == null ? l10n.post : l10n.save,
                    loading: _busy,
                    onPressed: _busy ? null : _submit,
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
