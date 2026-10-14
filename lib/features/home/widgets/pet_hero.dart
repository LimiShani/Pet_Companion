import '../../../access/access_provider.dart';
import '../../../platform/feature_ui.dart';
import '../../../presentation/pet_avatar.dart';
import '../../../services/pets/state/pet_completeness.dart' show PetInfoItem;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Large circular photo with the pet's name and Breed / Age / Weight pills.
///
/// A detail the owner has not filled in shows "Add" on a lighter pill, which
/// opens the sheet for that one detail; for an account that may not edit
/// pets it shows "—".
///
/// The coral header continues behind the top [coralRise] px of this widget,
/// so the photo appears to sit half on the header and half on the page.
class PetHero extends ConsumerWidget {
  const PetHero({super.key, required this.pet, this.coralRise = 84});

  final Pet pet;

  /// Height of the coral band painted behind the top of the hero.
  final double coralRise;

  /// Diameter of the circular photo.
  static const photoSize = 150.0;

  /// Diameter of the photo on a narrow phone (under 360 px), where the
  /// full size would leave the detail pills too little room ("Weight 23
  /// kg" cut short at 320 px).
  static const compactPhotoSize = 120.0;

  /// Where the pet's name starts, measured from the top of the hero.
  static const nameTop = 30.0;

  /// Where the Household module puts the people who share the pet, on the
  /// photo's bottom edge.
  static const peopleSlot = 'pet-hero-people';

  /// Key of the "Add" pill of [item] (breed, age or weight).
  static Key addKey(PetInfoItem item) => Key('hero-add-${item.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = AppFormat.of(context);
    final age = pet.ageYears;
    final weight = pet.weightKg;
    final breed = (pet.breed ?? '').trim().isEmpty ? null : pet.breed;
    final canAdd =
        ref.watch(capabilityProvider('pets.edit')) &&
        canOpenFeature(context, 'pet-info-item');

    /// The pill of one detail: its [value], or "Add" when it is missing.
    Widget pill(String label, String? value, PetInfoItem item, String add) {
      if (value != null) return _InfoPill(label: label, value: value);
      if (!canAdd) return _InfoPill(label: label, value: _unknown);
      return _InfoPill(
        key: addKey(item),
        label: label,
        value: l10n.commonAdd,
        missing: true,
        semanticLabel: add,
        onTap: () => openFeature<Object>(context, 'pet-info-item', pet.id, {
          'item': item,
        }),
      );
    }

    final words = context.petsL10n;

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
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppSpacing.headerRadius),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Photo(
                    pet: pet,
                    size: MediaQuery.sizeOf(context).width < 360
                        ? compactPhotoSize
                        : photoSize,
                  ),
                  PositionedDirectional(
                    bottom: -6,
                    end: -10,
                    child: featureSlot(peopleSlot, pet.id),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: nameTop),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Text(
                          pet.name,
                          style: AppText.petName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 8 px under the name and 6 px between the pills, as
                      // before; each pill's tap area takes the 6 px above it,
                      // so it is 44 px tall without moving anything.
                      const SizedBox(height: 8 - _InfoPill.reach),
                      pill(
                        l10n.homeBreed,
                        breed,
                        PetInfoItem.breed,
                        words.actionBreed(pet.name),
                      ),
                      pill(
                        l10n.homeAge,
                        age == null ? null : format.decimal(age),
                        PetInfoItem.age,
                        words.actionAge(pet.name),
                      ),
                      pill(
                        l10n.homeWeight,
                        weight == null
                            ? null
                            : l10n.homeWeightKg(format.decimal(weight)),
                        PetInfoItem.weight,
                        words.actionWeight(pet.name),
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

  /// Shown for a detail the owner has not filled in.
  static const _unknown = '—';
}

/// The pet's picture (its photo or its icon) in the white and coral ring.
/// A tap opens the pet's profile.
class _Photo extends StatelessWidget {
  const _Photo({required this.pet, required this.size});

  final Pet pet;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.coral, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E5B4636),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      // The ring takes 9 px on each side (4 border + 5 white).
      child: PetAvatar(
        pet: pet,
        size: size - 18,
        onTap: () => openFeature<Object>(context, 'pet-profile', pet.id),
      ),
    );
  }
}

/// One "label value" pill of the hero. A [missing] detail shows its value
/// ("Add") in coral on a lighter, outlined pill of the same size, and
/// [onTap] fills it in.
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    super.key,
    required this.label,
    required this.value,
    this.missing = false,
    this.semanticLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final bool missing;

  /// What a screen reader says for a tappable pill ("Add Soya's age").
  final String? semanticLabel;
  final VoidCallback? onTap;

  static const _labelColumn = 56.0;

  /// The room above each pill (the gap to what is above it), which is part
  /// of its tap area.
  static const reach = 6.0;

  @override
  Widget build(BuildContext context) {
    final pill = _pill(context);
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.only(top: reach),
        child: pill,
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: reach),
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: pill),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The 2 px outline of a missing detail is taken from the padding, so
    // both kinds of pill are the same size.
    final padding = missing
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    final decoration = missing
        ? BoxDecoration(
            color: scheme.surfaceContainer,
            border: Border.all(color: scheme.outlineVariant, width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          )
        : const BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          );
    // A tappable pill is painted as ink, so its ripple shows on it.
    Widget box({required Widget child}) => onTap == null
        ? Container(padding: padding, decoration: decoration, child: child)
        : Ink(padding: padding, decoration: decoration, child: child);
    return box(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The labels line up in a 56 px column. A longer word (another
          // language, large text) gets the room it needs, up to half of the
          // pill, instead of wrapping inside a fixed box.
          final most = constraints.maxWidth / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: most < _labelColumn ? most : _labelColumn,
                  maxWidth: most,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Text(
                    label,
                    style: AppText.label.copyWith(color: AppColors.brown),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: missing
                      ? AppText.button(14).copyWith(color: AppColors.coralDark)
                      : AppText.pillValue,
                  // "Add" is smaller than a value, on the same line height
                  // (the inherited one included), so the pill keeps its
                  // height.
                  strutStyle: missing
                      ? StrutStyle.fromTextStyle(
                          DefaultTextStyle.of(
                            context,
                          ).style.merge(AppText.pillValue),
                          forceStrutHeight: true,
                        )
                      : null,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
