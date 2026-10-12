import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../platform/feature_ui.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/state/health_keeper.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pets/data/pets_repository_provider.dart';
import '../pet_actions.dart';
import '../../../presentation/pet_words.dart';
import '../../../services/pets/state/pet_completeness.dart';
import '../../../presentation/pet_avatar.dart';
import '../widgets/pet_essentials_keeper.dart';
import '../widgets/pet_reminder_card.dart';
import '../../../presentation/pets_widgets.dart';
import 'name_and_kind_sheet.dart';
import 'remove_pet.dart';

/// The pet's profile: an overview of what is known, one row per answer.
/// Each row opens its own small sheet (or Health's page), which saves on
/// its own, so the page itself has nothing to save. A missing answer reads
/// "Add". Archive and delete are in the header's "More" menu.
class PetProfileScreen extends ConsumerStatefulWidget {
  const PetProfileScreen({super.key, required this.petId});

  final String petId;

  /// The picture: the one button of the identity block.
  static const pictureKey = Key('profile-picture');

  /// The header's "More" menu, and its two entries.
  static const moreKey = Key('profile-more');
  static const archiveKey = Key('profile-archive');
  static const deleteKey = Key('profile-delete');

  /// The row called [name]: `name`, `age`, `weight`, `breed`, `sex`,
  /// `vets`, `health` or `documents`.
  static Key rowKey(String name) => Key('profile-row-$name');

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  bool _removing = false;
  String? _error;

  Future<void> _remove() async {
    final pet = ref.read(petsStoreProvider).byId(widget.petId);
    if (pet == null || _removing) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final others = container
        .read(petsProvider)
        .where((p) => p.id != pet.id)
        .length;
    final choice = await askHowToRemovePet(
      context,
      pet,
      canArchive: others > 0,
    );
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

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'pets.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(
      petsStoreProvider.select((pets) => pets.byId(widget.petId)),
    );
    if (pet == null) {
      // Deleted (or never there): nothing to show.
      return PetsPage(
        title: context.petsL10n.petProfile,
        child: PetsNote(context.petsL10n.petNoLongerHere),
      );
    }
    // A row's sheet may answer the last missing essential.
    announcePetCompletion(ref, context, pet.id);
    final now = ref.watch(petsClockProvider)();

