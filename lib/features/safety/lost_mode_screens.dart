import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../platform/feature_ui.dart';
import '../../platform/usage.dart';
import '../../presentation/health_format.dart';
import '../../presentation/health_widgets.dart';
import '../../presentation/pet_words.dart';
import '../../services/community/data/community_models.dart' show Comment;
import '../../services/community/data/community_providers.dart';
import '../../services/findvet/regions/regions.dart';
import '../../services/outdoors/data/park_area.dart';
import '../../services/outdoors/state/parks_providers.dart';
import '../../services/pet_records/state/health_providers.dart';
import '../../services/pet_records/state/lost_card.dart';
import '../../services/pets/data/pets_repository_provider.dart';
import '../../services/safety/state/safety_providers.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/primary_button.dart';
import 'safety_widgets.dart';

/// The pet's own photo, for the preview of the post (`null`: none).
final _petPhotoProvider = FutureProvider.autoDispose
    .family<ImageProvider?, ({String? path, String? asset})>((ref, photo) async {
      final path = photo.path;
      if (path != null) {
        final data = await ref.watch(petsRepositoryProvider).loadPhoto(path);
        if (data.bytes case final bytes?) return MemoryImage(bytes);
        if (data.url case final url?) return NetworkImage(url.toString());
        return null;
      }
      final asset = photo.asset;
      return asset == null ? null : AssetImage(asset);
    });

/// The words of a refusal of Lost mode.
String lostFailureText(BuildContext context, Object error, String petName) {
  final safety = context.safetyL10n;
  final failure = error is LostAlertException ? error.failure : null;
  return switch (failure) {
    LostAlertFailure.alreadyActive => safety.lostErrActive(petName),
    LostAlertFailure.rateLimited => safety.lostErrRate,
    LostAlertFailure.invalid => safety.lostErrInvalid,
    LostAlertFailure.notAllowed => safety.lostErrNotAllowed,
    _ => safety.lostErrGeneric,
  };
}

/// [at] with the time of day [time].
DateTime _atTime(DateTime at, TimeOfDay time) =>
    DateTime(at.year, at.month, at.day, time.hour, time.minute);

/// Lost mode: step 1 (who, when, where), step 2 (the post as people will
/// see it, "Start lost mode"). Starting writes the post, the alert and the
/// pushes in one go, then opens the open alert with the lost card to share
/// on top. Back on step 2 returns to step 1 with everything kept.
class LostStartScreen extends ConsumerStatefulWidget {
  const LostStartScreen({super.key, required this.pet});

  static const whenKey = Key('lost-start-when');
  static const townKey = Key('lost-start-town');
  static const placeKey = Key('lost-start-place');
  static const noteKey = Key('lost-start-note');
  static const nextKey = Key('lost-start-next');
  static const changePetKey = Key('lost-start-change-pet');
  static const photoKey = Key('lost-start-photo');
  static const startKey = Key('lost-start-go');
  static const backKey = Key('lost-start-back');
  static const previewKey = Key('lost-start-preview');

  final Pet pet;

  @override
  ConsumerState<LostStartScreen> createState() => _LostStartScreenState();
}

