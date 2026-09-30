import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../../health/emergency/emergency.dart';
import '../checklist_sheet.dart';
import '../data/pets_repository_provider.dart';
import '../pet_actions.dart';
import '../pet_words.dart';
import '../state/pet_completeness.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_basics_fields.dart';
import '../widgets/pet_essentials_keeper.dart';
import '../widgets/pet_reminder_card.dart';
import '../widgets/pets_widgets.dart';
import 'remove_pet.dart';

/// The pet's profile: everything the add-a-pet flow asks, on one page, to
/// change later. The essentials card stays until everything is answered.
/// The vet and the health basics are Health's pieces. Archive and delete
/// sit at the very end.
class PetProfileScreen extends ConsumerStatefulWidget {
  const PetProfileScreen({super.key, required this.petId, this.fromMyPets = false});

  final String petId;

  /// Opened from "My pets": the header's "My pets" goes back there instead
  /// of opening it again.
  final bool fromMyPets;

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  PetBasicsController? _basics;
  PetSpecies _species = PetSpecies.dog;
  bool _saving = false;
  bool _removing = false;
  String? _error;

  DateTime get _now => ref.read(petsClockProvider)();
  Pet? get _pet => ref.read(petsStoreProvider).byId(widget.petId);

  @override
  void initState() {
    super.initState();
    final pet = _pet;
    if (pet != null) _fill(pet);
  }

  /// The pet as the form last saw it.
  Pet? _shown;

  void _fill(Pet pet) {
    _name.text = pet.name;
    _species = pet.species;
    _basics?.dispose();
    _basics = PetBasicsController(pet: pet, now: _now);
    _shown = pet;
  }

  /// The pet changed somewhere else while this page is open (a weight added
  /// from the checklist, a new picture): everything the owner has not
  /// edited here follows it, so "Save changes" never writes an old value
  /// back over a newer one.
  void _follow(Pet pet) {
    final shown = _shown;
    if (shown == null || !mounted) return;
    setState(() {
      if (_name.text.trim() == shown.name && _name.text != pet.name) _name.text = pet.name;
      if (_species == shown.species) _species = pet.species;
      _basics
        ?..refresh(pet, _now)
        // The weight unit follows the kind chosen here, saved or not.
        ..species = _species;
      _shown = pet;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _basics?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pet = _pet;
    final basics = _basics;
    if (pet == null || basics == null || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final stored = await ref
          .read(petsStoreProvider.notifier)
          .save(basics.applyTo(pet, now: _now, name: _name.text.trim(), species: _species));
      if (!mounted) return;
      // Saved: from here on the form follows the stored pet again.
      basics.markSaved();
      _shown = stored;
      setState(() => _saving = false);
      showPetsSnack(context, context.petsL10n.changesSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = petsErrorOf(context, e);
      });
    }
  }

  Future<void> _remove() async {
    final pet = _pet;
    if (pet == null || _removing) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final others = container.read(petsProvider).where((p) => p.id != pet.id).length;
    final choice = await askHowToRemovePet(context, pet, canArchive: others > 0);
    if (choice == null || !mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    // The words are taken now: this page may be gone when they are needed.
    final done = choice == RemoveChoice.archive
        ? context.petsL10n.petArchived(pet.name)
        : context.petsL10n.petDeleted(pet.name);
    final navigator = Navigator.of(context);
    final hasRouter = GoRouter.maybeOf(context) != null;
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      if (choice == RemoveChoice.archive) {
        await archivePet(container, pet);
      } else {
        await deletePet(container, pet);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _removing = false;
        _error = petsErrorOf(context, e);
      });
      return;
    }
    // With no pet left the router replaces everything with the welcome.
    if (navigator.mounted && (others > 0 || !hasRouter)) navigator.pop();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done)));
  }

  void _openMyPets() {
    if (widget.fromMyPets) {
      Navigator.of(context).pop();
    } else {
      openMyPets(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(petsStoreProvider.select((pets) => pets.byId(widget.petId)), (_, next) {
      if (next != null) _follow(next);
    });
    final pet = ref.watch(petsStoreProvider.select((pets) => pets.byId(widget.petId)));
    final basics = _basics;
    if (pet == null || basics == null) {
      // Deleted (or never there): nothing to edit.
      return PetsPage(title: context.petsL10n.petProfile, child: PetsNote(context.petsL10n.petNoLongerHere));
    }
    final now = ref.watch(petsClockProvider)();

    // Stays up to date while Health's pages or a sheet cover this one.
    return PetEssentialsKeeper(petId: pet.id, child: _page(pet, basics, now));
  }

  Widget _page(Pet pet, PetBasicsController basics, DateTime now) {
    return PetsPage(
      title: pet.name,
      actions: [HeaderTextAction(context.petsL10n.myPetsTitle, onPressed: _openMyPets)],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    PetAvatar(
                      pet: pet,
                      size: 96,
                      borderColor: AppColors.coral,
                      borderWidth: 4,
                      onTap: () => changePetPicture(context, pet.id),
                    ),
                    const PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: IgnorePointer(child: _SmallCameraBadge()),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PetsHeading(pet.name),
                      PetsNote(petSummaryLine(context.petsL10n, pet, now: now)),
                      TextButton(
                        onPressed: () => changePetPicture(context, pet.id),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(kPetsTapTarget, 40),
                          alignment: AlignmentDirectional.centerStart,
                        ),
                        child: Text(context.petsL10n.changePicture),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _EssentialsCard(pet: pet),
            PetsLabel(context.petsL10n.basics),
            TextFormField(
              key: const Key('pet-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.petsL10n.fieldName, errorMaxLines: 3),
              validator: (text) {
                final value = text?.trim() ?? '';
                if (value.isEmpty) return context.petsL10n.nameMissing;
                if (value.length > 60) return context.petsL10n.nameTooLong(60);
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PetSpecies>(
              key: const Key('pet-kind'),
              initialValue: _species,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.petsL10n.kind),
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              items: [
                for (final species in PetSpecies.values)
                  DropdownMenuItem(value: species, child: Text(petSpeciesText(context.petsL10n, species))),
              ],
              onChanged: (species) {
                if (species == null) return;
                setState(() => _species = species);
                basics.species = species;
              },
            ),
            PetBasicsFields(controller: basics, now: now),
            PetsLabel(context.petsL10n.vet),
            PetVetTile(petId: pet.id),
            const SizedBox(height: 8),
            PetVetTile(petId: pet.id, role: VetRole.emergency),
            PetsLabel(context.petsL10n.healthBasics),
            _HealthBasicsCard(pet: pet),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 20),
            PrimaryButton(label: context.petsL10n.saveChanges, loading: _saving, onPressed: _save),
            const Padding(padding: EdgeInsets.only(top: 24, bottom: 16), child: Divider()),
            PetsOutlineButton(
              context.petsL10n.archivePet(pet.name),
              icon: Icons.archive_outlined,
              onPressed: _removing ? null : _remove,
            ),
            const SizedBox(height: 4),
            PetsTextButton(context.petsL10n.deletePet(pet.name), onPressed: _removing ? null : _remove),
          ],
        ),
      ),
    );
  }
}

