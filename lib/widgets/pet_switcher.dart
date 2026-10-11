import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/pet.dart';
import '../platform/feature_ui.dart';
import '../presentation/pet_avatar.dart';
import '../presentation/pet_words.dart';
import '../state/pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// A compact chip for a coral header that shows the selected pet (its
/// picture and name) and opens a sheet to switch it.
///
/// The sheet lists the owner's pets, then "Open {name}'s profile" and "Add
/// a pet". Choosing a pet selects it for the whole app
/// ([selectedPetIdProvider]), the same as the pills of `PetSelector` on
/// Home. While an essential is missing the Pets feature's dot sits on the
/// chip's corner, as it does on a pill.
///
/// A header row holds the title, this chip, the Emergency pill and the
/// account avatar, which is more than a narrow phone has room for: below
/// [namedFrom] the chip gives up the name, below [chevronFrom] the chevron
/// too, and is the pet's picture alone. A screen reader always hears the
/// name.
class PetSwitcher extends ConsumerWidget {
  const PetSwitcher({super.key});

  static const chipKey = Key('pet-switcher-chip');
  static const sheetKey = Key('pet-switcher-sheet');
  static const addKey = Key('pet-switcher-add');
  static const profileKey = Key('pet-switcher-profile');
  static Key rowKey(String petId) => ValueKey('pet-switcher-row-$petId');

  /// The screen width from which the chip shows the pet's name.
  static const namedFrom = 370.0;

  /// The screen width from which the chip shows the chevron.
  static const chevronFrom = 340.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The selected pet rather than the stored id, which can be stale (the
    // pet was archived) or not set yet (the pets arrived after sign-in).
    final pet = ref.watch(selectedPetProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: context.petsL10n.switcherSemantics(pet.name),
          child: ExcludeSemantics(
            child: Builder(
              builder: (context) {
                final width = MediaQuery.sizeOf(context).width;
                return CoralMenuChip(
                  key: chipKey,
                  leading: PetAvatar(pet: pet, size: 24),
                  label: width >= namedFrom ? pet.name : null,
                  showChevron: width >= chevronFrom,
                  onTap: () => _open(context),
                );
              },
            ),
          ),
        ),
        // Essentials still missing for this pet. Takes no space and no
        // taps; shows nothing for a complete pet.
        PositionedDirectional(
          top: -2,
          end: -2,
          child: IgnorePointer(child: featureSlot('pet-attention', pet.id)),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _PetSwitcherSheet(),
    );
    // Opened from the header's own context, which outlives the sheet.
    if (result == null || !context.mounted) return;
    await openFeature<Object>(context, result.action, result.petId);
  }
}

/// What the sheet asks the header to open once it has closed.
class _SheetResult {
  const _SheetResult(this.action, this.petId);

  final String action;
  final String petId;
}

/// The pill-shaped chip of a coral header with a menu behind it: a
/// translucent dark track, a picture at the start, a short label and a
/// chevron at the end. With [onTap] it handles its own taps; without, the
/// parent does (a `PopupMenuButton`'s child). Without a [label] the chip is
/// the picture and the chevron alone.
class CoralMenuChip extends StatelessWidget {
  const CoralMenuChip({
    super.key,
    this.leading,
    required this.label,
    this.showChevron = true,
    this.onTap,
    this.maxLabelWidth = 96,
  });

  /// A 24 px picture at the start.
  final Widget? leading;
  final String? label;
  final bool showChevron;
  final VoidCallback? onTap;

  /// A long name is cut with an ellipsis past this, so the chip cannot
  /// push a header's other actions off the screen.
  final double maxLabelWidth;

  static const height = 36.0;

  /// The width of a chip with a 24 px picture and the chevron, no label.
  static const chevronWidth = 6.0 + 24 + 2 + 18 + 6;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final body = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        leading == null ? 12 : 6,
        0,
        showChevron || label == null ? 6 : 12,
        0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) leading!,
          if (label != null) ...[
            if (leading != null) const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (showChevron) ...[
            const SizedBox(width: 2),
            const AppIcon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.white,
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      height: height,
      child: Material(
        color: AppColors.onCoralPill,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.onCoralOutline, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? body
            : InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: body,
              ),
      ),
    );
  }
}

class _PetSwitcherSheet extends ConsumerWidget {
  const _PetSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.petsL10n;
    final pets = ref.watch(petsProvider);
    final selected = ref.watch(selectedPetProvider);
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: SingleChildScrollView(
        // Above the phone's own navigation bar, so the last row can always
        // be reached (see HealthSheetBody).
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          24 + math.max(media.viewInsets.bottom, media.viewPadding.bottom),
        ),
        child: Column(
          key: PetSwitcher.sheetKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(l10n.switcherTitle, style: AppText.heading),
            ),
            for (final pet in pets)
              _PetRow(
                key: PetSwitcher.rowKey(pet.id),
                pet: pet,
                summary: _summary(l10n, pet),
                selected: pet.id == selected.id,
                onTap: () {
                  ref.read(selectedPetIdProvider.notifier).select(pet.id);
                  Navigator.of(context).pop();
                },
              ),
            const Divider(height: 16),
            _ActionRow(
              key: PetSwitcher.profileKey,
              icon: Icons.badge_outlined,
              label: l10n.switcherOpenProfile(selected.name),
              onTap: () => Navigator.of(
                context,
              ).pop(_SheetResult('pet-profile', selected.id)),
            ),
            _ActionRow(
              key: PetSwitcher.addKey,
              icon: Icons.add_rounded,
              label: l10n.switcherAddPet,
              onTap: () =>
                  Navigator.of(context).pop(_SheetResult('add-pet', selected.id)),
            ),
          ],
        ),
      ),
    );
  }

  /// "Dog · Labrador": the kind, then the breed when there is one (the
  /// first part of what the My pets rows show).
  static String _summary(PetsL10n l10n, Pet pet) {
    final breed = petBreedText(l10n, pet);
    return [
      petSpeciesText(l10n, pet.species),
      if (breed != null) typedInLine(l10n, breed),
    ].join(' · ');
  }
}

class _PetRow extends StatelessWidget {
  const _PetRow({
    super.key,
    required this.pet,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final Pet pet;
  final String summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                ExcludeSemantics(child: PetAvatar(pet: pet, size: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: AppText.rowTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        summary,
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const AppIcon(
                    Icons.check_rounded,
                    size: 22,
                    color: AppColors.coralDark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  AppIcon(icon, size: 22, color: AppColors.brown),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.rowTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