class _LostStartScreenState extends ConsumerState<LostStartScreen> {
  final _place = TextEditingController();
  final _note = TextEditingController();
  late Pet _pet = widget.pet;
  late DateTime _seenAt = ref.read(healthClockProvider)();
  Locality? _town;
  bool _usePhoto = true;
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _town = switch (ref.read(outsideAreaProvider).area) {
      CityArea(:final locality) => locality,
      NearMeArea(:final nearest) => nearest,
      null => null,
    };
  }

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(healthClockProvider)();

  /// The post's fixed words follow the lost card's language.
  String get _postLanguage =>
      ref.read(lostCardProvider(_pet.id)).value?.language.code ?? 'he';

  Future<void> _pickWhen() async {
    final now = _now;
    final day = await showDatePicker(
      context: context,
      initialDate: _seenAt,
      firstDate: now.subtract(const Duration(days: 29)),
      lastDate: now,
      currentDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_seenAt),
    );
    if (!mounted) return;
    final picked = _atTime(day, time ?? TimeOfDay.fromDateTime(_seenAt));
    setState(() => _seenAt = picked.isAfter(now) ? now : picked);
  }

  Future<void> _pickTown() async {
    final town = await showHealthSheet<Locality>(context, const _TownPicker());
    if (town != null && mounted) {
      setState(() {
        _town = town;
        _error = null;
      });
    }
  }

  Future<void> _pickPet() async {
    final pet = await showHealthSheet<Pet>(context, _PetPicker(current: _pet));
    if (pet != null && mounted) setState(() => _pet = pet);
  }

  void _next() {
    if (_town == null) {
      setState(() => _error = context.safetyL10n.lostTownNeeded);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  Future<void> _start() async {
    final town = _town;
    if (town == null) return;
    final language = _postLanguage;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final started = context.safetyL10n.lostStarted;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final alert = await ref
          .read(lostAlertsProvider.notifier)
          .start(
            LostStart(
              petId: _pet.id,
              localityCode: town.code,
              seenAt: _seenAt,
              place: _place.text.trim(),
              note: _note.text.trim(),
              language: language,
              petPhotoPath: _usePhoto ? _pet.photoPath : null,
              areaName: town.nameIn(language),
            ),
          );
      ref.read(usageProvider).count(UsageKind.postCreated);
      // The server brought the lost card's draft up to date.
      ref.invalidate(lostCardProvider(_pet.id));
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(started)));
      final pet = _pet;
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LostAlertScreen(pet: pet, alertId: alert.id),
        ),
      );
      // The card to share comes next, filled in.
      final root = navigator.context;
      if (root.mounted) {
        openFeature<Object>(root, 'lost-card', pet.id).ignore();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = lostFailureText(context, error, _pet.name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.safetyL10n;
    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1 && !_busy) setState(() => _step = 0);
      },
      child: HealthPage(
        title: _step == 0 ? safety.lostRow : safety.lostPreviewTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              safety.lostStep(_step + 1, 2),
              style: AppText.secondary.copyWith(
                color: AppColors.brown,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_step == 0) ..._stepOne(context) else ..._stepTwo(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('lost-start-error'),
                style: AppText.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _stepOne(BuildContext context) {
    final safety = context.safetyL10n;
    final format = HealthFormat.of(context);
    final now = ref.watch(healthClockProvider)();
    final pets = ref.watch(petsProvider);
    final looks = ref.watch(lostCardProvider(_pet.id)).value?.description ?? '';
    final facts = [
      petSpeciesText(context.petsL10n, _pet.species),
      if ((_pet.breed ?? '').trim().isNotEmpty) _pet.breed!.trim(),
      if (looks.trim().isNotEmpty) looks.trim(),
    ].join(' · ');
    final language = safetyLanguageOf(context);
    return [
      HealthCard(
        radius: AppSpacing.fieldRadius,
        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 4, 8),
        child: Row(
          children: [
            _PetPhoto(pet: _pet, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TypedText(_pet.name, style: AppText.cardTitle),
                  TypedText(
                    facts,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
            ),
            if (pets.length > 1)
              HealthLink(
                safety.lostChangePet,
                key: LostStartScreen.changePetKey,
                onPressed: _pickPet,
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      PickerTile(
        key: LostStartScreen.whenKey,
        icon: Icons.schedule_rounded,
        label: safety.lostLastSeen,
        value: format.relativeDayTime(_seenAt, now),
        onTap: _pickWhen,
      ),
      const SizedBox(height: 10),
      PickerTile(
        key: LostStartScreen.townKey,
        icon: Icons.place_rounded,
        label: safety.lostTown,
        value: _town?.nameIn(language) ?? safety.lostTownChoose,
        placeholder: _town == null,
        onTap: _pickTown,
      ),
      const SizedBox(height: 10),
      TextField(
        key: LostStartScreen.placeKey,
        controller: _place,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: safety.lostWhere,
          helperText: safety.lostWhereHint,
          counterText: '',
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        key: LostStartScreen.noteKey,
        controller: _note,
        minLines: 2,
        maxLines: 4,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: safety.lostNote,
          hintText: safety.lostNoteHint,
          counterText: '',
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: LostStartScreen.nextKey,
        onPressed: _next,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: AppText.button(16),
        ),
        child: Text(safety.lostNext),
      ),
    ];
  }

  List<Widget> _stepTwo(BuildContext context) {
    final safety = context.safetyL10n;
    final language = _postLanguage;
    final looks = ref.watch(lostCardProvider(_pet.id)).value?.description ?? '';
    final town = _town!;
    final hasPhoto = _pet.hasPhoto;
    final author = ref.watch(authControllerProvider).value;
    final body = lostPostBody(
      language: language,
      name: _pet.name,
      species: _pet.species.name,
      breed: _pet.breed,
      looks: looks,
      seenAt: _seenAt,
      place: _place.text,
      area: town.nameIn(language),
      note: _note.text,
    );
    return [
      HealthCard(
        key: LostStartScreen.previewKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.neutral,
                  child: Text(
                    author?.initial ?? '',
                    style: AppText.cardTitle.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TypedText(
                        author?.displayName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle,
                      ),
                      Text(
                        safety.lostNow,
                        style: AppText.label.copyWith(color: AppColors.brown),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: AppTag(safety.lostPostTag, tone: AppTagTone.peach),
                ),
              ],
            ),
            if (hasPhoto && _usePhoto) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 150,
                  child: _PetPhoto(pet: _pet, size: double.infinity),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TypedText(body, style: AppText.body.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
      if (hasPhoto) ...[
        const SizedBox(height: 10),
        HealthCard(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SwitchListTile(
            key: LostStartScreen.photoKey,
            value: _usePhoto,
            onChanged: _busy ? null : (on) => setState(() => _usePhoto = on),
            title: Text(
              safety.lostUsePhoto(_pet.name),
              style: AppText.cardTitle,
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Text(
        safety.lostWhoHears(town.nameIn(safetyLanguageOf(context))),
        style: AppText.body.copyWith(color: AppColors.brown),
      ),
      const SizedBox(height: 12),
      HealthCard(
        child: Row(
          children: [
            const IconDisc(Icons.badge_rounded, color: AppColors.yellow),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(safety.lostCardNext, style: AppText.cardTitle),
                  Text(
                    safety.lostCardNextNote,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: LostStartScreen.startKey,
        child: PrimaryButton(
          label: safety.lostStart,
          loading: _busy,
          onPressed: _start,
        ),
      ),
      Center(
        child: HealthLink(
          context.l10n.commonBack,
          key: LostStartScreen.backKey,
          onPressed: _busy ? null : () => setState(() => _step = 0),
        ),
      ),
    ];
  }
}

/// The pet's photo (or a sage square with a paw), [size] square, or as
/// wide as allowed when [size] is infinite.
class _PetPhoto extends ConsumerWidget {
  const _PetPhoto({required this.pet, required this.size});

  final Pet pet;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref
        .watch(_petPhotoProvider((path: pet.photoPath, asset: pet.photoAsset)))
        .value;
    final box = size.isFinite
        ? (Widget child) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: size, height: size, child: child),
          )
        : (Widget child) => SizedBox.expand(child: child);
    return box(
      ColoredBox(
        color: AppColors.sage,
        child: photo == null
            ? const Center(child: AppIcon(Icons.pets_rounded, color: AppColors.ink))
            : Image(
                image: photo,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const Center(
                  child: AppIcon(Icons.pets_rounded, color: AppColors.ink),
                ),
              ),
      ),
    );
  }
}

/// "Choose the town": the localities of the app's list (the ones Find a
/// vet and the parks use), found as the owner types.
class _TownPicker extends StatefulWidget {
  const _TownPicker();

  @override
  State<_TownPicker> createState() => _TownPickerState();
}

class _TownPickerState extends State<_TownPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.safetyL10n;
    final language = safetyLanguageOf(context);
    final found = [
      for (final region in vetRegions) ...region.findLocalities(_query.text, limit: 8),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(safety.lostTownChoose),
        const SizedBox(height: 12),
        TextField(
          key: const Key('lost-town-field'),
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: safety.lostTownHint,
            prefixIcon: const AppIcon(Icons.search_rounded, color: AppColors.brown),
          ),
        ),
        const SizedBox(height: 8),
        for (final town in found)
          ListTile(
            key: ValueKey('lost-town-${town.code}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minTileHeight: kHealthTapTarget,
            leading: const AppIcon(Icons.place_rounded, color: AppColors.brown),
            title: Text(town.nameIn(language), style: AppText.cardTitle),
            onTap: () => Navigator.of(context).pop(town),
          ),
      ],
    );
  }
}

/// "Who is missing?": the pets the tabs show.
class _PetPicker extends ConsumerWidget {
  const _PetPicker({required this.current});

  final Pet current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(context.safetyL10n.lostWhichPet),
        const SizedBox(height: 8),
        for (final pet in ref.watch(petsProvider))
          ListTile(
            key: ValueKey('lost-pet-${pet.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minTileHeight: kHealthTapTarget,
            leading: _PetPhoto(pet: pet, size: 40),
            title: TypedText(pet.name, style: AppText.cardTitle),
            trailing: pet.id == current.id
                ? const AppIcon(Icons.check_rounded, color: AppColors.coralDark)
                : null,
            onTap: () => Navigator.of(context).pop(pet),
          ),
      ],
    );
  }
}

/// The comments on an alert's post, oldest first.
final _commentsProvider = FutureProvider.autoDispose
    .family<List<Comment>, String>(
      (ref, postId) =>
          ref.watch(feedRepositoryProvider).fetchComments(postId: postId),
    );

/// The open alert: since when and where, the sightings (comments of other
/// people on the post), the card to share, "{pet} is home" (the one filled
/// button) and a quiet "Close the alert" that asks first. Closes itself
/// once the alert is closed.
class LostAlertScreen extends ConsumerStatefulWidget {
  const LostAlertScreen({super.key, required this.pet, required this.alertId});

  static const statusKey = Key('lost-alert-status');
  static const sightingsKey = Key('lost-alert-sightings');
  static const openPostKey = Key('lost-alert-open-post');
  static const shareKey = Key('lost-alert-share');
  static const foundKey = Key('lost-alert-found');
  static const closeKey = Key('lost-alert-close');

  final Pet pet;
  final String alertId;

  @override
  ConsumerState<LostAlertScreen> createState() => _LostAlertScreenState();
}

class _LostAlertScreenState extends ConsumerState<LostAlertScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _close({required bool found}) async {
    final safety = context.safetyL10n;
    if (!found) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(safety.lostCloseQuestion),
          content: Text(safety.lostCloseNote),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(safety.lostKeepLooking),
            ),
            TextButton(
              key: const Key('lost-alert-close-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(safety.lostCloseConfirm),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final done = found ? safety.lostFoundDone : safety.lostClosedDone;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(lostAlertsProvider.notifier);
      if (found) {
        await controller.markFound(widget.alertId);
      } else {
        await controller.cancel(widget.alertId);
      }
      ref.invalidate(lostCardProvider(widget.pet.id));
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = lostFailureText(context, error, widget.pet.name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.safetyL10n;
    final format = HealthFormat.of(context);
    final now = ref.watch(healthClockProvider)();
    LostAlert? alert;
    for (final a in ref.watch(lostAlertsProvider).value ?? const <LostAlert>[]) {
      if (a.id == widget.alertId) alert = a;
    }
    final me = ref.watch(authControllerProvider).value?.id;
    final language = safetyLanguageOf(context);
    final town = localityOfCodeIn(alert?.localityCode)?.nameIn(language) ??
        alert?.localityCode ??
        '';
    final postId = alert?.postId;
    return HealthPage(
      title: safety.lostAlertTitle(widget.pet.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alert != null)
            HealthCard(
              key: LostAlertScreen.statusKey,
              color: AppColors.peach,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safety.lostSince(format.relativeDayTime(alert.lastSeenAt, now)),
                    style: AppText.rowTitle.copyWith(fontSize: 17),
                  ),
                  TypedText(
                    [town, if (alert.lastSeenPlace.isNotEmpty) alert.lastSeenPlace]
                        .join(' · '),
                    style: AppText.secondary.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          FormLabel(safety.lostSightings),
          if (postId != null)
            _Sightings(postId: postId, me: me)
          else
            HealthCard(child: Text(safety.lostNoSightings, style: AppText.body)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: LostAlertScreen.shareKey,
            onPressed: _busy
                ? null
                : () => openFeature<Object>(context, 'lost-card', widget.pet.id),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.ios_share_rounded, size: 18),
            label: Text(safety.lostShareCard),
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: LostAlertScreen.foundKey,
            child: PrimaryButton(
              label: safety.lostHome(widget.pet.name),
              loading: _busy,
              onPressed: alert == null ? null : () => _close(found: true),
            ),
          ),
          Center(
            child: HealthLink(
              safety.lostClose,
              key: LostAlertScreen.closeKey,
              onPressed: _busy || alert == null ? null : () => _close(found: false),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

/// The locality of [code] in the app's list, if any.
Locality? localityOfCodeIn(String? code) {
  if (code == null) return null;
  for (final region in vetRegions) {
    final locality = region.localityByCode(code);
    if (locality != null) return locality;
  }
  return null;
}

class _Sightings extends ConsumerWidget {
  const _Sightings({required this.postId, required this.me});

  final String postId;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safety = context.safetyL10n;
    final format = HealthFormat.of(context);
    final now = ref.watch(healthClockProvider)();
    final comments = ref.watch(_commentsProvider(postId));
    return comments.when(
      loading: () => const HealthLoading(),
      error: (error, _) => HealthLoadError(
        title: safety.lostSightingsFailed,
        error: error,
        onRetry: () => ref.invalidate(_commentsProvider(postId)),
      ),
      data: (all) {
        final sightings = [
          for (final c in all.reversed)
            if (c.authorId != me) c,
        ];
        return HealthCard(
          key: LostAlertScreen.sightingsKey,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sightings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    safety.lostNoSightings,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                ),
              for (final c in sightings) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.neutral,
                        child: Text(
                          c.authorInitial,
                          style: AppText.cardTitle.copyWith(color: AppColors.ink),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TypedText(
                              '${c.authorName} · ${format.relativeDayTime(c.createdAt, now)}',
                              style: AppText.label.copyWith(
                                color: AppColors.brown,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TypedText(c.text, style: AppText.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              Center(
                child: HealthLink(
                  safety.lostOpenPost,
                  key: LostAlertScreen.openPostKey,
                  onPressed: () =>
                      openFeature<Object>(context, 'post', '', {'id': postId}),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
