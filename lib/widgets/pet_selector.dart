import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pets/pets.dart';
import '../l10n/l10n.dart';
import '../models/pet.dart';
import '../state/pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Horizontal row of pet pills for switching the selected pet.
///
/// Designed to sit on a coral background (the home header, a [CoralHeader]'s
/// `bottom`). Reads and writes [selectedPetIdProvider], so every screen that
/// shows it stays on the same pet.
///
/// Each pill shows the pet's picture and, while an essential is missing, a
/// small dot. A long press on a pill opens that pet's profile.
class PetSelector extends ConsumerWidget {
  const PetSelector({super.key, this.onAdd, this.trailing, this.highlightSelected = true});

  /// When set, a dashed "+" button is shown after the pills.
  final VoidCallback? onAdd;

  /// An extra pill after the pets, for a choice that is not a pet (the
  /// Store's "All animals"). The caller draws it and handles its taps.
  final Widget? trailing;

  /// With `false` no pet pill is drawn as selected, for when [trailing] is
  /// the current choice. Tapping a pet still selects it.
  final bool highlightSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider);
    // The selected pet rather than the stored id, which can be stale (the
    // pet was archived) or not set yet (the pets arrived after sign-in).
    final selectedId = ref.watch(selectedPetProvider.select((pet) => pet.id));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final pet in pets) ...[
            Stack(
              children: [
                _PetPill(
                  pet: pet,
                  selected: highlightSelected && pet.id == selectedId,
                  onTap: () => ref.read(selectedPetIdProvider.notifier).select(pet.id),
                  // A long press opens the pet's profile, where a missing
                  // essential (the dot) is answered.
                  onLongPress: () => openPetProfile(context, pet.id),
                ),
                // Essentials still missing for this pet. Takes no space and
                // no taps; shows nothing for a complete pet.
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: IgnorePointer(child: PetAttentionDot(petId: pet.id)),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          if (onAdd != null) _AddPetButton(onTap: onAdd!),
        ],
      ),
    );
  }
}

class _PetPill extends StatelessWidget {
  const _PetPill({required this.pet, required this.selected, required this.onTap, required this.onLongPress});

  final Pet pet;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.ink : AppColors.white;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.yellow : AppColors.onCoralPill,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.yellow : AppColors.onCoralOutline, width: 2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The pet's photo or icon (decorative here: the name follows).
                ExcludeSemantics(child: PetAvatar(pet: pet, size: 22)),
                const SizedBox(width: 8),
                Text(pet.name, style: AppText.cardTitle.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPetButton extends StatelessWidget {
  const _AddPetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.petSelectorAdd,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: AppColors.white.withValues(alpha: 0.75), width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 38,
            height: 38,
            child: AppIcon(Icons.add_rounded, color: AppColors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
