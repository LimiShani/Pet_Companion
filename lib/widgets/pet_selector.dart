import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pets/widgets/pet_avatar.dart';
import '../models/pet.dart';
import '../state/pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Horizontal row of pet pills for switching the selected pet.
///
/// Designed to sit on a coral background (the home header, a [CoralHeader]'s
/// `bottom`). Reads and writes [selectedPetIdProvider], so every screen that
/// shows it stays on the same pet.
class PetSelector extends ConsumerWidget {
  const PetSelector({super.key, this.onAdd});

  /// When set, a dashed "+" button is shown after the pills.
  final VoidCallback? onAdd;

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
            _PetPill(
              pet: pet,
              selected: pet.id == selectedId,
              onTap: () => ref.read(selectedPetIdProvider.notifier).select(pet.id),
            ),
            const SizedBox(width: 8),
          ],
          if (onAdd != null) _AddPetButton(onTap: onAdd!),
        ],
      ),
    );
  }
}

class _PetPill extends StatelessWidget {
  const _PetPill({required this.pet, required this.selected, required this.onTap});

  final Pet pet;
  final bool selected;
  final VoidCallback onTap;

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
      label: 'Add a pet',
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: AppColors.white.withValues(alpha: 0.75), width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(Icons.add_rounded, color: AppColors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