class _SmallCameraBadge extends StatelessWidget {
  const _SmallCameraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.coralDark,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream, width: 3),
      ),
      child: const Icon(Icons.photo_camera_rounded, size: 16, color: AppColors.white),
    );
  }
}

/// "2 of 5 essentials still to add", what they are, and the way to the
/// checklist. Unlike the reminder it cannot be postponed: on the profile it
/// stays until everything is answered.
class _EssentialsCard extends ConsumerWidget {
  const _EssentialsCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    announcePetCompletion(ref, context, pet.id);
    final info = ref.watch(petCompletenessProvider(pet.id));
    if (!info.needsAttention) return const SizedBox.shrink();
    void open() => showPetChecklist(context, pet.id);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: PetsCard(
        onTap: open,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        child: Row(
          children: [
            const PetsDisc(Icons.fact_check_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(essentialsStillToAdd(context.petsL10n, info), style: AppText.cardTitle),
                  Text(
                    [for (final item in info.missing) item.labelIn(context.petsL10n)].join(' · '),
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PillButton(context.l10n.commonAdd, key: const Key('profile-essentials-add'), onPressed: open),
          ],
        ),
      ),
    );
  }
}

/// What Health knows about allergies, conditions and the microchip, each
/// with a link into Health's own profile page.
class _HealthBasicsCard extends ConsumerWidget {
  const _HealthBasicsCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(healthProfileProvider(pet.id));
    final value = profile.value;
    if (value == null) {
      return PetsCard(
        child: profile.hasError
            ? PetsNote(healthErrorMessage(profile.error!))
            : const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
      );
    }
    void open() => openHealthProfile(context, pet.id);
    final l10n = context.petsL10n;
    final app = context.l10n;
    String list(List<String> entries, bool noneKnown) => entries.isNotEmpty
        ? [for (final entry in entries) typedInLine(l10n, entry)].join(', ')
        : (noneKnown ? l10n.noneKnown : l10n.notAnsweredYet);

    Widget row(String label, String text, String action, {required String keyName}) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  Text(text, style: AppText.cardTitle),
                ],
              ),
            ),
            TextButton(
              key: Key('health-$keyName'),
              onPressed: open,
              style: TextButton.styleFrom(minimumSize: const Size(kPetsTapTarget, kPetsTapTarget)),
              child: Text(action),
            ),
          ],
        );

    final chip = value.microchip.trim();
    return PetsCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 6, 8),
      child: Column(
        children: [
          row(
            l10n.itemAllergies,
            list(value.allergies, value.allergiesNoneKnown),
            value.allergiesAnswered ? app.commonEdit : l10n.answer,
            keyName: 'allergies',
          ),
          row(
            l10n.itemConditions,
            list(value.conditions, value.conditionsNoneKnown),
            value.conditionsAnswered ? app.commonEdit : l10n.answer,
            keyName: 'conditions',
          ),
          row(
            l10n.itemMicrochip,
            chip.isEmpty ? l10n.notAdded : phoneInLine(l10n, chip),
            chip.isEmpty ? app.commonAdd : app.commonEdit,
            keyName: 'microchip',
          ),
        ],
      ),
    );
  }
}
