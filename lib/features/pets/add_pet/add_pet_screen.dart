import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/primary_button.dart';
import '../../firstdays/firstdays.dart';
import '../../health/emergency/emergency.dart';
import '../data/pets_repository_provider.dart';
import '../icons/pet_icon_bank.dart';
import '../pet_words.dart';
import '../pets_routes.dart';
import '../picture/pet_picture.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_basics_fields.dart';
import '../widgets/pets_widgets.dart';
import 'all_set_view.dart';

/// The add-a-pet flow, full screen.
///
/// Step 1 (name, kind, picture) creates the pet and selects it; every later
/// step can be skipped, and "Finish later" closes the flow from step 2 on.
/// There is no half-made state: an unfinished pet is simply a pet with
/// missing essentials, and the reminder is the way back in.
///
/// Pops with the new [Pet], or `null` when the owner left before step 1 was
/// saved.
class AddPetScreen extends ConsumerStatefulWidget {
  const AddPetScreen({super.key});

  @override
  ConsumerState<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends ConsumerState<AddPetScreen> {
  static const _uuid = Uuid();
  static const _steps = 4;

  /// The "All set" page after the last step.
  static const _allSet = _steps + 1;

  final _nameForm = GlobalKey<FormState>();
  final _aboutForm = GlobalKey<FormState>();
  final _name = TextEditingController();

  /// The new pet's id, made on the phone so its photo has a folder before
  /// the pet is stored.
  String _id = _uuid.v4();

  /// The pet made before "Add another pet" was chosen: what the flow
  /// returns when the owner then leaves before saving the next one.
  String? _previousId;
  PetSpecies _species = PetSpecies.dog;

  /// The picture chosen on step 1, not stored yet.
  PetPicture? _picture;
  PetBasicsController? _basics;

  /// "Just arrived home?" on step 2.
  ArrivalController? _arrival;
  int _step = 1;
  bool _busy = false;
  String? _error;

  Pet? get _pet => ref.read(petsStoreProvider).byId(_id);
  DateTime get _now => ref.read(petsClockProvider)();

  @override
  void dispose() {
    _name.dispose();
    _basics?.dispose();
    _arrival?.dispose();
    super.dispose();
  }

  /// Leaves the flow. The pet, once created, stays.
  void _close({bool toDashboard = false}) {
    final previous = _previousId;
    final pet = _pet ?? (previous == null ? null : ref.read(petsStoreProvider).byId(previous));
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(pet);
      if (toDashboard) router?.go(PetsRoutes.start);
    } else {
      // Opened from the first-pet welcome: the router decides where to land.
      router?.go(PetsRoutes.start);
    }
  }

