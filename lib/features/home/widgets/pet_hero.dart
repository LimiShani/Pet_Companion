import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../pets/pets.dart';

/// Large circular photo with the pet's name and Breed / Age / Weight pills.
///
/// The coral header continues behind the top [coralRise] px of this widget,
/// so the photo appears to sit half on the header and half on the page.
class PetHero extends StatelessWidget {
  const PetHero({super.key, required this.pet, this.coralRise = 84});

  final Pet pet;

  /// Height of the coral band painted behind the top of the hero.
  final double coralRise;

  /// Diameter of the circular photo.
  static const photoSize = 150.0;

  /// Where the pet's name starts, measured from the top of the hero.
  static const nameTop = 30.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: coralRise,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.headerRadius)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Photo(pet: pet),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: nameTop),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(pet.name, style: AppText.petName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(height: 8),
                      _InfoPill(label: 'Breed', value: pet.breed ?? '—'),
                      const SizedBox(height: 6),
                      _InfoPill(label: 'Age', value: pet.ageYears == null ? '—' : _formatNumber(pet.ageYears!)),
                      const SizedBox(height: 6),
                      _InfoPill(
                        label: 'Weight',
                        value: pet.weightKg == null ? '—' : '${_formatNumber(pet.weightKg!)} kg',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatNumber(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// The pet's picture (its photo or its icon) in the white and coral ring.
/// A tap opens the pet's profile.
class _Photo extends StatelessWidget {
  const _Photo({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PetHero.photoSize,
      height: PetHero.photoSize,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.coral, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x2E75562E), blurRadius: 18, offset: Offset(0, 6))],
      ),
      // The ring takes 9 px on each side (4 border + 5 white).
      child: PetAvatar(pet: pet, size: PetHero.photoSize - 18, onTap: () => openPetProfile(context, pet.id)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.all(Radius.circular(999))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: AppText.label.copyWith(color: AppColors.brown)),
          ),
          Expanded(
            child: Text(value, style: AppText.pillValue, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