    // Stays up to date while Health's pages or a sheet cover this one.
    return PetEssentialsKeeper(
      petId: pet.id,
      child: HealthKeeper(
        petId: pet.id,
        child: _DocumentsKeeper(petId: pet.id, child: _page(pet, now)),
      ),
    );
  }

  Widget _page(Pet pet, DateTime now) {
    final l10n = context.petsL10n;
    return PetsPage(
      title: pet.name,
      actions: [_MoreMenu(pet: pet, onRemove: _removing ? null : _remove)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Identity(pet: pet),
          _SectionLabel(l10n.basics),
          _BasicsCard(pet: pet, now: now),
          _HealthCard(pet: pet),
          _MoreCard(pet: pet),
          // Start the first 30 days, or see them (a summary once over).
          featureSlot('firstdays-profile', pet.id),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: AppText.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps the pet's documents active while the profile is covered, like
/// [HealthKeeper] does for the vets and the health profile.
class _DocumentsKeeper extends StatefulWidget {
  const _DocumentsKeeper({required this.petId, required this.child});

  final String petId;
  final Widget child;

  @override
  State<_DocumentsKeeper> createState() => _DocumentsKeeperState();
}

class _DocumentsKeeperState extends State<_DocumentsKeeper> {
  ProviderContainer? _container;
  ProviderSubscription<Object?>? _subscription;

  void _listen() {
    _subscription?.close();
    _subscription = _container!.listen(
      healthDocumentsProvider(widget.petId),
      (_, _) {},
      onError: (_, _) {},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _listen();
    }
  }

  @override
  void didUpdateWidget(_DocumentsKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) _listen();
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The header's ⋮: "Archive Kelly" and "Delete Kelly", which both open the
/// same clear choice.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.pet, required this.onRemove});

  final Pet pet;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.petsL10n;
    return PopupMenuButton<RemoveChoice>(
      key: PetProfileScreen.moreKey,
      tooltip: l10n.profileMoreTooltip,
      enabled: onRemove != null,
      icon: const AppIcon(Icons.more_vert_rounded, color: AppColors.white),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 180),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => onRemove?.call(),
      itemBuilder: (context) => [
        PopupMenuItem(
          key: PetProfileScreen.archiveKey,
          value: RemoveChoice.archive,
          child: _MenuRow(Icons.archive_outlined, l10n.archivePet(pet.name)),
        ),
        PopupMenuItem(
          key: PetProfileScreen.deleteKey,
          value: RemoveChoice.delete,
          child: _MenuRow(
            Icons.delete_outline_rounded,
            l10n.deletePet(pet.name),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppIcon(icon, size: 20, color: AppColors.brown),
      const SizedBox(width: 12),
      Flexible(child: Text(label, style: AppText.cardTitle)),
    ],
  );
}

/// The picture (the only button here), the name and a summary line.
class _Identity extends StatelessWidget {
  const _Identity({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.petsL10n;
    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.changePicture,
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              key: PetProfileScreen.pictureKey,
              customBorder: const CircleBorder(),
              onTap: () => changePetPicture(context, pet.id),
              child: ExcludeSemantics(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PetAvatar(
                      pet: pet,
                      size: 88,
                      borderColor: AppColors.coral,
                      borderWidth: 4,
                    ),
                    const PositionedDirectional(
                      end: -2,
                      bottom: -2,
                      child: _CameraBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pet.name,
                style: AppText.heading.copyWith(
                  fontSize: 22,
                  color: AppColors.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profileSummaryLine(l10n, pet),
                style: AppText.secondary.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brown,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.coralDark,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream, width: 2),
      ),
      child: const AppIcon(
        Icons.photo_camera_rounded,
        size: 14,
        color: AppColors.white,
      ),
    );
  }
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';

String _upperFirst(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// What is known about the pet's sex and neutering, in the order they are
/// said: "Female", "spayed". Empty when neither is answered.
List<String> profileSexAndNeutering(PetsL10n l10n, Pet pet) {
  final sex = pet.sex;
  final neutered = pet.neutered;
  // The word for neutering follows the sex: "spayed", "neutered".
  return [
    if (sex != null)
      sex == PetSex.unknown ? l10n.profileSexNotSure : petSexText(l10n, sex),
    if (neutered != null)
      switch (neutered) {
        Neutered.yes => switch (sex) {
          PetSex.female => l10n.profileSpayed,
          PetSex.male => l10n.profileNeuteredMale,
          _ => l10n.profileNeuteredAny,
        },
        Neutered.no => switch (sex) {
          PetSex.female => l10n.profileNotSpayed,
          PetSex.male => l10n.profileNotNeuteredMale,
          _ => l10n.profileNotNeuteredAny,
        },
        Neutered.unknown => l10n.profileNeuteringNotSure,
      },
  ];
}

/// "Dog · Mix · female, spayed": the kind, the breed, the sex and the
/// neutering, as far as they are known. The age has its own row.
String profileSummaryLine(PetsL10n l10n, Pet pet) {
  final breed = petBreedText(l10n, pet);
  final sex = profileSexAndNeutering(l10n, pet);
  return [
    petSpeciesText(l10n, pet.species),
    if (breed != null) typedInLine(l10n, breed),
    if (sex.isNotEmpty) _lowerFirst(sex.join(', ')),
  ].join(' · ');
}

/// "BASICS": the small heading above a card of rows.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 20, 6, 6),
      child: Semantics(
        header: true,
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text.toUpperCase(),
            style: AppText.label.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brown,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// The line between two rows of a card.
const _kRowLine = Color(0xFFF3E8CF);

/// A white rounded card of rows, with a line between them.
class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: _kRowLine,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One row: a label and its value on one line, or a title over a second
/// line ([subtitle]). A missing answer reads [missing] ("Add") in coral.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    required this.label,
    this.value,
    this.subtitle,
    this.missing,
    this.twoLines = false,
    this.onTap,
  });

  final String label;

  /// Shown at the end of the row.
  final String? value;

  /// Shown under [label] instead of [value].
  final String? subtitle;

  /// Shown in place of [value] (or [subtitle]) when there is none.
  final String? missing;

  /// A title over a second line, even while that line is [missing].
  final bool twoLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppText.cardTitle.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    );
    final addStyle = valueStyle.copyWith(
      fontSize: 14,
      color: AppColors.coralDark,
    );
    final twoLines = this.twoLines || subtitle != null;

    final Widget content;
    if (twoLines) {
      final second = subtitle ?? missing;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: valueStyle),
          if (second != null)
            Text(
              second,
              style: subtitle == null
                  ? addStyle.copyWith(fontSize: 13)
                  : AppText.label.copyWith(color: AppColors.brown),
            ),
        ],
      );
    } else {
      final shown = value ?? missing;
      // The value sits at the end of the label's line, or under the label
      // when both do not fit on one line.
      content = Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 2,
        children: [
          Text(
            label,
            style: AppText.cardTitle.copyWith(color: AppColors.ink),
          ),
          if (shown != null)
            Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: value == null ? addStyle : valueStyle,
            ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: twoLines ? 56 : 52),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            twoLines ? 8 : 6,
            onTap == null ? 16 : 10,
            twoLines ? 8 : 6,
          ),
          child: Row(
            children: [
              Expanded(child: content),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const AppIcon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.brown,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Name and kind, age, weight, breed, sex and neutering: each row opens
/// the small sheet with just that question.
class _BasicsCard extends StatelessWidget {
  const _BasicsCard({required this.pet, required this.now});

  final Pet pet;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.petsL10n;
    final add = context.l10n.commonAdd;
    final age = petAgeText(l10n, pet, now: now);
    final kg = pet.weightKg;
    final sex = profileSexAndNeutering(l10n, pet);
    void open(PetInfoItem item) =>
        openPetInfoItem(context, petId: pet.id, item: item);

    return _RowsCard(
      rows: [
        _ProfileRow(
          key: PetProfileScreen.rowKey('name'),
          label: l10n.profileNameAndKind,
          value: [
            typedInLine(l10n, pet.name),
            petSpeciesText(l10n, pet.species),
          ].join(' · '),
          onTap: () => showPetNameAndKindSheet(context, pet),
        ),
        _ProfileRow(
          key: PetProfileScreen.rowKey('age'),
          label: l10n.itemAge,
          value: age == null ? null : _lowerFirst(age),
          missing: add,
          onTap: () => open(PetInfoItem.age),
        ),
        _ProfileRow(
          key: PetProfileScreen.rowKey('weight'),
          label: l10n.itemWeight,
          value: kg == null ? null : petWeightText(l10n, kg, pet.species),
          missing: add,
          onTap: () => open(PetInfoItem.weight),
        ),
        _ProfileRow(
          key: PetProfileScreen.rowKey('breed'),
          label: l10n.itemBreed,
          value: switch (petBreedText(l10n, pet)) {
            final breed? => typedInLine(l10n, breed),
            null => null,
          },
          missing: add,
          onTap: () => open(PetInfoItem.breed),
        ),
        _ProfileRow(
          key: PetProfileScreen.rowKey('sex'),
          label: l10n.itemSexAndNeutering,
          value: sex.isEmpty ? null : _upperFirst(sex.join(' · ')),
          missing: add,
          onTap: () => open(PetInfoItem.sexAndNeutering),
        ),
      ],
    );
  }
}

/// "Dr. Levi · emergency: City Animal Hospital".
String _vetsLine(PetsL10n l10n, PetVets vets) {
  final regular = vets.regular;
  final emergency = vets.emergency;
  final emergencyText = emergency == null
      ? null
      : l10n.profileVetEmergency(typedInLine(l10n, emergency.name));
  return [
    if (regular != null) typedInLine(l10n, regular.name),
    if (emergencyText != null)
      regular == null ? emergencyText : _lowerFirst(emergencyText),
  ].join(' · ');
}

/// "Allergy: chicken · Arthritis in the hips · Chipped"; `null` when
/// nothing is answered yet.
String? _healthLine(PetsL10n l10n, HealthProfile profile) {
  String list(List<String> entries) =>
      [for (final entry in entries) typedInLine(l10n, entry)].join(', ');
  final parts = [
    if (profile.allergies.isNotEmpty)
      l10n.profileAllergies(
        profile.allergies.length,
        list(profile.allergies),
      )
    else if (profile.allergiesNoneKnown)
      l10n.profileNoAllergies,
    if (profile.conditions.isNotEmpty)
      list(profile.conditions)
    else if (profile.conditionsNoneKnown)
      l10n.profileNoConditions,
    if (profile.microchip.trim().isNotEmpty)
      l10n.profileChipped
    else if (profile.notChipped)
      l10n.profileNotChipped,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Health's pieces: the pet's vets and its health profile, each one row
/// that opens Health's own page.
class _HealthCard extends ConsumerWidget {
  const _HealthCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capabilityProvider('health.emergency.view'))) {
      return const SizedBox.shrink();
    }
    final l10n = context.petsL10n;
    final vets = ref.watch(petVetsProvider(pet.id));
    final profile = ref.watch(healthProfileProvider(pet.id));

    final vetsValue = vets.value;
    final noVet = vetsValue != null && vetsValue.isEmpty;
    final String? vetsLine;
    if (vetsValue != null) {
      vetsLine = noVet ? null : _vetsLine(l10n, vetsValue);
    } else {
      vetsLine = vets.hasError ? l10n.couldNotCheck : null;
    }

    final profileValue = profile.value;
    final String? healthLine;
    if (profileValue != null) {
      healthLine = _healthLine(l10n, profileValue);
    } else {
      healthLine = profile.hasError ? l10n.couldNotCheck : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.profileVetAndHealth),
        _RowsCard(
          rows: [
            _ProfileRow(
              key: PetProfileScreen.rowKey('vets'),
              label: l10n.profileVets,
              subtitle: vetsLine,
              missing: noVet ? l10n.profileAddVet : null,
              twoLines: true,
              onTap: () => noVet
                  ? openFeature<Object>(context, 'vet-picker', pet.id)
                  : openFeature<Object>(context, 'pet-vets', pet.id),
            ),
            _ProfileRow(
              key: PetProfileScreen.rowKey('health'),
              label: l10n.profileHealthProfile,
              subtitle: healthLine,
              missing: profileValue != null && healthLine == null
                  ? context.l10n.commonAdd
                  : null,
              twoLines: true,
              onTap: () =>
                  openFeature<Object>(context, 'health-profile', pet.id),
            ),
          ],
        ),
      ],
    );
  }
}

/// The pet's documents, a second door to them besides the emergency kit.
class _MoreCard extends ConsumerWidget {
  const _MoreCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capabilityProvider('health.records.view'))) {
      return const SizedBox.shrink();
    }
    final l10n = context.petsL10n;
    final count = ref.watch(healthDocumentsProvider(pet.id)).value?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.profileMore),
        _RowsCard(
          rows: [
            _ProfileRow(
              key: PetProfileScreen.rowKey('documents'),
              label: l10n.profileDocuments,
              value: count == null || count == 0
                  ? null
                  : AppFormat.of(context).integer(count),
              onTap: () =>
                  openFeature<Object>(context, 'pet-documents', pet.id),
            ),
          ],
        ),
      ],
    );
  }
}