  void _back() {
    if (_busy) return;
    if (_step > 1 && _step <= _steps) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      _close();
    }
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _busy = false;
      _error = null;
    });
  }

  /// "Add another pet" on the last page: the flow starts again, empty.
  void _startAnother() {
    setState(() {
      _previousId = _id;
      _id = _uuid.v4();
      _name.clear();
      _species = PetSpecies.dog;
      _picture = null;
      _basics?.dispose();
      _basics = null;
      _arrival?.dispose();
      _arrival = null;
      _step = 1;
      _busy = false;
      _error = null;
    });
  }

  Future<void> _choosePicture() async {
    final pet = _pet;
    final draft = _picture;
    final hasPicture = draft != null
        ? draft is! NoPicture
        : pet != null && (pet.hasPhoto || pet.iconKey != null);
    final picture = await choosePetPicture(
      context,
      petName: _name.text,
      species: _species,
      canRemove: hasPicture,
      currentIcon: draft is IconPicture
          ? draft.choice
          : pet?.iconKey == null
              ? null
              : PetIconChoice.parse(pet!.iconKey, species: _species),
    );
    if (picture != null && mounted) setState(() => _picture = picture);
  }

  /// Step 1: creates the pet (or, after "back", saves the changed name,
  /// kind and picture) and selects it.
  Future<void> _saveNameAndKind() async {
    if (!_nameForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = ref.read(petsStoreProvider.notifier);
    final name = _name.text.trim();
    final picture = _picture;
    try {
      final existing = _pet;
      var pet = existing == null
          ? Pet(
              id: _id,
              name: name,
              species: _species,
              iconKey: picture is IconPicture ? picture.choice.key : null,
              createdAt: _now,
            )
          : existing.withBasics(
              name: name,
              species: _species,
              breed: existing.breed,
              weightKg: existing.weightKg,
              sex: existing.sex,
              neutered: existing.neutered,
              keepAge: true,
            );
      pet = await store.save(pet);
      ref.read(selectedPetIdProvider.notifier).select(pet.id);

      var pictureFailed = false;
      if (picture != null && !(existing == null && picture is! PhotoPicture)) {
        try {
          pet = await savePetPicture(store, pet, picture);
        } catch (_) {
          pictureFailed = true;
        }
      }
      if (!mounted) return;
      _picture = null;
      _basics?.species = _species;
      _basics ??= PetBasicsController(pet: pet, now: _now);
      _arrival ??= ArrivalController.today(ref);
      _goTo(2);
      if (pictureFailed) {
        showPetsSnack(context, context.petsL10n.pictureNotSaved(pet.name));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = petsErrorOf(context, e);
      });
    }
  }

  /// Step 2: saves what the owner knows about the pet.
  Future<void> _saveAbout() async {
    final pet = _pet;
    final basics = _basics;
    if (pet == null || basics == null) return;
    if (!_aboutForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(petsStoreProvider.notifier).save(basics.applyTo(pet, now: _now));
      basics.markSaved();
      await _arrival?.apply(ref, pet.id);
      if (mounted) _goTo(3);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is HealthException ? healthErrorOf(context, e) : petsErrorOf(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the pet changes (a picture saved, an answer given).
    final pet = ref.watch(petsStoreProvider.select((pets) => pets.byId(_id)));

    final Widget page;
    if (_step == 1 || pet == null) {
      page = _page(title: context.petsL10n.addPetTitle, step: 1, finishLater: false, child: _nameAndKind(pet));
    } else {
      page = switch (_step) {
        2 => _page(title: context.petsL10n.aboutPetTitle(pet.name), step: 2, child: _about(pet)),
        3 => _page(title: context.petsL10n.petVetTitle(pet.name), step: 3, child: _vet(pet)),
        4 => _page(title: context.petsL10n.healthBasics, step: 4, child: _healthBasics(pet)),
        _ => AllSetView(
            pet: pet,
            onDashboard: () => _close(toDashboard: true),
            onAddAnother: _startAnother,
          ),
      };
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: page,
    );
  }

  Widget _page({required String title, required int step, required Widget child, bool finishLater = true}) {
    return PetsPage(
      // A new page per step, so each one starts scrolled to its top.
      key: ValueKey('add-pet-step-$step-$_id'),
      title: title,
      onBack: _back,
      actions: [if (finishLater) HeaderTextAction(context.petsL10n.finishLater, onPressed: _busy ? null : _close)],
      headerBottom: StepProgress(step: step, total: _steps),
      child: child,
    );
  }

  Widget _errorText() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
      );

  // ------------------------------------------------------------ step 1

  Widget _nameAndKind(Pet? pet) {
    final draft = _picture;
    final Widget picture;
    if (draft != null || pet == null) {
      picture = PetPictureCircle(
        size: 132,
        icon: draft is IconPicture ? draft.choice : PetIconChoice(PetIcon.defaultFor(_species)),
        bytes: draft is PhotoPicture ? draft.jpeg : null,
      );
    } else {
      picture = PetAvatar(pet: pet, size: 132);
    }
    final name = _name.text.trim();

    return Form(
      key: _nameForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PetsHeading(context.petsL10n.whoIsJoining),
          const SizedBox(height: 4),
          PetsNote(context.petsL10n.whoIsJoiningNote),
          const SizedBox(height: 18),
          Center(
            child: Semantics(
              button: true,
              label: context.petsL10n.addPhotoOrIcon,
              child: InkWell(
                key: const Key('pet-picture'),
                onTap: _busy ? null : _choosePicture,
                customBorder: const CircleBorder(),
                child: Stack(
                  children: [
                    ExcludeSemantics(child: picture),
                    const PositionedDirectional(end: 0, bottom: 0, child: _CameraBadge()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: PetsTextButton(context.petsL10n.addPhotoOrIcon, onPressed: _busy ? null : _choosePicture),
          ),
          const SizedBox(height: 4),
          TextFormField(
            key: const Key('pet-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: context.petsL10n.fieldName, errorMaxLines: 3),
            onChanged: (_) => setState(() {}),
            validator: (text) {
              final value = text?.trim() ?? '';
              if (value.isEmpty) return context.petsL10n.nameMissingNew;
              if (value.length > 60) return context.petsL10n.nameTooLong(60);
              return null;
            },
          ),
          PetsLabel(context.petsL10n.kindOfAnimal),
          _KindPicker(
            selected: _species,
            onSelected: _busy ? null : (species) => setState(() => _species = species),
          ),
          if (_error != null) _errorText(),
          const SizedBox(height: 20),
          PrimaryButton(label: context.l10n.commonContinue, loading: _busy, onPressed: _saveNameAndKind),
          const SizedBox(height: 12),
          PetsFinePrint(
            name.isEmpty ? context.petsL10n.savedOnContinueNoName : context.petsL10n.savedOnContinue(name),
            center: true,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ step 2

  Widget _about(Pet pet) {
    return Form(
      key: _aboutForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PetAvatar(pet: pet, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.petsL10n.petIsSaved(pet.name), style: AppText.cardTitle),
                    Text(
                      context.petsL10n.aboutNote,
                      style: AppText.secondary.copyWith(color: AppColors.brown),
                    ),
                  ],
                ),
              ),
            ],
          ),
          PetBasicsFields(controller: _basics!, now: _now),
          if (_arrival != null) ArrivalQuestion(controller: _arrival!),
          if (_error != null) _errorText(),
          const SizedBox(height: 20),
          PrimaryButton(label: context.l10n.commonContinue, loading: _busy, onPressed: _saveAbout),
          const SizedBox(height: 6),
          PetsTextButton(context.petsL10n.skipForNow, onPressed: _busy ? null : () => _goTo(3)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ step 3

  /// The vet step: Health's own vet tiles, one per role. Nothing about vets
  /// is stored or drawn here.
  Widget _vet(Pet pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsHeading(context.petsL10n.whoLooksAfter(pet.name)),
        const SizedBox(height: 4),
        PetsNote(context.petsL10n.vetStepNote),
        PetsLabel(context.petsL10n.regularVet, level: FieldLevel.essential),
        PetVetTile(petId: pet.id),
        PetsLabel(context.petsL10n.emergencyVet, level: FieldLevel.optional),
        PetVetTile(petId: pet.id, role: VetRole.emergency),
        const SizedBox(height: 20),
        PrimaryButton(label: context.l10n.commonContinue, onPressed: () => _goTo(4)),
        const SizedBox(height: 6),
        PetsTextButton(context.petsL10n.noVetYet, onPressed: () => _goTo(4)),
        PetsFinePrint(
          context.petsL10n.noVetYetNote(pet.name),
          center: true,
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 4

  /// The health basics step: Health's ready-made section, whose own button
  /// is labelled "Finish".
  Widget _healthBasics(Pet pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsHeading(context.petsL10n.whatAVetAsksFirst),
        const SizedBox(height: 4),
        PetsNote(context.petsL10n.healthStepNote),
        const SizedBox(height: 6),
        HealthBasicsSection(
          key: ValueKey('health-basics-${pet.id}'),
          petId: pet.id,
          saveLabel: context.petsL10n.finish,
          onSaved: (_) => _goTo(_allSet),
        ),
        const SizedBox(height: 6),
        PetsTextButton(context.petsL10n.skipForNow, onPressed: () => _goTo(_allSet)),
      ],
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.coralDark,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream, width: 3),
      ),
      child: const AppIcon(Icons.photo_camera_rounded, size: 20, color: AppColors.white),
    );
  }
}

/// The six kinds of animal, three to a row, each with its default icon.
class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.selected, required this.onSelected});

  final PetSpecies selected;
  final ValueChanged<PetSpecies>? onSelected;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 2 * gap) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final species in PetSpecies.values)
              SizedBox(
                width: width.floorToDouble(),
                child: Semantics(
                  button: true,
                  selected: species == selected,
                  child: Material(
                    color: species == selected ? AppColors.yellow : AppColors.white,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('kind-${species.name}'),
                      onTap: onSelected == null ? null : () => onSelected!(species),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(child: PetIconImage(PetIcon.defaultFor(species), size: 44)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                petSpeciesText(context.petsL10n, species),
                                style: AppText.secondary.copyWith(
                                  fontWeight: species == selected ? FontWeight.w800 : FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
